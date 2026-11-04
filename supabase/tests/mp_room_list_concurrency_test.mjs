// supabase/tests/mp_room_list_concurrency_test.mjs
//
// 交誼廳列表同一瞬間很多人加入（PGlite 只有一條連線做不到）：啟一個真的 PostgreSQL
// （embedded-postgres），套 supabase_stubs.sql 與 friends、mp_rooms、mp_seats、
// mp_presence、mp_quick_match、mp_room_list 幾支 migration，每個人各開一條連線同時打。
//
//   cd supabase/tests && npm install && npm run test:mp-list-concurrency
//
// 測鎖的案例把每人限流關掉（免得限流擋住、看不出少了鎖）；一個案例開著限流。

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
// Roles belong to the whole server, not one database: create them only once.
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8').replace(
  /create role (\w+) ([^;]+);/g,
  'do $r$ begin create role $1 $2; exception when duplicate_object then null; end $r$;',
);
const migrationsDir = join(here, '..', 'migrations');
const migrations = readdirSync(migrationsDir)
  .filter(
    (f) =>
      f.endsWith('.sql') &&
      ['friends', 'mp_rooms', 'mp_seats', 'mp_presence', 'mp_quick_match', 'mp_room_list'].some((k) => f.includes(k)),
  )
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const PORT = 54894;
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const HOST = uid(1);
const people = (n) => Array.from({ length: n }, (_, i) => uid(100 + i));

let server;
let dir;

test.before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'mp-list-pg-'));
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

