// supabase/tests/aa_rpc_test.mjs
//
// Runs supabase/migrations/*_active_aging.sql in PGlite on top of supabase_stubs.sql
// and checks the 12 銀足樂齡 RPCs: who can call them, the invite code, the server-side
// range / enum / size checks, idempotent resends, consent rules and the erase tombstone.
// Concurrency is not covered (PGlite has a single connection).
//
//   cd supabase/tests && npm install && node --test aa_rpc_test.mjs

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
  .filter((f) => f.endsWith('.sql') && f.includes('active_aging'))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const ann = '00000000-0000-4000-8000-000000000001';
const bob = '00000000-0000-4000-8000-000000000002';
const eve = '00000000-0000-4000-8000-000000000003';
const sid = '11111111-1111-4111-8111-111111111111';
const sid2 = '22222222-2222-4222-8222-222222222222';
const mid1 = '33333333-3333-4333-8333-333333333331';
const mid2 = '33333333-3333-4333-8333-333333333332';

async function fresh() {
  const db = new PGlite();
  await db.exec(stubs);
  await db.exec(migration);
  for (const u of [ann, bob, eve]) await db.query('insert into auth.users (id) values ($1)', [u]);
  return db;
}

/** Calls an RPC as [user] (role authenticated). Refills the bucket first unless [throttle]. */
async function rpc(db, user, fn, args = [], { throttle = false } = {}) {
  if (!throttle) await db.exec('delete from public.aa_rate_buckets');
  const ph = args.map((_, i) => `$${i + 1}`).join(', ');
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user ?? '']);
  try {
    const r = await db.query(`select public.${fn}(${ph}) as r`, args.map((a) => (a !== null && typeof a === 'object' ? JSON.stringify(a) : a)));
    return r.rows[0].r;
  } finally {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', '', false)");
  }
}

async function activate(db, user, role = 'instructor') {
  await db.query('select public.aa_admin_role_set($1, $2, false)', [user, role]);
}

const iso = (offsetMs = 0) => new Date(Date.now() + offsetMs).toISOString();
const startedAt = iso(-3600_000);
const sessionArgs = (over = {}) => ({
  id: sid, site: '三峽據點', series: 'steady', type: 'measure', planned_count: 20,
  aed_location: '大門口', started_at: startedAt, ...over,
});
const part = (code = 'P01', over = {}) => ({
  code, rolled: true, answers: { unwell: 'no', meds: 'no', fell: 'no' }, seated: false,
  reasons: [], group: 'A', ...over,
});
const consent = (code = 'P01', type = 'measure', granted = true, over = {}) => ({
  code, type, granted, version: 'v1', method: 'paper', at: iso(-1800_000), ...over,
});
const meas = (over = {}) => ({
  mid: mid1, code: 'P01', item: 'chair30', side: '', human1: 12, human2: 12, camera: 11, camera2: 13,
  camera_valid: true, camera_note: '', cam_fps: 28, cam_detect: 0.98, assisted: false, note: '',
  at: iso(-600_000), ...over,
});

