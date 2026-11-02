// supabase/tests/diamonds_test.mjs
//
// Runs supabase/migrations/*_diamonds.sql in PGlite on top of
// supabase_stubs.sql and checks the diamond RPCs: who earns, how often, the
// monthly cap, who can see what, and the 3-month expiry. "Today" is pinned by
// replacing public.diamond_today() (the migration keeps the date in that one
// function for this reason).
//
//   cd supabase/tests && npm install && npm run test:diamonds

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
  .filter((f) => f.endsWith('.sql') && f.includes('diamonds'))
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
  await today(db, '2026-11-02');
  return db;
}

/** Pins "today in Taipei" (superuser; the function stays closed to clients). */
const today = (db, day) =>
  db.exec(`create or replace function public.diamond_today() returns date language sql stable
    set search_path = '' as $$ select date '${day}' $$`);

/** Opens a subscription for [user] through [day] (what an admin does by hand). */
const subscribe = (db, user, day) =>
  db.query(
    `insert into public.subscriptions (user_id, active_until) values ($1, $2)
     on conflict (user_id) do update set active_until = excluded.active_until`,
    [user, day],
  );

/** Runs [sql] as [user] (role authenticated); refills the bucket first unless [throttle]. */
async function as(db, user, sql, params = [], { throttle = false } = {}) {
  if (!throttle) await db.exec('delete from public.diamond_buckets');
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user ?? '']);
  try {
    return await db.query(sql, params);
  } finally {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', '', false)");
  }
}
const balance = async (db, user, o) => (await as(db, user, 'select public.diamond_balance() as r', [], o)).rows[0].r;
const earn = async (db, user, minutes, o) =>
  (await as(db, user, 'select public.diamond_earn_exercise($1) as r', [minutes], o)).rows[0].r;

test('signed out: every call says so', async () => {
  const db = await fresh();
  assert.deepEqual(await balance(db, null), { ok: false, reason: 'signed_out' });
  assert.deepEqual(await earn(db, null, 20), { ok: false, reason: 'signed_out' });
  const r = (await as(db, null, "select public.diamond_redeem('x', 10) as r")).rows[0].r;
  assert.deepEqual(r, { ok: false, reason: 'signed_out' });
});

test('no subscription: nothing is paid', async () => {
  const db = await fresh();
  const r = await earn(db, me, 30);
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'not_subscribed');
  assert.equal(r.balance, 0);
  assert.equal((await balance(db, me)).subscribed, false);
});

test('an ended subscription earns nothing; today is the last day it covers', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-11-01');
  assert.equal((await earn(db, me, 30)).reason, 'not_subscribed');
  await subscribe(db, me, '2026-11-02');
  assert.equal((await earn(db, me, 30)).ok, true);
});

test('under 15 minutes pays nothing, 15 pays 10', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  for (const m of [0, 1, 14]) assert.equal((await earn(db, me, m)).reason, 'too_short', String(m));
  const r = await earn(db, me, 15);
  assert.equal(r.ok, true);
  assert.equal(r.earned, 10);
  assert.equal(r.balance, 10);
  assert.equal(r.month, 10);
  assert.equal(r.cap, 300);
});

test('nonsense minutes are refused', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  assert.equal((await earn(db, me, -5)).reason, 'bad_minutes');
  assert.equal((await earn(db, me, 1441)).reason, 'bad_minutes');
  assert.equal((await earn(db, me, null)).reason, 'bad_minutes');
});

test('the same day twice pays once; the next day pays again', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  assert.equal((await earn(db, me, 20)).earned, 10);
  const again = await earn(db, me, 60);
  assert.equal(again.ok, false);
  assert.equal(again.reason, 'already_today');
  assert.equal(again.balance, 10);
  await today(db, '2026-11-03');
  assert.equal((await earn(db, me, 20)).balance, 20);
});

test('Taipei is UTC+8: 17:30 UTC is already the next day there', async () => {
  const db = await fresh();
  const r = await db.query("select (timestamptz '2026-11-01 17:30:00+00' at time zone 'Asia/Taipei')::date as d");
  assert.equal(r.rows[0].d.toISOString().slice(0, 10), '2026-11-02');
});

test('month cap: 300 in a 31-day month, the 31st day pays nothing; the next month starts again', async () => {
  const db = await fresh();
  await subscribe(db, me, '2027-12-31');
  for (let d = 1; d <= 30; d++) {
    await today(db, `2026-12-${String(d).padStart(2, '0')}`);
    const r = await earn(db, me, 20);
    assert.equal(r.ok, true, `day ${d}`);
  }
  await today(db, '2026-12-31');
  const capped = await earn(db, me, 20);
  assert.equal(capped.ok, false);
  assert.equal(capped.reason, 'month_cap');
  assert.equal(capped.month, 300);
  assert.equal(capped.balance, 300);
  await today(db, '2027-01-01');
  const next = await earn(db, me, 20);
  assert.equal(next.ok, true);
  assert.equal(next.month, 10);
  assert.equal(next.balance, 310);
});

