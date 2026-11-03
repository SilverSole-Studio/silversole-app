// supabase/tests/mp_concurrency_test.mjs
//
// The online-play cases PGlite cannot play (one connection): many calls at the
// same instant. Starts a real PostgreSQL on this machine (embedded-postgres,
// MIT), applies supabase_stubs.sql plus the friends and mp_rooms migrations,
// and fires the calls from separate connections at once.
//
//   cd supabase/tests && npm install && npm run test:mp-concurrency
//
// Cases that test a lock turn the per-person rate limit off (so the limiter
// does not hide a missing lock); one case leaves it on.

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
  .filter((f) => f.endsWith('.sql') && (f.includes('friends') || f.includes('mp_rooms')))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const PORT = 54891;
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

test('60 rooms opened at once by one person: exactly 3 live, never more', async () => {
  await freshDb('mp_rooms_cap', 0);
  const res = await burst('mp_rooms_cap', Array.from({ length: 60 }, () => [A, "select public.mp_create_room('xiangqi') as r", []]));
  assert.equal(count(res, (r) => r.ok === true), 3, JSON.stringify(res.filter((r) => r.ok !== true).slice(0, 2)));
  assert.equal(count(res, (r) => r.reason === 'too_many_rooms'), 57);
  const [{ n }] = await admin('mp_rooms_cap', "select count(*)::int as n from public.mp_rooms where host = $1 and status = 'waiting'", [A]);
  assert.equal(n, 3);
  const [{ d }] = await admin('mp_rooms_cap', 'select count(distinct code)::int as d from public.mp_rooms');
  assert.equal(d, 3, 'three different codes');
});

test('the same move sent 40 times at once is stored once', async () => {
  await freshDb('mp_dup', 0);
  // set up the room as the two players would
  const room = await burst('mp_dup', [[A, "select public.mp_create_room('xiangqi') as r", []]]);
  const code = room[0].room.code;
  const id = room[0].room.id;
  assert.equal((await burst('mp_dup', [[B, 'select public.mp_join_room($1, $2) as r', [code, 'xiangqi']]]))[0].ok, true);
  const res = await burst(
    'mp_dup',
    Array.from({ length: 40 }, () => [A, 'select public.mp_submit_move($1, 1, $2::jsonb) as r', [id, '{"f":"h2","t":"e2"}']]),
  );
  assert.equal(count(res, (r) => r.ok === true && !r.dup), 1, JSON.stringify(res.slice(0, 3)));
  assert.equal(count(res, (r) => r.ok === true && r.dup === true), 39);
  const [row] = await admin('mp_dup', 'select seq, jsonb_array_length(moves)::int as n from public.mp_rooms where id = $1', [id]);
  assert.deepEqual([row.seq, row.n], [1, 1]);
});

test('both players move at the same instant: exactly one move lands', async () => {
  await freshDb('mp_both', 0);
  const room = (await burst('mp_both', [[A, "select public.mp_create_room('xiangqi') as r", []]]))[0].room;
  await burst('mp_both', [[B, 'select public.mp_join_room($1, null) as r', [room.code]]]);
  const jobs = [];
  for (let i = 0; i < 20; i++) {
    jobs.push([A, 'select public.mp_submit_move($1, 1, $2::jsonb) as r', [room.id, '{"by":"A"}']]);
    jobs.push([B, 'select public.mp_submit_move($1, 1, $2::jsonb) as r', [room.id, '{"by":"B"}']]);
  }
  const res = await burst('mp_both', jobs);
  assert.equal(count(res, (r) => r.ok === true && !r.dup), 1);
  const [row] = await admin('mp_both', 'select seq, moves from public.mp_rooms where id = $1', [room.id]);
  assert.equal(row.seq, 1);
  assert.deepEqual(row.moves, [{ by: 0, m: { by: 'A' } }], 'only the host (whose turn it is) can have moved');
});