/** Instructor ann with an open measure session, P01 present and consented. */
async function ready() {
  const db = await fresh();
  await activate(db, ann);
  assert.equal((await rpc(db, ann, 'aa_session_upsert', [sessionArgs()])).ok, true);
  assert.equal((await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P01')]])).ok, true);
  assert.equal((await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P01')]])).ok, true);
  return db;
}

test('signed out and not a member are told apart; aa_me is false for everyone else', async () => {
  const db = await fresh();
  assert.deepEqual(await rpc(db, null, 'aa_me'), { ok: false, reason: 'signed_out' });
  assert.deepEqual(await rpc(db, ann, 'aa_me'), { ok: true, active: false, role: null });
  assert.deepEqual(await rpc(db, ann, 'aa_session_upsert', [sessionArgs()]), { ok: false, reason: 'not_member' });
  assert.deepEqual(await rpc(db, ann, 'aa_session_list'), { ok: false, reason: 'not_member' });
  await activate(db, ann, 'assistant');
  assert.deepEqual(await rpc(db, ann, 'aa_me'), { ok: true, active: true, role: 'assistant' });
});

test('tables are closed to the app roles; anon cannot call the RPCs', async () => {
  const db = await ready();
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [ann]);
  for (const t of ['aa_sessions', 'aa_measurements', 'aa_roles', 'aa_invites', 'aa_audit']) {
    await assert.rejects(db.query(`select * from public.${t}`), /permission denied/);
    await assert.rejects(db.query(`delete from public.${t}`), /permission denied/);
  }
  await assert.rejects(db.query('select public.aa_admin_purge_expired()'), /permission denied/);
  await assert.rejects(db.query('select public.aa_gate(1, true)'), /permission denied/);
  await db.exec('reset role');
  await db.exec('set role anon');
  await assert.rejects(db.query('select public.aa_me()'), /permission denied/);
  await db.exec('reset role');
});

test('invite: wrong codes lock the user; a good code works once; stopped codes stop', async () => {
  const db = await fresh();
  const made = (await db.query("select public.aa_admin_invite_create('assistant', '三峽', 1, 14) as r")).rows[0].r;
  assert.match(made.code, /^[1-9][0-9]{7}$/);
  // A code that does not exist, one that is the wrong shape: both just 'invalid'.
  assert.deepEqual(await rpc(db, bob, 'aa_invite_redeem', ['12345678']), { ok: false, reason: 'invalid' });
  assert.deepEqual(await rpc(db, bob, 'aa_invite_redeem', ['abc']), { ok: false, reason: 'invalid' });
  // The 5th failure in a row locks; even the right code is refused while locked.
  for (let i = 0; i < 3; i++) await rpc(db, bob, 'aa_invite_redeem', ['12345679']);
  assert.deepEqual(await rpc(db, bob, 'aa_invite_redeem', [made.code]), { ok: false, reason: 'rate_limited' });
  // Wiping the bucket or deleting the account does not wipe the attempts.
  const n = (await db.query('select count(*)::int as n from public.aa_invite_attempts where not ok')).rows[0].n;
  assert.equal(n, 5);
  // Another user with the right code gets in; a second user cannot reuse a one-use code.
  assert.deepEqual(await rpc(db, ann, 'aa_invite_redeem', [made.code]), { ok: true, role: 'assistant' });
  assert.deepEqual(await rpc(db, eve, 'aa_invite_redeem', [made.code]), { ok: false, reason: 'invalid' });
  // Redeeming again as the same user is a no-op, not a second use.
  assert.deepEqual(await rpc(db, ann, 'aa_invite_redeem', [made.code]), { ok: true, role: 'assistant' });
  assert.equal((await db.query('select used_count from public.aa_invites')).rows[0].used_count, 1);
  // Reissue disables the old code and hands out a new one.
  const again = (await db.query('select public.aa_admin_invite_reissue($1) as r', [made.id])).rows[0].r;
  assert.notEqual(again.code, made.code);
  assert.deepEqual(await rpc(db, eve, 'aa_invite_redeem', [again.code]), { ok: true, role: 'assistant' });
  // A revoked person cannot come back with a new code.
  await db.query('select public.aa_admin_role_set($1, null, true)', [eve]);
  const third = (await db.query("select public.aa_admin_invite_create('instructor') as r")).rows[0].r;
  assert.deepEqual(await rpc(db, eve, 'aa_invite_redeem', [third.code]), { ok: false, reason: 'forbidden' });
  assert.deepEqual(await rpc(db, eve, 'aa_me'), { ok: true, active: false, role: null });
});

test('an expired or disabled invite is just invalid', async () => {
  const db = await fresh();
  const a = (await db.query("select public.aa_admin_invite_create('instructor') as r")).rows[0].r;
  await db.query('update public.aa_invites set expires_at = now() - interval \'1 minute\' where id = $1', [a.id]);
  assert.deepEqual(await rpc(db, ann, 'aa_invite_redeem', [a.code]), { ok: false, reason: 'invalid' });
  const b = (await db.query("select public.aa_admin_invite_create('instructor') as r")).rows[0].r;
  await db.query('select public.aa_admin_invite_disable($1)', [b.id]);
  assert.deepEqual(await rpc(db, bob, 'aa_invite_redeem', [b.code]), { ok: false, reason: 'invalid' });
});

test('session: idempotent resend, owner fixed, others get forbidden, fields checked', async () => {
  const db = await fresh();
  await activate(db, ann);
  await activate(db, bob);
  assert.equal((await rpc(db, ann, 'aa_session_upsert', [sessionArgs()])).ok, true);
  assert.equal((await rpc(db, ann, 'aa_session_upsert', [sessionArgs({ planned_count: 25 })])).ok, true);
  assert.equal((await db.query('select count(*)::int n from public.aa_sessions')).rows[0].n, 1);
  assert.equal((await db.query('select planned_count from public.aa_sessions')).rows[0].planned_count, 25);
  assert.deepEqual(await rpc(db, bob, 'aa_session_upsert', [sessionArgs({ site: '偷' })]), { ok: false, reason: 'forbidden' });
  assert.equal((await db.query('select owner_id from public.aa_sessions')).rows[0].owner_id, ann);
  // series / type are fixed once created.
  assert.deepEqual(await rpc(db, ann, 'aa_session_upsert', [sessionArgs({ series: 'hands' })]), { ok: false, reason: 'invalid' });
  for (const bad of [
    { series: 'x' }, { type: 'x' }, { planned_count: 41 }, { planned_count: -1 }, { planned_count: 1.5 },
    { site: '' }, { site: 'a'.repeat(61) }, { aed_location: 'a'.repeat(61) }, { id: 'nope' },
    { started_at: 'now' }, { started_at: iso(3 * 86400_000) }, { extra: 1 },
  ]) {
    assert.equal((await rpc(db, ann, 'aa_session_upsert', [sessionArgs({ id: sid2, ...bad })])).reason, 'invalid', JSON.stringify(bad));
  }
});

test('session: at most 3 open sessions per person', async () => {
  const db = await fresh();
  await activate(db, ann);
  for (let i = 1; i <= 3; i++) {
    const id = `44444444-4444-4444-8444-44444444444${i}`;
    assert.equal((await rpc(db, ann, 'aa_session_upsert', [sessionArgs({ id })])).ok, true);
  }
  assert.deepEqual(await rpc(db, ann, 'aa_session_upsert', [sessionArgs({ id: sid2 })]), { ok: false, reason: 'too_large' });
});

test('participants: whitelist keys, enums and the 60 cap', async () => {
  const db = await ready();
  for (const bad of [
    { code: 'X1' }, { code: 'P1' }, { name: '王大明' }, { rolled: 'yes' }, { group: 'C' },
    { answers: { unwell: 'maybe' } }, { answers: { other: 'no' } }, { reasons: ['bad'] },
    { reasons: ['fell', 'fell'] }, { reasons: ['unwell', 'meds', 'fell', 'fell'] },
  ]) {
    const r = await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P02', bad)]]);
    assert.deepEqual(r, { ok: false, reason: 'invalid' }, JSON.stringify(bad));
  }
  // One bad row means none is written.
  assert.equal((await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P02'), part('P03', { group: 'Z' })]])).ok, false);
  assert.equal((await db.query('select count(*)::int n from public.aa_participants')).rows[0].n, 1);
  assert.equal((await rpc(db, ann, 'aa_participants_upsert', [sid, Array.from({ length: 61 }, (_, i) => part(`P${i + 10}`))])).reason, 'too_large');
  const rows = Array.from({ length: 59 }, (_, i) => part(`P${i + 10}`));
  assert.deepEqual(await rpc(db, ann, 'aa_participants_upsert', [sid, rows]), { ok: true, n: 59 });
  assert.equal((await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P200')]])).reason, 'too_large');
  // Re-sending an existing code is an update, not a new row.
  assert.equal((await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P01', { seated: true })]])).ok, true);
  assert.equal((await db.query("select seated from public.aa_participants where code = 'P01'")).rows[0].seated, true);
});

test('another user cannot read or write my session; not-found looks the same', async () => {
  const db = await ready();
  await activate(db, bob);
  for (const [fn, args] of [
    ['aa_participants_upsert', [sid, [part('P09')]]],
    ['aa_measurements_upsert', [sid, [meas()]]],
    ['aa_session_pull', [sid]],
    ['aa_session_close', [sid, iso()]],
    ['aa_session_delete', [sid]],
    ['aa_participant_erase', [sid, 'P01']],
    ['aa_session_pull', [sid2]],
  ]) {
    assert.deepEqual(await rpc(db, bob, fn, args), { ok: false, reason: 'forbidden' }, fn);
  }
  assert.deepEqual((await rpc(db, bob, 'aa_session_list')).sessions, []);
});

test('measurements: no consent, empty, ranges, time window, enums, partial accept', async () => {
  const db = await ready();
  await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P02')]]);
  const m = (over) => rpc(db, ann, 'aa_measurements_upsert', [sid, [meas(over)]]);
  const reason = async (over) => (await m(over)).rejected[0]?.reason ?? 'accepted';
  assert.equal(await reason({}), 'accepted');
  // P02 has no measure consent; a granted portrait does not count.
  assert.equal(await reason({ mid: mid2, code: 'P02' }), 'no_consent');
  await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P02', 'portrait')]]);
  assert.equal(await reason({ mid: mid2, code: 'P02' }), 'no_consent');
  // Not a person who was ever checked in.
  assert.equal(await reason({ mid: mid2, code: 'P77' }), 'no_consent');
  assert.equal(await reason({ mid: mid2, human1: null, human2: null, camera: null, camera2: null, camera_valid: null }), 'empty');
  assert.equal(await reason({ mid: mid2, human1: 61 }), 'out_of_range');
  assert.equal(await reason({ mid: mid2, human1: 12.5 }), 'out_of_range');
  assert.equal(await reason({ mid: mid2, human1: -1 }), 'out_of_range');
  assert.equal(await reason({ mid: mid2, item: 'sls', side: 'L', human1: 45.1 }), 'out_of_range');
  assert.equal(await reason({ mid: mid2, item: 'sls', side: 'L', human1: 30.25 }), 'out_of_range');
  assert.equal(await reason({ mid: mid2, item: 'sls', side: 'L', human1: 30.2, human2: 31.5, camera: 29.9, camera2: null, camera_valid: true }), 'accepted');
  assert.equal(await reason({ mid: mid2, item: 'sls', side: '' }), 'invalid');
  assert.equal(await reason({ mid: mid2, item: 'chair30', side: 'L' }), 'invalid');
  assert.equal(await reason({ mid: mid2, item: 'jump' }), 'invalid');
  assert.equal(await reason({ mid: mid2, cam_fps: 121 }), 'out_of_range');
  assert.equal(await reason({ mid: mid2, cam_detect: 1.1 }), 'out_of_range');
  assert.equal(await reason({ mid: mid2, camera: null, camera2: null, camera_valid: true }), 'invalid');
  assert.equal(await reason({ mid: mid2, note: 'x'.repeat(201) }), 'invalid');
  assert.equal(await reason({ mid: mid2, name: '王' }), 'invalid');
  assert.equal(await reason({ mid: mid2, human1: '12' }), 'invalid');
  assert.equal(await reason({ mid: mid2, at: iso(2 * 86400_000) }), 'bad_time');
  assert.equal(await reason({ mid: mid2, at: iso(-3 * 86400_000) }), 'bad_time');
  assert.equal(await reason({ mid: mid2, at: 'now' }), 'bad_time');
  assert.equal(await reason({ mid: 'x' }), 'invalid');
  // A mixed batch keeps the good rows.
  const r = await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas({ mid: '33333333-3333-4333-8333-333333333338' }), meas({ mid: '33333333-3333-4333-8333-333333333339', human1: 99 })]]);
  assert.equal(r.accepted, 1);
  assert.equal(r.rejected.length, 1);
  assert.equal(r.rejected[0].reason, 'out_of_range');
});

test('measurements: resend is idempotent, code and item are fixed, other sessions are out of reach', async () => {
  const db = await ready();
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas()]])).accepted, 1);
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas({ human1: 14 })]])).accepted, 1);
  assert.equal((await db.query('select count(*)::int n from public.aa_measurements')).rows[0].n, 1);
  assert.equal(Number((await db.query('select human1 from public.aa_measurements')).rows[0].human1), 14);
  await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P02')]]);
  await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P02')]]);
  const r = await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas({ code: 'P02' })]]);
  assert.deepEqual(r.rejected, [{ mid: mid1, reason: 'immutable' }]);
  // Bob uses the same mid in his own session: Ann's row stays untouched.
  await activate(db, bob);
  await rpc(db, bob, 'aa_session_upsert', [sessionArgs({ id: sid2 })]);
  await rpc(db, bob, 'aa_participants_upsert', [sid2, [part('P01')]]);
  await rpc(db, bob, 'aa_consents_upsert', [sid2, [consent('P01')]]);
  assert.equal((await rpc(db, bob, 'aa_measurements_upsert', [sid2, [meas({ human1: 1, human2: 1, camera: 1, camera2: 1 })]])).accepted, 1);
  const rows = (await db.query('select session_id, human1 from public.aa_measurements order by human1')).rows;
  assert.equal(rows.length, 2);
  assert.equal(Number(rows.find((x) => x.session_id === sid).human1), 14);
});

