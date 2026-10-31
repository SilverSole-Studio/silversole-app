// supabase/tests/devices_rls_test.mjs
//
// Runs supabase/migrations/*_devices_rls.sql in PGlite on top of
// supabase_stubs.sql (which recreates the production devices / user_devices
// tables with their ORIGINAL permissive policies) and checks:
//   - a signed-in user reads only the devices bound to them
//   - nobody can insert a binding straight into user_devices
//   - the heartbeat path (service role / superuser UPDATE) still works
//   - without the migration the same attacks work (the test detects the hole)
//
//   cd supabase/tests && npm install && npm run test:devices

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const here = dirname(fileURLToPath(import.meta.url));
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8');
const migrationsDir = join(here, '..', 'migrations');
const MIGRATION = 'devices_rls';

/** All migrations in order; [exclude] drops the ones whose file name contains it. */
function migrations({ exclude } = {}) {
  return readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql') && !(exclude && f.includes(exclude)))
    .sort()
    .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
    .join('\n');
}

const userA = '00000000-0000-4000-8000-00000000000a';
const userB = '00000000-0000-4000-8000-00000000000b';

async function fresh({ withFix = true } = {}) {
  const db = new PGlite();
  await db.exec(stubs);
  await db.exec(migrations({ exclude: withFix ? undefined : MIGRATION }));
  for (const u of [userA, userB]) await db.query('insert into auth.users (id) values ($1)', [u]);
  // Superuser seeding (provisioning is manual in production).
  await db.exec(`
    insert into public.devices (device_id, label, last_battery_percent, is_charging)
      values ('D1', 'sole one', 80, false), ('D2', 'sole two', 55, true);
  `);
  await db.query('insert into public.user_devices (user_id, device_id, nickname) values ($1, $2, $3)', [
    userA,
    'D1',
    'mine',
  ]);
  return db;
}

/** Runs [sql] as [role] with [user] as auth.uid() (null = no JWT). */
async function as(db, role, user, sql, params = []) {
  await db.exec(`set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user ?? '']);
  try {
    return await db.query(sql, params);
  } finally {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', '', false)");
  }
}
const asUser = (db, user, sql, params) => as(db, 'authenticated', user, sql, params);
const deviceIds = async (db, user) =>
  (await asUser(db, user, 'select device_id from public.devices order by device_id')).rows.map((r) => r.device_id);
const bind = (db, user, deviceId) =>
  asUser(db, user, 'insert into public.user_devices (user_id, device_id) values ($1, $2)', [user, deviceId]);

test('a user reads only the devices bound to them', async () => {
  const db = await fresh();
  assert.deepEqual(await deviceIds(db, userA), ['D1']);
});

test('a user with no binding reads no device', async () => {
  const db = await fresh();
  assert.deepEqual(await deviceIds(db, userB), []);
});

test('anon: the stubs grant anon table privileges, but no policy applies, so it reads zero rows', async () => {
  const db = await fresh();
  const r = await as(db, 'anon', null, 'select device_id from public.devices');
  assert.deepEqual(r.rows, []);
  const ud = await as(db, 'anon', null, 'select * from public.user_devices');
  assert.deepEqual(ud.rows, []);
});

test('signed in with a made-up uid still sees nothing', async () => {
  const db = await fresh();
  assert.deepEqual(await deviceIds(db, '00000000-0000-4000-8000-0000000000ff'), []);
});

test('cannot bind someone else\'s device by inserting into user_devices', async () => {
  const db = await fresh();
  await assert.rejects(bind(db, userB, 'D1'), /row-level security/);
  await assert.rejects(bind(db, userB, 'D2'), /row-level security/);
  assert.deepEqual(await deviceIds(db, userB), []);
  assert.equal((await db.query('select count(*)::int as n from public.user_devices')).rows[0].n, 1);
});

test('cannot bind even a free device to oneself, or insert for another user', async () => {
  const db = await fresh();
  await assert.rejects(bind(db, userA, 'D2'), /row-level security/);
  await assert.rejects(
    asUser(db, userA, 'insert into public.user_devices (user_id, device_id) values ($1, $2)', [userB, 'D2']),
    /row-level security/,
  );
});

test('anon cannot insert a binding', async () => {
  const db = await fresh();
  await assert.rejects(
    as(db, 'anon', null, 'insert into public.user_devices (user_id, device_id) values ($1, $2)', [userB, 'D1']),
    /permission denied|row-level security/,
  );
});

test('user_devices: you still see your own row, and nobody else\'s', async () => {
  const db = await fresh();
  const a = await asUser(db, userA, 'select user_id, device_id, nickname from public.user_devices');
  assert.deepEqual(a.rows, [{ user_id: userA, device_id: 'D1', nickname: 'mine' }]);
  const b = await asUser(db, userB, 'select * from public.user_devices');
  assert.deepEqual(b.rows, []);
});

test('heartbeat path: service role and superuser can still update devices', async () => {
  const db = await fresh();
  const upd = `update public.devices set last_heartbeat_at = '2026-11-01T00:00:00Z',
    last_battery_percent = 42, is_charging = true, last_battery_at = now() where device_id = 'D2'`;
  await db.exec(upd); // superuser
  await as(db, 'service_role', null, upd); // bypassrls, the Edge Function's role
  const r = await db.query("select last_battery_percent, is_charging from public.devices where device_id = 'D2'");
  assert.deepEqual(r.rows, [{ last_battery_percent: 42, is_charging: true }]);
});

test('a user cannot write devices (no write policy)', async () => {
  const db = await fresh();
  const r = await asUser(db, userA, "update public.devices set last_battery_percent = 1 where device_id = 'D1'");
  assert.equal(r.affectedRows, 0);
  assert.equal(
    (await db.query("select last_battery_percent from public.devices where device_id = 'D1'")).rows[0]
      .last_battery_percent,
    80,
  );
});

test('before the migration: the same user reads every device and can bind any device (hole is real)', async () => {
  const db = await fresh({ withFix: false });
  assert.deepEqual(await deviceIds(db, userB), ['D1', 'D2']);
  await bind(db, userB, 'D1'); // does not throw
  assert.equal((await asUser(db, userB, 'select * from public.user_devices')).rows.length, 1);
});