test('a leftover that does not fill a whole day never pays past 300', async () => {
  const db = await fresh();
  await subscribe(db, me, '2027-12-31');
  for (let d = 1; d <= 29; d++) {
    await db.query(
      `insert into public.diamond_ledger (user_id, day, delta, reason) values ($1, $2, $3, 'earn_exercise')`,
      [me, `2026-12-${String(d).padStart(2, '0')}`, d === 29 ? 15 : 10],
    );
  }
  await today(db, '2026-12-30');
  const r = await earn(db, me, 20);
  assert.equal(r.earned, 5);
  assert.equal(r.month, 300);
});

test('each account only sees its own diamonds and subscription', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  await subscribe(db, other, '2026-12-31');
  await earn(db, me, 20);
  const theirs = await balance(db, other);
  assert.equal(theirs.balance, 0);
  assert.equal(theirs.month, 0);
  assert.equal((await balance(db, me)).balance, 10);
  const subs = (await as(db, me, 'select user_id from public.subscriptions')).rows;
  assert.deepEqual(subs.map((r) => r.user_id), [me]);
});

test('no direct table writes, no direct ledger or bucket reads, no helpers', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  await earn(db, me, 20);
  for (const sql of [
    'select * from public.diamond_ledger',
    `insert into public.diamond_ledger (user_id, day, delta, reason) values ('${me}', date '2026-11-05', 10, 'earn_exercise')`,
    'update public.diamond_ledger set delta = 1000',
    'delete from public.diamond_ledger',
    'select * from public.diamond_buckets',
    `insert into public.subscriptions (user_id, active_until) values ('${other}', date '2030-01-01')`,
    "update public.subscriptions set active_until = date '2030-01-01'",
    'delete from public.subscriptions',
    `select public.diamond_take('${me}')`,
    `select public.diamond_settle('${me}', date '2026-11-02')`,
    `select public.diamond_snapshot('${me}', date '2026-11-02')`,
    'select public.diamond_today()',
  ]) {
    await assert.rejects(as(db, me, sql), /permission denied/, sql);
  }
  assert.equal((await balance(db, me)).balance, 10);
});

test('the ledger refuses UPDATE even for an admin', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  await earn(db, me, 20);
  await assert.rejects(db.exec('update public.diamond_ledger set delta = 500'), /append-only/);
});

test('redeem is not open yet', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  await earn(db, me, 20);
  const r = (await as(db, me, "select public.diamond_redeem('pen', 100) as r")).rows[0].r;
  assert.deepEqual(r, { ok: false, reason: 'not_open' });
  assert.equal((await balance(db, me)).balance, 10);
});

test('kept for 3 months after the subscription ends, then zeroed once', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-11-30');
  await earn(db, me, 20); // 10
  // Cancelled: active_until stays 2026-11-30. Last kept day is 2027-02-28.
  await today(db, '2027-02-28');
  let b = await balance(db, me);
  assert.equal(b.balance, 10);
  assert.equal(b.subscribed, false);
  await today(db, '2027-03-01');
  b = await balance(db, me);
  assert.equal(b.balance, 0);
  const rows = (await db.query('select delta, reason, ref from public.diamond_ledger order by id')).rows;
  assert.deepEqual(rows.map((r) => [r.reason, r.delta]), [['earn_exercise', 10], ['expire', -10]]);
  assert.equal(rows[1].ref, '2026-11-30');
  // Asking again does not write a second expire row.
  await balance(db, me);
  await balance(db, me);
  assert.equal((await db.query("select count(*)::int as n from public.diamond_ledger where reason = 'expire'")).rows[0].n, 1);
});

test('earning also settles an expired balance first; re-subscribing starts clean', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-11-30');
  await earn(db, me, 20);
  await today(db, '2027-06-01');
  await subscribe(db, me, '2027-12-31');
  const r = await earn(db, me, 20);
  assert.equal(r.ok, true);
  assert.equal(r.balance, 10); // the old 10 expired, today's 10 counts
});

test('re-subscribing within 3 months keeps the old diamonds', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-11-30');
  await earn(db, me, 20);
  await today(db, '2027-01-15');
  await subscribe(db, me, '2027-02-15');
  const b = await balance(db, me);
  assert.equal(b.balance, 10);
  assert.equal(b.subscribed, true);
});

test('rate limit: hammering runs dry, others are unaffected', async () => {
  const db = await fresh();
  let limited = 0;
  for (let i = 0; i < 15; i++) {
    const r = await balance(db, me, { throttle: true });
    if (r.reason === 'rate_limited') limited++;
  }
  assert.equal(limited, 5);
  assert.equal((await earn(db, me, 20, { throttle: true })).reason, 'rate_limited');
  assert.equal((await balance(db, other, { throttle: true })).ok, true);
});

test('deleting the account deletes its diamonds and subscription', async () => {
  const db = await fresh();
  await subscribe(db, me, '2026-12-31');
  await earn(db, me, 20);
  await db.query('delete from auth.users where id = $1', [me]);
  assert.equal((await db.query('select count(*)::int as n from public.diamond_ledger')).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int as n from public.subscriptions')).rows[0].n, 0);
});