test('consent: latest wins, an old resend cannot undo a withdrawal, history is append-only', async () => {
  const db = await ready();
  const t0 = iso(-1800_000);
  const t1 = iso(-900_000);
  assert.equal((await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P01', 'measure', false, { at: t1 })]])).ok, true);
  assert.equal((await db.query("select granted from public.aa_consents where type = 'measure'")).rows[0].granted, false);
  // The first (older) "granted" arrives again from the offline queue.
  await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P01', 'measure', true, { at: t0 })]]);
  assert.equal((await db.query("select granted from public.aa_consents where type = 'measure'")).rows[0].granted, false);
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas()]])).rejected[0].reason, 'no_consent');
  // Same row again does not add history.
  await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P01', 'measure', false, { at: t1 })]]);
  assert.equal((await db.query("select count(*)::int n from public.aa_consent_history where type = 'measure'")).rows[0].n, 2);
  // One row per type; research is its own row.
  await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P01', 'research', false)]]);
  assert.equal((await db.query('select count(*)::int n from public.aa_consents')).rows[0].n, 2);
  for (const bad of [{ type: 'x' }, { method: 'fax' }, { version: '' }, { version: 'v'.repeat(21) }, { granted: 'yes' }, { code: 'P99' }]) {
    const r = await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P01', 'camera', true, bad)]]);
    assert.equal(r.ok, false, JSON.stringify(bad));
  }
});