/** A fresh database: HOST and [n] more people (uid(100+i)); everyone is a stranger to everyone. */
async function freshDb(name, n, { noRateLimit = true } = {}) {
  const admin = await connect('postgres');
  await admin.query(`drop database if exists ${name}`);
  await admin.query(`create database ${name}`);
  await admin.end();
  const db = await connect(name);
  await db.query(stubs);
  await db.query(migrations);
  if (noRateLimit) {
    await db.query(
      'create or replace function public.mp_take(p_me uuid, p_cost real) returns boolean language plpgsql as $$ begin ' +
        'insert into public.mp_limits (user_id, tokens) values (p_me, 30) on conflict (user_id) do nothing; ' +
        'perform 1 from public.mp_limits where user_id = p_me for update; return true; end $$',
    );
  }
  for (const [i, u] of [HOST, ...people(n)].entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query('insert into public.profiles (user_id, friend_code, nickname) values ($1, $2, $3)', [u, String(80000000 + i), `玩家${i}`]);
  }
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

const count = (res, f) => res.filter(f).length;
const open = async (db, host, game, seats, vis = 'public') =>
  (await burst(db, [[host, 'select public.mp_create_room($1, $2, $3) as r', [game, seats, vis]]]))[0].room.id;
const take = (u, room) => [u, 'select public.mp_join_listed($1) as r', [room]];

test('6 strangers take the one seat of a 2-seat room at once: exactly one gets it, the others hear "full"', async () => {
  await freshDb('l_two', 6);
  const room = await open('l_two', HOST, 'xiangqi', 2);
  const res = await burst('l_two', people(6).map((u) => take(u, room)));
  assert.equal(count(res, (r) => r.ok === true), 1, JSON.stringify(res));
  assert.equal(count(res, (r) => r.reason === 'full'), 5, JSON.stringify(res));
  const [row] = await admin('l_two', 'select * from public.mp_rooms where id = $1', [room]);
  assert.equal(row.status, 'playing');
  const winner = res.find((r) => r.ok === true);
  assert.equal(row.guest, winner.room.guest);
  const [{ n }] = await admin('l_two', 'select count(*)::int as n from public.mp_rooms');
  assert.equal(n, 1);
});

test('8 strangers go for a 4-seat room that already has 1 guest: exactly 2 get in, seats distinct, game starts', async () => {
  await freshDb('l_four', 8);
  const room = await open('l_four', HOST, 'mahjong', 4);
  const first = await burst('l_four', [take(people(8)[0], room)]);
  assert.equal(first[0].ok, true);
  const res = await burst('l_four', people(8).slice(1).map((u) => take(u, room)));
  assert.equal(count(res, (r) => r.ok === true), 2, JSON.stringify(res));
  assert.equal(count(res, (r) => r.reason === 'full'), 5);
  const [row] = await admin('l_four', 'select * from public.mp_rooms where id = $1', [room]);
  assert.equal(row.status, 'playing');
  const seated = [row.host, row.guest, row.guest2, row.guest3];
  assert.ok(seated.every(Boolean));
  assert.equal(new Set(seated).size, 4, 'four different people');
  assert.equal(row.bots, 0);
});

test('10 strangers go for an empty 4-seat room at once: exactly 3 sit, nobody twice', async () => {
  await freshDb('l_empty', 10);
  const room = await open('l_empty', HOST, 'holdem', 4);
  const res = await burst('l_empty', people(10).map((u) => take(u, room)));
  assert.equal(count(res, (r) => r.ok === true), 3, JSON.stringify(res));
  assert.equal(count(res, (r) => r.reason === 'full'), 7);
  const sides = res.filter((r) => r.ok).map((r) => r.room.side).sort();
  assert.deepEqual(sides, [1, 2, 3]);
});

test('one person fires 20 joins for the same room at once: seated once, answers are all ok', async () => {
  await freshDb('l_same', 1);
  const room = await open('l_same', HOST, 'mahjong', 4);
  const me = people(1)[0];
  const res = await burst('l_same', Array.from({ length: 20 }, () => take(me, room)));
  assert.equal(count(res, (r) => r.ok === true), 20, JSON.stringify(res.filter((r) => r.ok !== true).slice(0, 2)));
  const [row] = await admin('l_same', 'select * from public.mp_rooms where id = $1', [room]);
  assert.equal(row.guest, me);
  assert.equal(row.guest2, null);
  assert.equal(row.guest3, null);
});

test('one person tries to take 6 different rooms at once: at most 3 live rooms in total', async () => {
  await freshDb('l_cap', 7);
  const hosts = people(6);
  const rooms = [];
  for (const h of hosts) rooms.push(await open('l_cap', h, 'xiangqi', 2));
  const res = await burst('l_cap', rooms.map((r) => take(HOST, r)));
  assert.equal(count(res, (r) => r.ok === true), 3, JSON.stringify(res));
  assert.equal(count(res, (r) => r.reason === 'too_many_rooms'), 3);
  const [{ n }] = await admin('l_cap', 'select count(*)::int as n from public.mp_rooms where guest = $1', [HOST]);
  assert.equal(n, 3);
});

test('a host leaving while strangers join: one outcome, nobody is left half-seated', async () => {
  for (let round = 0; round < 8; round++) {
    const db = `l_leave_${round}`;
    await freshDb(db, 2);
    const room = await open(db, HOST, 'xiangqi', 2);
    const [a, b] = people(2);
    const res = await burst(db, [take(a, room), take(b, room), [HOST, 'select public.mp_leave($1, $2) as r', [room, 'resign']]]);
    const [row] = await admin(db, 'select * from public.mp_rooms where id = $1', [room]);
    assert.ok(count(res.slice(0, 2), (r) => r.ok === true) <= 1, JSON.stringify(res));
    if (row.status === 'waiting') assert.equal(row.guest, null);
    else assert.ok(['playing', 'done', 'abandoned'].includes(row.status));
  }
});

test('with the rate limit on: 40 list calls at once from one person, at most 10 get through', async () => {
  await freshDb('l_rate', 0, { noRateLimit: false });
  await admin(
    'l_rate',
    'insert into public.mp_limits (user_id, tokens) values ($1, 30) on conflict (user_id) do update set tokens = 30, updated_at = now()',
    [HOST],
  );
  const res = await burst('l_rate', Array.from({ length: 40 }, () => [HOST, 'select public.mp_list_rooms() as r', []]));
  const limited = count(res, (r) => r.reason === 'rate_limited');
  const served = count(res, (r) => r.ok === true);
  assert.equal(limited + served, 40, JSON.stringify(res.filter((r) => r.ok !== true && r.reason !== 'rate_limited').slice(0, 2)));
  assert.ok(served <= 11 && limited >= 29, `served ${served}, limited ${limited}`);
});