test('30 people try to sit in the same room at once: exactly one gets the seat', async () => {
  await freshDb('mp_seat', 30);
  const room = (await burst('mp_seat', [[A, "select public.mp_create_room('xiangqi') as r", []]]))[0].room;
  const res = await burst(
    'mp_seat',
    Array.from({ length: 30 }, (_, i) => [uid(100 + i), 'select public.mp_join_room($1, $2) as r', [room.code, 'xiangqi']]),
  );
  assert.equal(count(res, (r) => r.ok === true), 1, JSON.stringify(res.slice(0, 3)));
  const [row] = await admin('mp_seat', 'select status, guest from public.mp_rooms where id = $1', [room.id]);
  assert.equal(row.status, 'playing');
  assert.ok(row.guest);
});

test('one person joining the same room from 20 phones at once: still one seat, same room', async () => {
  await freshDb('mp_phones', 0);
  const room = (await burst('mp_phones', [[A, "select public.mp_create_room('xiangqi') as r", []]]))[0].room;
  const res = await burst('mp_phones', Array.from({ length: 20 }, () => [B, 'select public.mp_join_room($1, $2) as r', [room.code, 'xiangqi']]));
  assert.equal(count(res, (r) => r.ok === true && r.room.id === room.id), 20);
  const [{ n }] = await admin('mp_phones', 'select count(*)::int as n from public.mp_rooms');
  assert.equal(n, 1);
});

test('20 friends invite the same person at once: at most 5 invites wait for them', async () => {
  await freshDb('mp_invite', 20);
  const res = await burst(
    'mp_invite',
    Array.from({ length: 20 }, (_, i) => [uid(100 + i), "select public.mp_invite($1, 'xiangqi') as r", [B]]),
  );
  assert.equal(count(res, (r) => r.ok === true), 5, JSON.stringify(res.filter((r) => r.ok !== true).slice(0, 2)));
  assert.equal(count(res, (r) => r.reason === 'invitee_busy'), 15);
  const [{ n }] = await admin('mp_invite', "select count(*)::int as n from public.mp_rooms where invited = $1 and status = 'waiting'", [B]);
  assert.equal(n, 5);
});

test('30 code guesses at once: exactly 5 are counted as misses, the rest are locked out', async () => {
  await freshDb('mp_guess', 0);
  await burst('mp_guess', [[A, "select public.mp_create_room('xiangqi') as r", []]]);
  const res = await burst(
    'mp_guess',
    Array.from({ length: 30 }, (_, i) => [B, 'select public.mp_join_room($1, $2) as r', [String(100000 + i), 'xiangqi']]),
  );
  assert.equal(count(res, (r) => r.reason === 'bad_code'), 5, JSON.stringify(res.slice(0, 8)));
  assert.equal(count(res, (r) => r.reason === 'locked'), 25);
});

test('with the rate limit on: 60 calls at once from one person, at most 30 get through', async () => {
  await freshDb('mp_rate', 0, { noRateLimit: false });
  const room = (await burst('mp_rate', [[A, "select public.mp_create_room('xiangqi') as r", []]]))[0].room;
  await burst('mp_rate', [[B, 'select public.mp_join_room($1, null) as r', [room.code]]]);
  await admin('mp_rate', 'update public.mp_limits set tokens = 30, updated_at = now()');
  const res = await burst('mp_rate', Array.from({ length: 60 }, () => [A, 'select public.mp_submit_move($1, 7, $2::jsonb) as r', [room.id, '{"a":1}']]));
  const limited = count(res, (r) => r.reason === 'rate_limited');
  const served = count(res, (r) => r.reason === 'seq_mismatch');
  assert.equal(limited + served, 60, JSON.stringify(res.filter((r) => r.reason !== 'rate_limited' && r.reason !== 'seq_mismatch').slice(0, 2)));
  assert.ok(served <= 31 && limited >= 29, `served ${served}, limited ${limited}`);
});