test('events: stop needs condition_index 0-5, note needs text; resend is idempotent', async () => {
  const db = await ready();
  const eid = '55555555-5555-4555-8555-555555555551';
  const stop = { eid, type: 'stop', code: 'P01', condition_index: 2, text: '', at: iso(-1000) };
  assert.deepEqual(await rpc(db, ann, 'aa_events_upsert', [sid, [stop]]), { ok: true, n: 1 });
  assert.deepEqual(await rpc(db, ann, 'aa_events_upsert', [sid, [{ ...stop, text: '頭暈' }]]), { ok: true, n: 1 });
  assert.equal((await db.query('select count(*)::int n from public.aa_events')).rows[0].n, 1);
  assert.equal((await rpc(db, ann, 'aa_events_upsert', [sid, [{ ...stop, condition_index: 3 }]])).reason, 'invalid');
  const e2 = '55555555-5555-4555-8555-555555555552';
  for (const bad of [
    { ...stop, eid: e2, condition_index: 6 }, { ...stop, eid: e2, condition_index: null },
    { ...stop, eid: e2, type: 'note', condition_index: null, text: '' },
    { ...stop, eid: e2, type: 'note', condition_index: 1, text: 'x' },
    { ...stop, eid: e2, code: 'P55' }, { ...stop, eid: e2, text: 'x'.repeat(201) },
    { ...stop, eid: e2, type: 'other' },
  ]) {
    assert.equal((await rpc(db, ann, 'aa_events_upsert', [sid, [bad]])).reason, 'invalid', JSON.stringify(bad));
  }
  const note = { eid: e2, type: 'note', code: '', condition_index: null, text: '水不夠', at: iso(-500) };
  assert.deepEqual(await rpc(db, ann, 'aa_events_upsert', [sid, [note]]), { ok: true, n: 1 });
});

