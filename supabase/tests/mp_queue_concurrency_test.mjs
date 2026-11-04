// supabase/tests/mp_queue_concurrency_test.mjs
//
// 快速配對同一瞬間很多人按（PGlite 只有一條連線做不到）：啟一個真的 PostgreSQL
// （embedded-postgres），套 supabase_stubs.sql 與 friends、mp_rooms、mp_seats、
// mp_presence、mp_quick_match 幾支 migration，每個人各開一條連線同時打。
//
//   cd supabase/tests && npm install && npm run test:mp-queue-concurrency
//
// 測鎖的案例把每人限流關掉（免得限流擋住、看不出少了鎖）；一個案例開著限流。
//

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
  .filter((f) => f.endsWith('.sql') && (f.includes('friends') || f.includes('mp_rooms') || f.includes('mp_seats') || f.includes('mp_presence') || f.includes('mp_quick_match')))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const PORT = 54893;
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const A = uid(1);
const B = uid(2);

let server;
let dir;

test.before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'mp-pg-'));
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

/** A fresh database: A, B and [n] more people (uid(100+i)), all friends of B. */
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
      "create or replace function public.mp_take(p_me uuid, p_cost real) returns boolean language plpgsql as $$ begin " +
        "insert into public.mp_limits (user_id, tokens) values (p_me, 30) on conflict (user_id) do nothing; " +
        "perform 1 from public.mp_limits where user_id = p_me for update; return true; end $$",
    );
  }
  const people = [A, B, ...Array.from({ length: n }, (_, i) => uid(100 + i))];
  for (const [i, u] of people.entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query('insert into public.profiles (user_id, friend_code) values ($1, $2)', [u, String(50000000 + i)]);
  }
  for (const u of people.filter((x) => x !== B)) {
    await db.query(
      "insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')",
      [u, B],
    );
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
const press = (u, game, seats) => [u, 'select public.mp_queue_join($1, $2) as r', [game, seats]];

/** 每個人最後恰好在一間房裡（不多不少），回 { rooms, perUser } */
async function seating(database) {
  const rooms = await admin(database, 'select id, host, guest, guest2, guest3, seats, status from public.mp_rooms');
  const perUser = {};
  for (const r of rooms) for (const u of [r.host, r.guest, r.guest2, r.guest3]) if (u) perUser[u] = (perUser[u] || 0) + 1;
  return { rooms, perUser };
}

test('8 people press at once (2 seats): exactly 4 rooms, everyone in exactly one', async () => {
  await freshDb('q_pairs', 6);
  const users = [A, B, ...Array.from({ length: 6 }, (_, i) => uid(100 + i))];
  const res = await burst('q_pairs', users.map((u) => press(u, 'xiangqi', 2)));
  assert.equal(count(res, (r) => r.ok !== true), 0, JSON.stringify(res.filter((r) => r.ok !== true).slice(0, 2)));
  const { rooms, perUser } = await seating('q_pairs');
  assert.equal(rooms.length, 4);
  assert.ok(rooms.every((r) => r.status === 'playing' && r.guest && !r.guest2));
  for (const u of users) assert.equal(perUser[u], 1, `${u} is in ${perUser[u]} rooms`);
  // the people who got a reply of matched:true plus the ones holding a mailbox = everybody
  const mine = count(res, (r) => r.matched === true);
  const [{ n }] = await admin('q_pairs', 'select count(*)::int as n from public.mp_queue where room is not null');
  assert.equal(mine + n, 8);
  const [{ w }] = await admin('q_pairs', 'select count(*)::int as w from public.mp_queue where room is null');
  assert.equal(w, 0);
});

test('12 people press at once (4 seats): exactly 3 tables of 4', async () => {
  await freshDb('q_tables', 10);
  const users = [A, B, ...Array.from({ length: 10 }, (_, i) => uid(100 + i))];
  const res = await burst('q_tables', users.map((u) => press(u, 'mahjong', 4)));
  assert.equal(count(res, (r) => r.ok !== true), 0, JSON.stringify(res.filter((r) => r.ok !== true).slice(0, 2)));
  const { rooms, perUser } = await seating('q_tables');
  assert.equal(rooms.length, 3);
  assert.ok(rooms.every((r) => r.seats === 4 && r.guest && r.guest2 && r.guest3 && r.status === 'playing'));
  for (const u of users) assert.equal(perUser[u], 1);
});

test('5 people press at once (4 seats): one table, one person keeps waiting', async () => {
  await freshDb('q_five', 3);
  const users = [A, B, uid(100), uid(101), uid(102)];
  const res = await burst('q_five', users.map((u) => press(u, 'holdem', 4)));
  assert.equal(count(res, (r) => r.ok !== true), 0);
  const { rooms } = await seating('q_five');
  assert.equal(rooms.length, 1);
  const [{ w }] = await admin('q_five', 'select count(*)::int as w from public.mp_queue where room is null');
  assert.equal(w, 1);
});

test('two games at once do not mix people', async () => {
  await freshDb('q_games', 6);
  const users = [A, B, ...Array.from({ length: 6 }, (_, i) => uid(100 + i))];
  const res = await burst(
    'q_games',
    users.map((u, i) => press(u, i % 2 ? 'chess' : 'xiangqi', 2)),
  );
  assert.equal(count(res, (r) => r.ok !== true), 0);
  const rooms = await admin('q_games', 'select game, count(*)::int as n from public.mp_rooms group by game order by game');
  assert.deepEqual(rooms, [{ game: 'chess', n: 2 }, { game: 'xiangqi', n: 2 }]);
});

test('one person pressing from 20 phones at once: one queue row, no room', async () => {
  await freshDb('q_phones', 0);
  const res = await burst('q_phones', Array.from({ length: 20 }, () => press(A, 'xiangqi', 2)));
  assert.equal(count(res, (r) => r.ok === true && r.matched === false), 20, JSON.stringify(res.slice(0, 2)));
  const [{ n }] = await admin('q_phones', 'select count(*)::int as n from public.mp_queue');
  assert.equal(n, 1);
  const [{ r }] = await admin('q_phones', 'select count(*)::int as r from public.mp_rooms');
  assert.equal(r, 0, 'a person is never matched with themselves');
});

test('cancel races with a match: either cancelled with nobody matched, or matched and told so', async () => {
  for (let round = 0; round < 12; round++) {
    const db = `q_race_${round}`;
    await freshDb(db, 0);
    await burst(db, [press(A, 'xiangqi', 2)]);
    const res = await burst(db, [press(B, 'xiangqi', 2), [A, 'select public.mp_queue_leave() as r', []]]);
    const [join, leave] = res;
    const rooms = await admin(db, 'select id from public.mp_rooms');
    const waiting = await admin(db, 'select user_id from public.mp_queue where room is null');
    if (rooms.length === 1) {
      // matched: B was told, and A's cancel handed the room back (or A's row is still a mailbox)
      assert.equal(join.matched, true, JSON.stringify(res));
      if (leave.matched) assert.equal(leave.room.id, rooms[0].id);
      else {
        const box = await admin(db, 'select 1 from public.mp_queue where user_id = $1 and room is not null', [A]);
        assert.equal(box.length, 1, 'the match is not lost: A can still collect it');
      }
    } else {
      assert.equal(rooms.length, 0);
      assert.equal(join.matched, false, JSON.stringify(res));
      assert.equal(leave.matched, false);
      assert.deepEqual(waiting.map((w) => w.user_id), [B], 'A is gone, B waits alone');
    }
  }
});

test('with the rate limit on: 40 presses at once from one person, at most 7 get through', async () => {
  await freshDb('q_rate', 0, { noRateLimit: false });
  await admin('q_rate', 'update public.mp_limits set tokens = 30, updated_at = now()');
  const res = await burst('q_rate', Array.from({ length: 40 }, () => press(A, 'xiangqi', 2)));
  const limited = count(res, (r) => r.reason === 'rate_limited');
  const served = count(res, (r) => r.ok === true);
  assert.equal(limited + served, 40, JSON.stringify(res.filter((r) => r.ok !== true && r.reason !== 'rate_limited').slice(0, 2)));
  assert.ok(served <= 7 && limited >= 33, `served ${served}, limited ${limited}`);
});
