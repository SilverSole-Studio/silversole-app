// supabase/tests/mp_rooms_test.mjs
//
// Runs the friends migrations plus supabase/migrations/*_mp_rooms.sql in PGlite
// on top of supabase_stubs.sql and plays the online-play RPCs the way an
// attacker would: calling the API directly, with the wrong person, the wrong
// turn, a skipped seq, a resent move, a stranger reading someone's room.
//
//   cd supabase/tests && npm install && npm run test:mp
//
// Every case runs inside `begin; ... rollback;` on one shared database, so the
// cases cannot leak into each other and nothing is kept. Time does not move
// inside a transaction (now() is fixed), so a case that needs "2 hours later"
// or "the last move was a second ago" rewrites the stored timestamps as the
// table owner instead. Concurrency (many calls at the same instant) needs a
// real multi-connection server: mp_concurrency_test.mjs.

import { test, before, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const here = dirname(fileURLToPath(import.meta.url));
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8');
const migrationsDir = join(here, '..', 'migrations');
const migrations = readdirSync(migrationsDir)
  .filter((f) => f.endsWith('.sql') && (f.includes('friends') || f.includes('mp_rooms')))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const A = uid(1); // host
const B = uid(2); // A's friend
const C = uid(3); // stranger
const D = uid(4); // A's friend who blocked A
const F = (n) => uid(10 + n); // F(1)..F(7): friends of B

let db;
let throttle = false;

before(async () => {
  db = new PGlite();
  await db.exec(stubs);
  await db.exec(migrations);
  const people = [A, B, C, D, ...[1, 2, 3, 4, 5, 6, 7].map(F)];
  for (const [i, u] of people.entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query(
      `insert into public.profiles (user_id, friend_code, nickname) values ($1, $2, $3)`,
      [u, String(40000000 + i), `玩家${i}`],
    );
  }
  const friend = (x, y) =>
    db.query(
      `insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')`,
      [x, y],
    );
  await friend(A, B);
  await friend(A, D);
  for (let n = 1; n <= 7; n++) await friend(B, F(n));
  await db.query('insert into public.blocks (blocker, blocked) values ($1, $2)', [D, A]);
});

beforeEach(async () => {
  throttle = false;
  await db.exec('begin');
});
afterEach(async () => {
  await db.exec('rollback');
  await db.exec('reset role');
});

/** Runs [sql] as [user] (role authenticated, RLS on). Refills the bucket first unless a test turned [throttle] on. */
async function as(user, sql, params = [], role = 'authenticated') {
  if (!throttle) await db.exec('update public.mp_limits set tokens = 30');
  await db.exec(`set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user ?? '']);
  // A refused statement (permission denied) aborts a transaction; a savepoint keeps the case going.
  await db.exec('savepoint as_user');
  try {
    return await db.query(sql, params);
  } catch (e) {
    await db.exec('rollback to savepoint as_user');
    throw e;
  } finally {
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', '', false)");
  }
}
const rpc = async (user, fn, ...args) => {
  const ph = args.map((_, i) => `$${i + 1}`).join(', ');
  return (await as(user, `select public.${fn}(${ph}) as r`, args)).rows[0].r;
};
const sql = async (q, params = []) => (await db.query(q, params)).rows;
const room = (id) => sql('select * from public.mp_rooms where id = $1', [id]).then((r) => r[0]);
/** The last move was "long ago": lets the next move through the 0.3 s per-room limit. */
const calm = (id) => sql("update public.mp_rooms set last_move_at = now() - interval '5 seconds' where id = $1", [id]);
const move = async (user, id, seq, m, ...rest) => {
  await calm(id);
  return rpc(user, 'mp_submit_move', id, seq, JSON.stringify(m), ...rest);
};

/** A and B in a playing room. */
async function playing(game = 'xiangqi') {
  const c = await rpc(A, 'mp_create_room', game);
  assert.equal(c.ok, true);
  const j = await rpc(B, 'mp_join_room', c.room.code, game);
  assert.equal(j.ok, true);
  return { id: c.room.id, code: c.room.code };
}

// ── 身分 ────────────────────────────────────────────────────────────────

test('signed out: every RPC says signed_out', async () => {
  for (const [fn, args] of [
    ['mp_create_room', ['xiangqi']],
    ['mp_join_room', ['123456', null]],
    ['mp_invite', [B, 'xiangqi']],
    ['mp_my_invites', [null]],
    ['mp_accept_invite', [uid(99)]],
    ['mp_leave', [uid(99), 'resign']],
  ]) {
    const r = await rpc(null, fn, ...args);
    assert.deepEqual(r, { ok: false, reason: 'signed_out' }, fn);
  }
  const m = await rpc(null, 'mp_submit_move', uid(99), 1, '{"a":1}');
  assert.equal(m.reason, 'signed_out');
});

test('anon cannot call the RPCs at all; nobody can call the internal helpers', async () => {
  await assert.rejects(as(null, "select public.mp_create_room('xiangqi')", [], 'anon'), /permission denied/);
  await assert.rejects(as(A, 'select public.mp_take($1, 1)', [A]), /permission denied/);
  await assert.rejects(as(A, "select public.mp_notify('room:x', 'move', '{}')"), /permission denied/);
  await assert.rejects(as(A, 'select public.mp_cleanup()'), /permission denied/);
});

// ── 開房與讀取 ──────────────────────────────────────────────────────────

test('create room: 6-digit code, waiting, I am side 0', async () => {
  const r = await rpc(A, 'mp_create_room', 'xiangqi');
  assert.equal(r.ok, true);
  assert.match(r.room.code, /^[1-9][0-9]{5}$/);
  assert.equal(r.room.status, 'waiting');
  assert.equal(r.room.side, 0);
  assert.equal(r.room.seq, 0);
  assert.equal(r.room.host, A);
});

test('bad game names are refused', async () => {
  for (const g of ['', 'Xiang qi', 'x'.repeat(33), "a'; drop table x; --", null]) {
    const r = await rpc(A, 'mp_create_room', g);
    assert.equal(r.ok, false);
    assert.ok(['bad_game', 'rate_limited'].includes(r.reason), String(g));
  }
});

test('non-members read nothing; the two players read the room', async () => {
  const { id } = await playing();
  assert.equal((await as(C, 'select * from public.mp_rooms')).rows.length, 0, 'stranger sees no room');
  assert.equal((await as(C, 'select * from public.mp_rooms where id = $1', [id])).rows.length, 0);
  assert.equal((await as(A, 'select * from public.mp_rooms where id = $1', [id])).rows.length, 1);
  assert.equal((await as(B, 'select * from public.mp_rooms where id = $1', [id])).rows.length, 1);
  assert.equal((await as(null, 'select * from public.mp_rooms', [], 'anon').catch(() => ({ rows: [] }))).rows.length, 0);
});

test('nobody writes mp_rooms directly, not even a player', async () => {
  const { id } = await playing();
  await assert.rejects(as(A, "update public.mp_rooms set winner = 0, status = 'done' where id = $1", [id]), /permission denied/);
  await assert.rejects(as(B, 'delete from public.mp_rooms where id = $1', [id]), /permission denied/);
  await assert.rejects(
    as(C, "insert into public.mp_rooms (game, host) values ('xiangqi', $1)", [C]),
    /permission denied/,
  );
  await assert.rejects(as(A, 'select * from public.mp_limits'), /permission denied/);
  await assert.rejects(as(A, 'select * from public.mp_declines'), /permission denied/);
});

// ── 房號加入 ────────────────────────────────────────────────────────────

test('join by code: guest sits, room is playing, host moves first', async () => {
  const c = await rpc(A, 'mp_create_room', 'xiangqi');
  const j = await rpc(B, 'mp_join_room', c.room.code, 'xiangqi');
  assert.equal(j.ok, true);
  assert.equal(j.room.status, 'playing');
  assert.equal(j.room.side, 1);
  assert.equal(j.room.turn, 0);
  // an answer got lost, the same guest asks again: same room, nothing changes
  const again = await rpc(B, 'mp_join_room', c.room.code, 'xiangqi');
  assert.equal(again.ok, true);
  assert.equal(again.room.id, c.room.id);
  // a third person finds the room full, and cannot tell it from a wrong code
  const third = await rpc(C, 'mp_join_room', c.room.code, 'xiangqi');
  assert.deepEqual(third, { ok: false, reason: 'bad_code' });
  assert.deepEqual(await rpc(C, 'mp_join_room', '999999', 'xiangqi'), { ok: false, reason: 'bad_code' });
  // host cannot join their own room; a wrong game is a plain bad code
  const own = await rpc(A, 'mp_create_room', 'xiangqi');
  assert.equal((await rpc(A, 'mp_join_room', own.room.code, 'xiangqi')).reason, 'own_room');
  assert.equal((await rpc(C, 'mp_join_room', own.room.code, 'pool')).reason, 'bad_code');
});

test('guessing codes: 5 misses lock the person out for 10 minutes, even for the right code', async () => {
  const c = await rpc(A, 'mp_create_room', 'xiangqi');
  for (let i = 0; i < 4; i++) {
    assert.equal((await rpc(C, 'mp_join_room', '100000', 'xiangqi')).reason, 'bad_code');
  }
  assert.equal((await rpc(C, 'mp_join_room', 'abc', 'xiangqi')).reason, 'bad_code', 'a malformed code counts too');
  const locked = await rpc(C, 'mp_join_room', c.room.code, 'xiangqi');
  assert.equal(locked.reason, 'locked');
  assert.ok(locked.until);
  // it is a record on the person: other people are not affected
  assert.equal((await rpc(B, 'mp_join_room', c.room.code, 'xiangqi')).ok, true);
  // ten minutes later the lock is over
  await sql("update public.mp_limits set join_locked_until = now() - interval '1 second' where user_id = $1", [C]);
  const c2 = await rpc(A, 'mp_create_room', 'xiangqi');
  assert.equal((await rpc(C, 'mp_join_room', c2.room.code, 'xiangqi')).ok, true);
});

test('a successful join, leaving rooms or making new ones does not wipe the guess counter', async () => {
  for (let i = 0; i < 4; i++) await rpc(C, 'mp_join_room', '100000', 'xiangqi');
  // C joins a real room (the "reset by succeeding" trick) ...
  const c = await rpc(A, 'mp_create_room', 'xiangqi');
  assert.equal((await rpc(C, 'mp_join_room', c.room.code, 'xiangqi')).ok, true);
  // ... leaves it, makes and cancels rooms of their own ...
  await rpc(C, 'mp_leave', c.room.id, 'resign');
  const mine = await rpc(C, 'mp_create_room', 'xiangqi');
  await rpc(C, 'mp_leave', mine.room.id, 'resign');
  assert.equal((await sql('select join_fails from public.mp_limits where user_id = $1', [C]))[0].join_fails, 4);
  // ... and the next miss still locks them
  await rpc(C, 'mp_join_room', '100000', 'xiangqi');
  assert.equal((await rpc(C, 'mp_join_room', '100000', 'xiangqi')).reason, 'locked');
  // The counter is only forgotten by time: 10 quiet minutes
  await sql("update public.mp_limits set join_locked_until = null, join_fail_since = now() - interval '11 minutes' where user_id = $1", [C]);
  await rpc(C, 'mp_join_room', '100000', 'xiangqi');
  assert.equal((await sql('select join_fails from public.mp_limits where user_id = $1', [C]))[0].join_fails, 1);
});

// ── 走一步 ──────────────────────────────────────────────────────────────

test('moves: only a player, only on their turn, seq must follow on', async () => {
  const { id } = await playing();
  const m1 = { f: 'h2', t: 'e2' };
  // a stranger, and the guest out of turn
  assert.equal((await move(C, id, 1, m1)).reason, 'not_found');
  assert.equal((await move(B, id, 1, m1)).reason, 'not_your_turn');
  // a skipped seq
  assert.equal((await move(A, id, 2, m1)).reason, 'seq_mismatch');
  assert.equal((await move(A, id, 0, m1)).reason, 'bad_move');
  assert.equal((await room(id)).seq, 0, 'nothing was stored by the refused ones');
  // the real move
  assert.deepEqual(await move(A, id, 1, m1), { ok: true, seq: 1 });
  let r = await room(id);
  assert.equal(r.seq, 1);
  assert.equal(r.turn, 1);
  assert.deepEqual(r.moves, [{ by: 0, m: m1 }]);
  // now it is B's turn, A is out of turn
  assert.equal((await move(A, id, 2, { f: 'x' })).reason, 'not_your_turn');
  const m2 = { f: 'h7', t: 'e7' };
  assert.deepEqual(await move(B, id, 2, m2), { ok: true, seq: 2 });
  r = await room(id);
  assert.deepEqual(r.moves.map((x) => x.by), [0, 1]);
  assert.equal(r.turn, 0);
});

test('resending the same move changes nothing; a different move for a taken seq is refused', async () => {
  const { id } = await playing();
  const m1 = { f: 'h2', t: 'e2' };
  assert.equal((await move(A, id, 1, m1)).ok, true);
  const dup = await move(A, id, 1, m1);
  assert.deepEqual(dup, { ok: true, seq: 1, dup: true });
  assert.equal((await room(id)).moves.length, 1, 'not stored twice');
  assert.equal((await move(A, id, 1, { f: 'a0', t: 'a1' })).reason, 'seq_mismatch', 'other move, same seq');
  // the other side cannot use the resend path to "confirm" my move as theirs
  assert.equal((await move(B, id, 1, m1)).reason, 'seq_mismatch');
  assert.equal((await room(id)).moves.length, 1);
  // a resend of an old move after the game moved on is still just a resend
  assert.equal((await move(B, id, 2, { f: 'h7', t: 'e7' })).ok, true);
  assert.equal((await move(A, id, 1, m1)).dup, true);
});

test('move size, shape and speed limits', async () => {
  const { id } = await playing();
  assert.equal((await move(A, id, 1, { pad: 'x'.repeat(300) })).reason, 'move_too_big');
  assert.equal((await rpc(A, 'mp_submit_move', id, 1, 'null')).reason, 'bad_move');
  assert.equal((await rpc(A, 'mp_submit_move', id, 1, '{"a":1}', 5)).reason, 'bad_move', 'next must be 0 or 1');
  assert.equal((await rpc(A, 'mp_submit_move', id, 1, '{"a":1}', null, 'lose')).reason, 'bad_move');
  assert.equal((await room(id)).seq, 0);
  // two accepted moves in the same instant: the second is too fast
  assert.equal((await move(A, id, 1, { a: 1 })).ok, true);
  const fast = await rpc(B, 'mp_submit_move', id, 2, '{"a":2}');
  assert.equal(fast.reason, 'too_fast');
  assert.equal((await room(id)).seq, 1);
  // plain strings and numbers are fine moves
  assert.equal((await move(B, id, 2, 'e7')).ok, true);
  assert.equal((await move(A, id, 3, 42)).ok, true);
});

test('a room holds at most 1000 moves', async () => {
  const { id } = await playing();
  await sql("update public.mp_rooms set seq = 1000, turn = 0 where id = $1", [id]);
  assert.equal((await move(A, id, 1001, { a: 1 })).reason, 'too_long');
});

test('p_next lets a game give the turn to the same side again; p_end finishes the room', async () => {
  const { id } = await playing('pool');
  assert.equal((await move(A, id, 1, { shot: 1 }, 0)).ok, true);
  assert.equal((await room(id)).turn, 0, 'host keeps the turn');
  assert.equal((await move(A, id, 2, { shot: 2 })).ok, true);
  assert.equal((await room(id)).turn, 1);
  // the guest wins with this move
  const end = await move(B, id, 3, { shot: 'last' }, null, 'win');
  assert.deepEqual(end, { ok: true, seq: 3 });
  const r = await room(id);
  assert.equal(r.status, 'done');
  assert.equal(r.winner, 1);
  assert.equal(r.end_reason, 'finish');
  // no more moves, but resending the final move still answers "yes, already taken"
  assert.equal((await move(A, id, 4, { a: 1 })).reason, 'not_playing');
  assert.equal((await move(B, id, 3, { shot: 'last' }, null, 'win')).dup, true);
});

test('a draw finishes with no winner', async () => {
  const { id } = await playing();
  assert.equal((await move(A, id, 1, { a: 1 }, null, 'draw')).ok, true);
  const r = await room(id);
  assert.equal(r.status, 'done');
  assert.equal(r.winner, null);
});

test('a room silent for 2 hours is void; a stale waiting room cannot be joined', async () => {
  const { id } = await playing();
  await sql("update public.mp_rooms set updated_at = now() - interval '3 hours' where id = $1", [id]);
  const r = await move(A, id, 1, { a: 1 });
  assert.equal(r.reason, 'expired');
  assert.deepEqual([(await room(id)).status, (await room(id)).end_reason], ['abandoned', 'expired']);

  const w = await rpc(A, 'mp_create_room', 'xiangqi');
  await sql("update public.mp_rooms set updated_at = now() - interval '3 hours' where id = $1", [w.room.id]);
  assert.equal((await rpc(B, 'mp_join_room', w.room.code, 'xiangqi')).reason, 'bad_code');
  assert.equal((await room(w.room.id)).status, 'abandoned');
  // the code is free again
  const again = await rpc(A, 'mp_create_room', 'xiangqi');
  assert.equal(again.ok, true);
});

// ── 認輸與離開 ──────────────────────────────────────────────────────────

test('leave: resigning a playing room loses it; leaving twice is harmless', async () => {
  const { id } = await playing();
  assert.equal((await rpc(C, 'mp_leave', id, 'resign')).reason, 'not_found');
  const l = await rpc(B, 'mp_leave', id, 'resign');
  assert.equal(l.ok, true);
  assert.equal(l.room.status, 'done');
  assert.equal(l.room.winner, 0, 'the one who stayed wins');
  assert.equal((await room(id)).end_reason, 'resign');
  const again = await rpc(B, 'mp_leave', id, 'resign');
  assert.equal(again.ok, true);
  assert.equal((await room(id)).winner, 0, 'not flipped by a second call');
  // and the other cannot "un-resign" by resigning too
  await rpc(A, 'mp_leave', id, 'resign');
  assert.equal((await room(id)).winner, 0);
});

test('abort: only when it is their turn and they have been silent for a minute', async () => {
  const { id } = await playing();
  // it is A's turn: A cannot abort (that is just stalling the guest), B must wait a minute
  assert.equal((await rpc(A, 'mp_leave', id, 'abort')).reason, 'too_early');
  assert.equal((await rpc(B, 'mp_leave', id, 'abort')).reason, 'too_early');
  await sql("update public.mp_rooms set updated_at = now() - interval '61 seconds' where id = $1", [id]);
  assert.equal((await rpc(A, 'mp_leave', id, 'abort')).reason, 'too_early', 'A is the one on turn');
  const ok = await rpc(B, 'mp_leave', id, 'abort');
  assert.equal(ok.ok, true);
  const r = await room(id);
  assert.deepEqual([r.status, r.end_reason, r.winner], ['abandoned', 'opponent_gone', null]);
});

test('host cancels a waiting room', async () => {
  const c = await rpc(A, 'mp_create_room', 'xiangqi');
  assert.equal((await rpc(B, 'mp_leave', c.room.id, 'resign')).reason, 'not_found');
  assert.equal((await rpc(A, 'mp_leave', c.room.id, 'resign')).ok, true);
  assert.equal((await room(c.room.id)).status, 'abandoned');
  assert.equal((await rpc(B, 'mp_join_room', c.room.code, 'xiangqi')).reason, 'bad_code', 'cancelled code is dead');
});

// ── 邀請好友 ────────────────────────────────────────────────────────────

test('invite: friends only; strangers, yourself, and a friend who blocked you all get the same answer', async () => {
  assert.equal((await rpc(A, 'mp_invite', C, 'xiangqi')).reason, 'not_friends');
  assert.equal((await rpc(A, 'mp_invite', A, 'xiangqi')).reason, 'not_friends');
  assert.equal((await rpc(A, 'mp_invite', D, 'xiangqi')).reason, 'not_friends', 'D blocked A');
  assert.equal((await rpc(A, 'mp_invite', uid(77), 'xiangqi')).reason, 'not_friends');
  assert.equal((await rpc(A, 'mp_invite', B, 'Bad Game')).reason, 'bad_game');
  assert.equal((await sql('select count(*)::int as n from public.mp_rooms'))[0].n, 0, 'no room was made');
});

test('invite: the friend sees it, others cannot take the seat, the friend accepts', async () => {
  const inv = await rpc(A, 'mp_invite', B, 'xiangqi');
  assert.equal(inv.ok, true);
  const id = inv.room.id;
  // the friend's own channel was pinged
  const ping = await sql("select * from realtime.messages where topic = $1 and event = 'invite'", ['user:' + B]);
  assert.equal(ping.length, 1);
  assert.equal(ping[0].payload.room, id);
  assert.equal(ping[0].private, true);
  // asking again is the same room
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).room.id, id);
  assert.equal((await sql('select count(*)::int as n from public.mp_rooms'))[0].n, 1);
  // list: B sees it, C sees nothing, a filter for another game hides it
  const list = await rpc(B, 'mp_my_invites', null);
  assert.deepEqual(list.invites.map((x) => [x.room, x.game, x.from]), [[id, 'xiangqi', A]]);
  assert.deepEqual((await rpc(C, 'mp_my_invites', null)).invites, []);
  assert.deepEqual((await rpc(B, 'mp_my_invites', 'pool')).invites, []);
  // the code of an invite room does not let a stranger in, and C cannot accept it
  assert.equal((await rpc(C, 'mp_join_room', inv.room.code, 'xiangqi')).reason, 'bad_code');
  assert.equal((await rpc(C, 'mp_accept_invite', id)).reason, 'not_found');
  // B accepts (twice is fine)
  const acc = await rpc(B, 'mp_accept_invite', id);
  assert.equal(acc.ok, true);
  assert.equal(acc.room.status, 'playing');
  assert.equal(acc.room.side, 1);
  assert.equal((await rpc(B, 'mp_accept_invite', id)).ok, true);
  assert.deepEqual((await rpc(B, 'mp_my_invites', null)).invites, [], 'no longer pending');
  assert.equal((await move(A, id, 1, { a: 1 })).ok, true);
});

test('invite: the friend can also come in by the code; if you unfriend/block first the invite dies', async () => {
  const inv = await rpc(A, 'mp_invite', B, 'xiangqi');
  assert.equal((await rpc(B, 'mp_join_room', inv.room.code, 'xiangqi')).ok, true);

  const inv2 = await rpc(A, 'mp_invite', B, 'pool');
  await sql('insert into public.blocks (blocker, blocked) values ($1, $2)', [B, A]);
  assert.deepEqual((await rpc(B, 'mp_my_invites', null)).invites, [], 'hidden once B blocked A');
  assert.equal((await rpc(B, 'mp_accept_invite', inv2.room.id)).reason, 'not_found');
  assert.equal((await rpc(A, 'mp_invite', B, 'pool')).reason, 'not_friends');
});

test('invite: a friend has at most 5 pending invites, counted over everyone who invites them', async () => {
  for (let n = 1; n <= 5; n++) assert.equal((await rpc(F(n), 'mp_invite', B, 'xiangqi')).ok, true, 'inviter ' + n);
  assert.equal((await rpc(F(6), 'mp_invite', B, 'xiangqi')).reason, 'invitee_busy');
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).reason, 'invitee_busy');
  // B declines one -> there is room for one more
  const first = (await rpc(B, 'mp_my_invites', null)).invites[0];
  assert.equal((await rpc(B, 'mp_leave', first.room, 'resign')).ok, true);
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).ok, true);
});

test('invite: a decline starts a cool-down that cancelling, leaving and cleaning cannot wipe', async () => {
  const inv = await rpc(A, 'mp_invite', B, 'xiangqi');
  assert.equal((await rpc(B, 'mp_leave', inv.room.id, 'resign')).ok, true, 'B declines');
  assert.equal((await room(inv.room.id)).status, 'abandoned');
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).reason, 'invitee_busy');
  // A makes and cancels rooms of their own: the record stays
  for (let i = 0; i < 2; i++) {
    const r = await rpc(A, 'mp_create_room', 'xiangqi');
    await rpc(A, 'mp_leave', r.room.id, 'resign');
  }
  assert.equal((await sql('select count(*)::int as n from public.mp_declines'))[0].n, 1);
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).reason, 'invitee_busy');
  // 5 minutes later it is allowed again
  await sql("update public.mp_declines set until_at = now() - interval '1 second'");
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).ok, true);
});

test('the host cancelling their own invite is not a decline', async () => {
  const inv = await rpc(A, 'mp_invite', B, 'xiangqi');
  await rpc(A, 'mp_leave', inv.room.id, 'resign');
  assert.equal((await sql('select count(*)::int as n from public.mp_declines'))[0].n, 0);
});

// ── 額度與上限 ──────────────────────────────────────────────────────────

test('at most 3 live rooms per person', async () => {
  for (let i = 0; i < 3; i++) assert.equal((await rpc(A, 'mp_create_room', 'xiangqi')).ok, true);
  assert.equal((await rpc(A, 'mp_create_room', 'xiangqi')).reason, 'too_many_rooms');
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).reason, 'too_many_rooms');
  // as a guest too: B can sit in 3 rooms, not 4
  const codes = (await sql('select code from public.mp_rooms where host = $1', [A])).map((r) => r.code);
  for (const code of codes) assert.equal((await rpc(B, 'mp_join_room', code, 'xiangqi')).ok, true);
  const c = await rpc(F(1), 'mp_create_room', 'xiangqi');
  assert.equal((await rpc(B, 'mp_join_room', c.room.code, 'xiangqi')).reason, 'too_many_rooms');
});

test('opening rooms is rationed: cancelling one does not give the cost back', async () => {
  throttle = true;
  await sql('delete from public.mp_limits');
  for (let i = 0; i < 2; i++) {
    const r = await rpc(A, 'mp_create_room', 'xiangqi');
    assert.equal(r.ok, true, 'room ' + i);
    assert.equal((await rpc(A, 'mp_leave', r.room.id, 'resign')).ok, true, 'cancel ' + i);
  }
  // bucket 30: 2 x (10 + 1) used, 8 left: no third room
  assert.equal((await rpc(A, 'mp_create_room', 'xiangqi')).reason, 'rate_limited');
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).reason, 'rate_limited');
  // it fills up again with time (a minute later)
  await sql("update public.mp_limits set updated_at = now() - interval '60 seconds' where user_id = $1", [A]);
  assert.equal((await rpc(A, 'mp_create_room', 'xiangqi')).ok, true);
  // someone else is not slowed by A
  assert.equal((await rpc(B, 'mp_create_room', 'xiangqi')).ok, true);
});

test('hammering moves runs the person dry', async () => {
  const { id } = await playing();
  throttle = true;
  await sql('update public.mp_limits set tokens = 3 where user_id = $1', [A]);
  const seen = [];
  for (let i = 0; i < 5; i++) seen.push((await rpc(A, 'mp_submit_move', id, 9, '{"a":1}')).reason);
  assert.ok(seen.includes('rate_limited'), seen.join(','));
});

test('a host keeps at most 20 finished rooms; never-played rooms are removed', async () => {
  for (let i = 0; i < 25; i++) {
    await sql(
      `insert into public.mp_rooms (game, host, guest, status, seq, updated_at)
       values ('xiangqi', $1, $2, 'done', 3, now() - ($3 || ' minutes')::interval)`,
      [A, B, String(20 + i)],
    );
  }
  await sql(
    `insert into public.mp_rooms (game, host, status, updated_at) values ('xiangqi', $1, 'abandoned', now())`,
    [A],
  );
  assert.equal((await rpc(A, 'mp_create_room', 'xiangqi')).ok, true);
  const rows = await sql(`select status, count(*)::int as n from public.mp_rooms where host = $1 group by status`, [A]);
  const n = Object.fromEntries(rows.map((r) => [r.status, r.n]));
  assert.equal(n.done, 20);
  assert.equal(n.abandoned ?? 0, 0);
  assert.equal(n.waiting, 1);
});

test('mp_cleanup (service role): ends stale live rooms, deletes old finished ones', async () => {
  const { id } = await playing();
  await sql("update public.mp_rooms set updated_at = now() - interval '3 hours' where id = $1", [id]);
  await sql(
    `insert into public.mp_rooms (game, host, guest, status, updated_at)
     values ('xiangqi', $1, $2, 'done', now() - interval '20 days')`,
    [A, B],
  );
  const r = (await as(null, 'select public.mp_cleanup() as r', [], 'service_role')).rows[0].r;
  assert.deepEqual(r, { expired: 1, deleted: 1 });
  assert.equal((await room(id)).status, 'abandoned');
});

// ── Realtime ────────────────────────────────────────────────────────────

test('every change pings the room channel; the ping is only a hint (no move inside)', async () => {
  const c = await rpc(A, 'mp_create_room', 'xiangqi');
  await rpc(B, 'mp_join_room', c.room.code, 'xiangqi');
  await move(A, c.room.id, 1, { secret: 'hello' });
  await rpc(B, 'mp_leave', c.room.id, 'resign');
  const msgs = await sql("select event, payload from realtime.messages where topic = $1 order by inserted_at, event", [
    'room:' + c.room.id,
  ]);
  assert.deepEqual(msgs.map((m) => m.event).sort(), ['joined', 'left', 'move']);
  for (const m of msgs) assert.equal(JSON.stringify(m.payload).includes('hello'), false);
});

test('a failing Realtime never undoes the move', async () => {
  const { id } = await playing();
  // Realtime is down: send() blows up. (The case runs in a transaction, so this is rolled back.)
  await db.exec(`create or replace function realtime.send(payload jsonb, event text, topic text, private boolean default true)
    returns void language plpgsql as $$ begin raise exception 'realtime is down'; end $$`);
  assert.equal((await move(A, id, 1, { a: 1 })).ok, true);
  assert.equal((await room(id)).seq, 1);
  assert.equal((await rpc(B, 'mp_leave', id, 'resign')).ok, true, 'leaving still works too');
});

/** What [user] can read from realtime.messages when subscribed to [topic]. */
async function channel(user, topic) {
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
  await db.query("select set_config('realtime.topic', $1, false)", [topic]);
  try {
    return (await db.query('select * from realtime.messages')).rows;
  } finally {
    await db.exec('reset role');
    await db.query("select set_config('realtime.topic', '', false)");
  }
}
async function canSend(user, topic, ext = 'broadcast') {
  await db.exec('set role authenticated');
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
  await db.query("select set_config('realtime.topic', $1, false)", [topic]);
  await db.exec('savepoint can_send');
  try {
    await db.query("insert into realtime.messages (topic, extension, event, payload) values ($1, $2, 'pos', '{}')", [topic, ext]);
    return true;
  } catch {
    await db.exec('rollback to savepoint can_send');
    return false;
  } finally {
    await db.exec('reset role');
    await db.query("select set_config('realtime.topic', '', false)");
  }
}

test('Realtime RLS: only the two players are let into room:<id>, only you into user:<you>', async () => {
  const { id } = await playing();
  const topic = 'room:' + id;
  assert.ok((await channel(A, topic)).some((m) => m.topic === topic), 'host hears the room');
  assert.ok((await channel(B, topic)).some((m) => m.topic === topic), 'guest hears the room');
  assert.equal((await channel(C, topic)).length, 0, 'a stranger hears nothing');
  assert.equal((await channel(D, topic)).length, 0);
  // a made-up topic and a pattern trick
  assert.equal((await channel(C, 'room:%')).length, 0);
  assert.equal((await channel(C, 'room:' + uid(99))).length, 0);
  // own user channel only
  await sql("select realtime.send('{}'::jsonb, 'invite', $1, true)", ['user:' + B]);
  assert.equal((await channel(B, 'user:' + B)).filter((m) => m.topic === 'user:' + B).length, 1);
  assert.equal((await channel(C, 'user:' + B)).length, 0, "C cannot listen on B's channel");
  assert.equal((await channel(B, 'user:' + C)).length, 0);
  // sending: players may on their room, nobody on a user channel, strangers not at all, only broadcast/presence
  assert.equal(await canSend(A, topic), true);
  assert.equal(await canSend(B, topic, 'presence'), true);
  assert.equal(await canSend(C, topic), false);
  assert.equal(await canSend(B, 'user:' + B), false);
  assert.equal(await canSend(A, topic, 'postgres_changes'), false);
});
