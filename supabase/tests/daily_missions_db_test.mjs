// supabase/tests/daily_missions_db_test.mjs
//
// Runs supabase/migrations/*_daily_mission_plans.sql in PGlite on top of
// supabase_stubs.sql and checks what the Edge Function `daily-missions` relies on:
//   - the table is closed to anon and signed-in users (RLS on, no policy, no grants)
//   - the service role (the function) can use it
//   - the claim `insert ... on conflict (user_id, day) do nothing returning *`
//     hands the row to exactly one caller
//   - taking over a stale `pending` row (a conditional update) matches exactly
//     one row, and never a fresh, done or failed one
//
//   cd supabase/tests && npm install && npm run test:missions-db

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const here = dirname(fileURLToPath(import.meta.url));
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8');
const migrationsDir = join(here, '..', 'migrations');

function migrations() {
  return readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort()
    .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
    .join('\n');
}

const userA = '00000000-0000-4000-8000-00000000000a';
const userB = '00000000-0000-4000-8000-00000000000b';
const DAY = '2026-11-01';
const TABLE = 'public.daily_mission_plans';

async function fresh() {
  const db = new PGlite();
  await db.exec(stubs);
  await db.exec(migrations());
  for (const u of [userA, userB]) await db.query('insert into auth.users (id) values ($1)', [u]);
  return db;
}

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

/** The claim exactly as index.ts makes it (PostgREST upsert with ignoreDuplicates). */
const CLAIM = `insert into ${TABLE} (user_id, day, status) values ($1, $2, 'pending')
               on conflict (user_id, day) do nothing returning *`;

/** The takeover exactly as index.ts makes it: refresh created_at only if still stale. */
const TAKEOVER = `update ${TABLE} set created_at = now()
                  where user_id = $1 and day = $2 and status = 'pending'
                    and created_at < now() - interval '60 seconds'
                  returning user_id`;

// ------------------------------------------------------------------ migration

test('RLS is on and there is not a single policy', async () => {
  const db = await fresh();
  const rls = await db.query(
    "select relrowsecurity from pg_class where oid = 'public.daily_mission_plans'::regclass",
  );
  assert.equal(rls.rows[0].relrowsecurity, true);
  const policies = await db.query(
    "select count(*)::int as n from pg_policies where tablename = 'daily_mission_plans'",
  );
  assert.equal(policies.rows[0].n, 0);
});

test('anon and authenticated hold no privilege on the table at all', async () => {
  const db = await fresh();
  for (const role of ['anon', 'authenticated']) {
    for (const priv of ['select', 'insert', 'update', 'delete', 'truncate', 'references', 'trigger']) {
      const r = await db.query('select has_table_privilege($1, $2, $3) as ok', [role, TABLE, priv]);
      assert.equal(r.rows[0].ok, false, `${role} ${priv}`);
    }
  }
});

test('anon and authenticated cannot select, insert, update or delete', async () => {
  const db = await fresh();
  await db.query(CLAIM, [userA, DAY]);
  for (const [role, user] of [
    ['anon', null],
    ['authenticated', userA],
    ['authenticated', userB],
  ]) {
    await assert.rejects(as(db, role, user, `select * from ${TABLE}`), /permission denied/, `${role} select`);
    await assert.rejects(
      as(db, role, user, `insert into ${TABLE} (user_id, day, status) values ($1, '2026-11-02', 'done')`, [
        user ?? userA,
      ]),
      /permission denied/,
      `${role} insert`,
    );
    await assert.rejects(
      as(db, role, user, `update ${TABLE} set status = 'done'`),
      /permission denied/,
      `${role} update`,
    );
    await assert.rejects(as(db, role, user, `delete from ${TABLE}`), /permission denied/, `${role} delete`);
  }
  // Nothing was touched.
  const left = await db.query(`select status from ${TABLE}`);
  assert.deepEqual(left.rows, [{ status: 'pending' }]);
});

test('the service role (the function) can read and write', async () => {
  const db = await fresh();
  const claimed = await as(db, 'service_role', null, CLAIM, [userA, DAY]);
  assert.equal(claimed.rows.length, 1);
  await as(db, 'service_role', null, `update ${TABLE} set status = 'done', payload = $1 where user_id = $2`, [
    JSON.stringify({ greeting: 'hi' }),
    userA,
  ]);
  const r = await as(db, 'service_role', null, `select status, payload from ${TABLE}`);
  assert.deepEqual(r.rows, [{ status: 'done', payload: { greeting: 'hi' } }]);
});

