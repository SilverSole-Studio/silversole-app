// supabase/tests/game_saves_test.mjs
//
// Runs supabase/migrations/*_game_saves.sql in PGlite on top of
// supabase_stubs.sql and checks the two RPCs: who can read and write, the size
// and JSON checks, the rev compare-and-swap and the per-user rate limit.
//
//   cd supabase/tests && npm install && npm run test:saves

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const here = dirname(fileURLToPath(import.meta.url));
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8');
const migrationsDir = join(here, '..', 'migrations');
const migration = readdirSync(migrationsDir)
  .filter((f) => f.endsWith('.sql') && f.includes('game_saves'))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const me = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';

async function fresh() {
  const db = new PGlite();
  await db.exec(stubs);
  await db.exec(migration);
  for (const u of [me, other]) await db.query('insert into auth.users (id) values ($1)', [u]);
  return db;
}

/** Runs [sql] as [user] (role authenticated); refills the bucket first unless [throttle]. */
async function as(db, user, sql, params = [], { throttle = false } = {}) {
  if (!throttle) await db.exec('delete from public.game_save_buckets');
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user ?? '']);
  try {
    return await db.query(sql, params);
  } finally {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', '', false)");
  }
}
const load = async (db, user, o) => (await as(db, user, 'select public.game_save_load() as r', [], o)).rows[0].r;
const store = async (db, user, rev, data, o) =>
  (await as(db, user, 'select public.game_save_store($1, $2) as r', [rev, data], o)).rows[0].r;

test('signed out: both calls say so', async () => {
  const db = await fresh();
  assert.deepEqual(await load(db, null), { ok: false, reason: 'signed_out' });
  assert.deepEqual(await store(db, null, 0, '{}'), { ok: false, reason: 'signed_out' });
});

test('first load is empty, first save is rev 1, load returns it', async () => {
  const db = await fresh();
  const empty = await load(db, me);
  assert.equal(empty.ok, true);
  assert.equal(empty.rev, 0);
  assert.equal(empty.data, null);
  assert.deepEqual(await store(db, me, 0, '{"coins":5}'), { ok: true, rev: 1 });
  const got = await load(db, me);
  assert.equal(got.rev, 1);
  assert.equal(got.data, '{"coins":5}');
  assert.ok(got.savedAt);
});

test('a stale rev is refused with the current rev and does not overwrite', async () => {
  const db = await fresh();
  await store(db, me, 0, '{"a":1}');
  await store(db, me, 1, '{"a":2}');
  assert.deepEqual(await store(db, me, 1, '{"a":"old phone"}'), { ok: false, reason: 'conflict', rev: 2 });
  assert.equal((await load(db, me)).data, '{"a":2}');
});

test('too big and not-JSON are refused', async () => {
  const db = await fresh();
  assert.equal((await store(db, me, 0, '{"x":"' + 'a'.repeat(262144) + '"}')).reason, 'too_big');
  assert.equal((await store(db, me, 0, 'not json')).reason, 'bad_data');
  assert.equal((await store(db, me, 0, null)).reason, 'too_big');
  assert.equal((await load(db, me)).rev, 0);
});

test('each account only sees and writes its own save', async () => {
  const db = await fresh();
  await store(db, me, 0, '{"mine":true}');
  const theirs = await load(db, other);
  assert.equal(theirs.rev, 0);
  assert.equal(theirs.data, null);
  await store(db, other, 0, '{"theirs":true}');
  assert.equal((await load(db, me)).data, '{"mine":true}');
});

test('no direct table access, no direct bucket helper', async () => {
  const db = await fresh();
  await store(db, me, 0, '{}');
  for (const sql of [
    'select * from public.game_saves',
    "update public.game_saves set data = '{}'",
    `insert into public.game_saves (user_id, rev, data) values ('${me}', 99, '{}')`,
    'select * from public.game_save_buckets',
    `select public.game_save_take('${me}')`,
  ]) {
    await assert.rejects(as(db, me, sql), /permission denied/, sql);
  }
});

test('rate limit: hammering the RPC runs dry, others are unaffected', async () => {
  const db = await fresh();
  let limited = 0;
  for (let i = 0; i < 15; i++) {
    const r = await load(db, me, { throttle: true });
    if (r.reason === 'rate_limited') limited++;
  }
  assert.equal(limited, 5); // capacity 10, time does not move in PGlite
  assert.equal((await store(db, me, 0, '{}', { throttle: true })).reason, 'rate_limited');
  assert.equal((await load(db, other, { throttle: true })).ok, true);
});

test('deleting the account deletes the save', async () => {
  const db = await fresh();
  await store(db, me, 0, '{}');
  await db.query('delete from auth.users where id = $1', [me]);
  assert.equal((await db.query('select count(*)::int as n from public.game_saves')).rows[0].n, 0);
});