test('batch size: too many rows and oversized requests', async () => {
  const db = await ready();
  const many = Array.from({ length: 101 }, (_, i) => meas({ mid: `66666666-6666-4666-8666-${String(i).padStart(12, '0')}` }));
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, many])).reason, 'too_large');
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas({ note: 'x'.repeat(120_000) })]])).reason, 'too_large');
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, { not: 'an array' }])).reason, 'invalid');
  // 500 measurements per session.
  await db.query(
    `insert into public.aa_measurements (session_id, mid, code, item, human1, at)
     select $1, gen_random_uuid(), 'P01', 'chair30', 10, now() from generate_series(1, 499)`,
    [sid],
  );
  const r = await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas(), meas({ mid: mid2 })]]);
  assert.equal(r.accepted, 1);
  assert.equal(r.rejected[0].reason, 'too_large');
});

test('rate limit: a flood is refused and not audited', async () => {
  const db = await fresh();
  await activate(db, ann);
  let limited = 0;
  for (let i = 0; i < 40; i++) {
    const r = await rpc(db, ann, 'aa_session_list', [], { throttle: true });
    if (r.reason === 'rate_limited') limited++;
  }
  assert.ok(limited > 0);
  assert.equal((await db.query('select count(*)::int n from public.aa_audit where reason = \'rate_limited\'')).rows[0].n, 0);
});

