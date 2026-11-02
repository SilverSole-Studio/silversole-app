// supabase/tests/diamonds_concurrency_test.mjs
//
// The diamonds cases PGlite cannot play (one connection): the same account
// calling earn from several phones at the same instant. Starts a real
// PostgreSQL on this machine (embedded-postgres), same harness as
// game_saves_concurrency_test.mjs.
//
//   cd supabase/tests && npm install && npm run test:diamonds-concurrency

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8').replace(
  /create role (\w+) ([^;]+);/g,
  'do $r$ begin create role $1 $2; exception when duplicate_object then null; end $r$;',
);
const migrationsDir = join(here, '..', 'migrations');
const migration = readdirSync(migrationsDir)
  .filter((f) => f.endsWith('.sql') && f.includes('diamonds'))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const PORT = 54893;
const me = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';

let server;
let dir;

test.before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'diamonds-pg-'));
  server = new EmbeddedPostgres({
    databaseDir: dir,
    user: 'postgres',
    password: 'postgres',
    port: PORT,
    persistent: false,
    initdbFlags: ['--encoding=UTF8', '--locale=C'],
    postgresFlags: ['-c', 'max_connections=100'],
  });
  await server.initialise();
  await server.start();
});

test.after(async () => {
  await server?.stop();
  if (dir) rmSync(dir, { recursive: true, force: true });
});

const connect = async (database) => {
  const c = new pg.Client({ host: 'localhost', port: PORT, user: 'postgres', password: 'postgres', database });
  await c.connect();
  return c;
};

async function freshDb(name) {
  const admin = await connect('postgres');
  await admin.query(`drop database if exists ${name}`);
  await admin.query(`create database ${name}`);
  await admin.end();
  const db = await connect(name);
  await db.query(stubs);
  await db.query(migration);
  for (const u of [me, other]) await db.query('insert into auth.users (id) values ($1)', [u]);
  // Covers today whatever "today" is when this runs.
  for (const u of [me, other]) {
    await db.query('insert into public.subscriptions (user_id, active_until) values ($1, current_date + 3)', [u]);
  }
  await db.end();
}

/** Every job as [user] on its own connection, all fired in the same tick. */
async function burst(database, user, jobs) {
  const clients = await Promise.all(
    jobs.map(async () => {
      const c = await connect(database);
      await c.query('set role authenticated');
      await c.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
      return c;
    }),
  );
  try {
    return await Promise.all(
      jobs.map(([sql, params], i) =>
        clients[i].query(sql, params).then(
          (r) => r.rows[0].r,
          (e) => ({ error: e.message }),
        ),
      ),
    );
  } finally {
    await Promise.all(clients.map((c) => c.end()));
  }
}

test('eight phones earn at the same instant: exactly one is paid', async () => {
  await freshDb('d_once');
  const rs = await burst(
    'd_once',
    me,
    Array.from({ length: 8 }, () => ['select public.diamond_earn_exercise(20) as r', []]),
  );
  assert.equal(rs.filter((r) => r.ok === true).length, 1, JSON.stringify(rs));
  assert.equal(rs.filter((r) => r.reason === 'already_today').length, 7, JSON.stringify(rs));
  const [after] = await burst('d_once', me, [['select public.diamond_balance() as r', []]]);
  assert.equal(after.balance, 10);
});

test('two accounts at once are both paid, neither blocks the other', async () => {
  await freshDb('d_two');
  const a = burst('d_two', me, [['select public.diamond_earn_exercise(20) as r', []]]);
  const b = burst('d_two', other, [['select public.diamond_earn_exercise(20) as r', []]]);
  const [[ra], [rb]] = await Promise.all([a, b]);
  assert.equal(ra.balance, 10);
  assert.equal(rb.balance, 10);
});

test('30 calls at once from one person: 10 pass the limiter, 20 are rate limited, nothing errors', async () => {
  await freshDb('d_rate');
  const rs = await burst('d_rate', me, Array.from({ length: 30 }, () => ['select public.diamond_balance() as r', []]));
  assert.equal(rs.filter((r) => r.ok === true).length, 10, JSON.stringify(rs.filter((r) => r.error)));
  assert.equal(rs.filter((r) => r.reason === 'rate_limited').length, 20);
});

test('balance and earn racing across the expiry write one expire row', async () => {
  await freshDb('d_exp');
  const db = await connect('d_exp');
  await db.query('update public.subscriptions set active_until = current_date - 200 where user_id = $1', [me]);
  await db.query(
    "insert into public.diamond_ledger (user_id, day, delta, reason) values ($1, current_date - 300, 50, 'earn_exercise')",
    [me],
  );
  await db.end();
  const rs = await burst(
    'd_exp',
    me,
    Array.from({ length: 6 }, (_, i) => [
      i % 2 ? 'select public.diamond_balance() as r' : 'select public.diamond_earn_exercise(20) as r',
      [],
    ]),
  );
  assert.equal(rs.filter((r) => r.error).length, 0, JSON.stringify(rs));
  const admin = await connect('d_exp');
  const n = (await admin.query("select count(*)::int as n from public.diamond_ledger where reason = 'expire'")).rows[0].n;
  const bal = (await admin.query('select sum(delta)::int as s from public.diamond_ledger')).rows[0].s;
  await admin.end();
  assert.equal(n, 1);
  assert.equal(bal, 0);
});
