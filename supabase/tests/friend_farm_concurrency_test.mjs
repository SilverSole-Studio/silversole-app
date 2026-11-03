// supabase/tests/friend_farm_concurrency_test.mjs
//
// The friend-farm cases PGlite cannot play (one connection): many calls at the
// same instant. Starts a real PostgreSQL on this machine (embedded-postgres, MIT),
// applies supabase_stubs.sql plus the friends, game_saves and friend_farm
// migrations, and fires the calls from separate connections at once.
//
//   cd supabase/tests && npm install && npm run test:friend-farm-concurrency
//
// The token bucket is swapped for "lock my row, always allow", so the limiter
// does not hide a missing lock.

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
const migrations = readdirSync(migrationsDir)
  .filter((f) => f.endsWith('.sql') && (f.includes('friends') || f.includes('game_saves') || f.includes('friend_farm')))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const PORT = 54893;
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const A = uid(1);
const B = uid(2);
const dryFarm = JSON.stringify({
  v: 1,
  keys: {
    'silversole.farm': JSON.stringify({
      xp: 10,
      plots: Array.from({ length: 12 }, () => ({ owned: true, crop: 'bokChoy', stage: 1, dry: true })),
    }),
  },
});

let server;
let dir;

test.before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'ff-pg-'));
  server = new EmbeddedPostgres({
    databaseDir: dir,
    user: 'postgres',
    password: 'postgres',
    port: PORT,
    persistent: false,
    initdbFlags: ['--encoding=UTF8', '--locale=C'],
    postgresFlags: ['-c', 'max_connections=200'],
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

const friend = (db, x, y) =>
  db.query(
    "insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')",
    [x, y],
  );

/** A fresh database: A, B and [n] more people (uid(100+i)), all friends of A; everybody has a dry farm. */
async function freshDb(name, n) {
  const admin = await connect('postgres');
  await admin.query(`drop database if exists ${name}`);
  await admin.query(`create database ${name}`);
  await admin.end();
  const db = await connect(name);
  await db.query(stubs);
  await db.query(migrations);
  await db.query(
    'create or replace function public.friend_farm_take(p_me uuid, p_cost real) returns boolean language plpgsql as $$ begin ' +
      'insert into public.friend_help_limits (user_id, tokens) values (p_me, 30) on conflict (user_id) do nothing; ' +
      'perform 1 from public.friend_help_limits where user_id = p_me for update; return true; end $$',
  );
  const people = [A, B, ...Array.from({ length: n }, (_, i) => uid(100 + i))];
  for (const [i, u] of people.entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query('insert into public.profiles (user_id, friend_code) values ($1, $2)', [u, String(50000000 + i)]);
    await db.query('insert into public.game_saves (user_id, rev, data) values ($1, 1, $2)', [u, dryFarm]);
  }
  await friend(db, A, B);
  for (let i = 0; i < n; i++) await friend(db, A, uid(100 + i));
  await db.end();
}

/** Every job [user, sql, params] on its own connection, all fired in the same tick. */
async function burst(database, jobs) {
  const clients = await Promise.all(
    jobs.map(async ([user]) => {
      const c = await connect(database);
      await c.query('set role authenticated');
      await c.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
      return c;
    }),
  );
  try {
    return await Promise.all(
      jobs.map(([, q, params], i) =>
        clients[i].query(q, params).then(
          (r) => r.rows[0]?.r ?? r.rows,
          (e) => ({ error: e.message }),
        ),
      ),
    );
  } finally {
    await Promise.all(clients.map((c) => c.end()));
  }
}

async function admin(database, q, params = []) {
  const c = await connect(database);
  try {
    return (await c.query(q, params)).rows;
  } finally {
    await c.end();
  }
}

const water = (user, who, plot) => [user, 'select public.friend_water($1, $2) as r', [who, plot]];

test('A fires 20 waterings at 7 friends at once: exactly 5 friends are helped, once each', async () => {
  await freshDb('ff_daily', 6);
  const friends = [B, ...Array.from({ length: 6 }, (_, i) => uid(100 + i))];
  const jobs = [];
  for (let i = 0; i < 20; i++) jobs.push(water(A, friends[i % 7], i % 12));
  const out = await burst('ff_daily', jobs);
  assert.ok(out.every((r) => !r.error), JSON.stringify(out.filter((r) => r.error)));
  assert.equal(out.filter((r) => r.ok).length, 5);
  const rows = await admin('ff_daily', 'select helper, helped from public.friend_helps');
  assert.equal(rows.length, 5);
  assert.equal(new Set(rows.map((r) => r.helped)).size, 5, 'no friend twice');
});

test('10 helpers water the same friend at once: only 2 plots can be waiting, never the same plot twice', async () => {
  await freshDb('ff_recv', 0);
  const helpers = Array.from({ length: 10 }, (_, i) => uid(200 + i));
  const db = await connect('ff_recv');
  for (const [i, h] of helpers.entries()) {
    await db.query('insert into auth.users (id) values ($1)', [h]);
    await db.query('insert into public.profiles (user_id, friend_code) values ($1, $2)', [h, String(60000000 + i)]);
    await friend(db, h, B);
  }
  await db.end();
  const out = await burst('ff_recv', helpers.map((h, i) => water(h, B, i % 2)));
  assert.ok(out.every((r) => !r.error), JSON.stringify(out.filter((r) => r.error)));
  assert.equal(out.filter((r) => r.ok).length, 2);
  const rows = await admin('ff_recv', 'select plot from public.friend_helps');
  assert.deepEqual(rows.map((r) => r.plot).sort(), [0, 1]);
});

test('A and B help each other many times at once: no deadlock, one record each way', async () => {
  await freshDb('ff_dead', 0);
  const jobs = [];
  for (let i = 0; i < 10; i++) {
    jobs.push(water(A, B, i % 12));
    jobs.push(water(B, A, i % 12));
  }
  const out = await burst('ff_dead', jobs);
  assert.ok(out.every((r) => !r.error), JSON.stringify(out.filter((r) => r.error)));
  assert.equal(out.filter((r) => r.ok).length, 2);
});

test('two phones claim at once: each record is handed out exactly once', async () => {
  await freshDb('ff_claim', 3);
  const helpers = [A, uid(100), uid(101), uid(102)];
  const db = await connect('ff_claim');
  for (const h of helpers.slice(1)) await friend(db, h, B);
  await db.end();
  const made = await burst('ff_claim', helpers.map((h, i) => water(h, B, i)));
  assert.equal(made.filter((r) => r.ok).length, 4);
  const claims = await burst('ff_claim', Array.from({ length: 6 }, () => [B, 'select public.friend_helps_claim() as r', []]));
  assert.ok(claims.every((r) => !r.error), JSON.stringify(claims));
  assert.equal(claims.reduce((n, r) => n + r.received.length, 0), 4, 'four records, handed out once in total');
  const mine = await burst('ff_claim', Array.from({ length: 4 }, () => [A, 'select public.friend_helps_claim() as r', []]));
  assert.equal(mine.reduce((n, r) => n + r.givenXp, 0), 3, 'A gets the helper xp once');
});