test('close: 7 days of back-filling, then closed; delete still works', async () => {
  const db = await ready();
  assert.equal((await rpc(db, ann, 'aa_session_close', [sid, iso(-60_000)])).ok, true);
  const first = (await db.query('select closed_at from public.aa_sessions')).rows[0].closed_at;
  assert.equal((await rpc(db, ann, 'aa_session_close', [sid, iso()])).ok, true);
  assert.equal((await db.query('select closed_at from public.aa_sessions')).rows[0].closed_at.getTime(), first.getTime());
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas()]])).accepted, 1);
  await db.query("update public.aa_sessions set closed_server_at = now() - interval '8 days'");
  assert.deepEqual(await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas()]]), { ok: false, reason: 'closed' });
  assert.deepEqual(await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P05')]]), { ok: false, reason: 'closed' });
  assert.deepEqual(await rpc(db, ann, 'aa_session_close', [sid, iso()]), { ok: false, reason: 'closed' });
  assert.deepEqual(await rpc(db, ann, 'aa_session_delete', [sid]), { ok: true });
  assert.equal((await db.query('select count(*)::int n from public.aa_sessions')).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int n from public.aa_measurements')).rows[0].n, 0);
  assert.equal((await db.query('select count(*)::int n from public.aa_consent_history')).rows[0].n, 0);
  // The audit trail outlives the session.
  assert.ok((await db.query("select count(*)::int n from public.aa_audit where fn = 'aa_session_delete'")).rows[0].n === 1);
});

test('pull and list give the owner everything back, in the 08 field names', async () => {
  const db = await ready();
  await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas()]]);
  await rpc(db, ann, 'aa_events_upsert', [sid, [{ eid: '55555555-5555-4555-8555-555555555551', type: 'note', code: '', text: '備註', at: iso(-100) }]]);
  const p = await rpc(db, ann, 'aa_session_pull', [sid]);
  assert.equal(p.ok, true);
  assert.equal(p.session.id, sid);
  assert.equal(p.session.planned_count, 20);
  assert.equal(p.participants[0].code, 'P01');
  assert.equal(p.participants[0].group, 'A');
  assert.equal(p.consents[0].type, 'measure');
  assert.equal(p.measurements[0].mid, mid1);
  assert.equal(p.measurements[0].camera_valid, true);
  assert.equal('session_id' in p.measurements[0], false);
  assert.equal(p.events[0].type, 'note');
  const l = await rpc(db, ann, 'aa_session_list', [5]);
  assert.equal(l.sessions.length, 1);
  assert.deepEqual(l.sessions[0].counts, { participants: 1, consents: 1, measurements: 1, events: 1 });
});

test('erase: removes the person\'s data, blanks the health answers, blocks a later resend', async () => {
  const db = await ready();
  await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas()]]);
  await rpc(db, ann, 'aa_events_upsert', [sid, [{ eid: '55555555-5555-4555-8555-555555555551', type: 'stop', code: 'P01', condition_index: 1, text: '', at: iso(-100) }]]);
  assert.deepEqual(await rpc(db, ann, 'aa_participant_erase', [sid, 'P01']), { ok: true });
  for (const t of ['aa_measurements', 'aa_events', 'aa_consents', 'aa_consent_history']) {
    assert.equal((await db.query(`select count(*)::int n from public.${t}`)).rows[0].n, 0, t);
  }
  const row = (await db.query('select answers, reasons, erased_at from public.aa_participants')).rows[0];
  assert.equal(row.answers, null);
  assert.ok(row.erased_at);
  // The offline queue sends it all again: nothing comes back.
  assert.equal((await rpc(db, ann, 'aa_participants_upsert', [sid, [part('P01')]])).reason, 'invalid');
  assert.equal((await rpc(db, ann, 'aa_consents_upsert', [sid, [consent('P01')]])).reason, 'invalid');
  assert.equal((await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas()]])).rejected[0].reason, 'no_consent');
  assert.equal((await rpc(db, ann, 'aa_participant_erase', [sid, 'bad'])).reason, 'invalid');
});

test('the audit table records calls and failures but never the payload', async () => {
  const db = await ready();
  await rpc(db, ann, 'aa_measurements_upsert', [sid, [meas({ human1: 99 })]]);
  const rows = (await db.query('select fn, session_id, ok from public.aa_audit order by id')).rows;
  assert.ok(rows.length >= 4);
  assert.equal(rows.at(-1).fn, 'aa_measurements_upsert');
  assert.equal(rows.at(-1).session_id, sid);
  const cols = (await db.query("select column_name from information_schema.columns where table_name = 'aa_audit'")).rows.map((r) => r.column_name);
  assert.deepEqual(cols.sort(), ['at', 'fn', 'id', 'ok', 'reason', 'session_id', 'user_id']);
});