test('status is limited to pending, done and failed; a user and a day are both needed', async () => {
  const db = await fresh();
  await assert.rejects(
    db.query(`insert into ${TABLE} (user_id, day, status) values ($1, $2, 'bogus')`, [userA, DAY]),
    /check constraint/,
  );
  await assert.rejects(db.query(`insert into ${TABLE} (user_id, status) values ($1, 'pending')`, [userA]), /null value/);
  await assert.rejects(
    db.query(`insert into ${TABLE} (user_id, day, status) values ('00000000-0000-4000-8000-0000000000ff', $1, 'pending')`, [DAY]),
    /foreign key/,
  );
});

test('rows go with the account', async () => {
  const db = await fresh();
  await db.query(CLAIM, [userA, DAY]);
  await db.query(CLAIM, [userB, DAY]);
  await db.query('delete from auth.users where id = $1', [userA]);
  const r = await db.query(`select user_id from ${TABLE}`);
  assert.deepEqual(r.rows, [{ user_id: userB }]);
});

// ----------------------------------------------------------------------- claim

test('the claim returns the row once and nothing the second time', async () => {
  const db = await fresh();
  const first = await db.query(CLAIM, [userA, DAY]);
  assert.equal(first.rows.length, 1);
  assert.equal(first.rows[0].user_id, userA);
  assert.equal(first.rows[0].status, 'pending');

  const second = await db.query(CLAIM, [userA, DAY]);
  assert.equal(second.rows.length, 0);

  // Another day and another user are separate claims.
  assert.equal((await db.query(CLAIM, [userA, '2026-11-02'])).rows.length, 1);
  assert.equal((await db.query(CLAIM, [userB, DAY])).rows.length, 1);
  assert.equal((await db.query(`select count(*)::int as n from ${TABLE}`)).rows[0].n, 3);
});

test('a claim does not overwrite a finished row', async () => {
  const db = await fresh();
  await db.query(CLAIM, [userA, DAY]);
  await db.query(`update ${TABLE} set status = 'done', payload = '{"greeting":"x"}' where user_id = $1`, [userA]);
  assert.equal((await db.query(CLAIM, [userA, DAY])).rows.length, 0);
  const r = await db.query(`select status, payload from ${TABLE}`);
  assert.deepEqual(r.rows, [{ status: 'done', payload: { greeting: 'x' } }]);
});

// -------------------------------------------------------------------- takeover

async function seed(db, status, ageSeconds, user = userA) {
  await db.query(
    `insert into ${TABLE} (user_id, day, status, created_at)
     values ($1, $2, $3, now() - ($4 || ' seconds')::interval)`,
    [user, DAY, status, String(ageSeconds)],
  );
}

test('taking over a stale pending row affects exactly one row, once', async () => {
  const db = await fresh();
  await seed(db, 'pending', 90);
  await seed(db, 'pending', 90, userB); // somebody else's stale row stays alone

  const first = await db.query(TAKEOVER, [userA, DAY]);
  assert.equal(first.rows.length, 1);
  // created_at was refreshed, so a second racing takeover no longer matches.
  const second = await db.query(TAKEOVER, [userA, DAY]);
  assert.equal(second.rows.length, 0);

  const b = await db.query(`select created_at < now() - interval '60 seconds' as stale from ${TABLE} where user_id = $1`, [userB]);
  assert.equal(b.rows[0].stale, true);
});

test('a fresh pending, a done and a failed row are never taken over', async () => {
  const db = await fresh();
  await seed(db, 'pending', 10);
  assert.equal((await db.query(TAKEOVER, [userA, DAY])).rows.length, 0);

  await db.query(`update ${TABLE} set status = 'done', created_at = now() - interval '1 hour'`);
  assert.equal((await db.query(TAKEOVER, [userA, DAY])).rows.length, 0);

  await db.query(`update ${TABLE} set status = 'failed'`);
  assert.equal((await db.query(TAKEOVER, [userA, DAY])).rows.length, 0);

  assert.equal((await db.query(TAKEOVER, [userA, '2026-11-02'])).rows.length, 0);
});

test('the takeover runs as the service role too', async () => {
  const db = await fresh();
  await seed(db, 'pending', 120);
  const r = await as(db, 'service_role', null, TAKEOVER, [userA, DAY]);
  assert.equal(r.rows.length, 1);
});
