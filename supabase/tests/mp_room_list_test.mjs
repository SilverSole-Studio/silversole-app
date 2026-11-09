// supabase/tests/mp_room_list_test.mjs
//
// 交誼廳的房間列表（mp_rooms.visibility、mp_create_room 的 p_visibility、mp_list_rooms、
// mp_join_listed，以及 mp_join_room 補上的 friends／封鎖限制）。
// 在 PGlite 裡跑：friends、mp_rooms、mp_seats、mp_presence、mp_quick_match、mp_room_list
// 幾支 migration 套在 supabase_stubs.sql 上，用攻擊者的角度直接打 RPC。
// 同一瞬間搶最後一個位子（要真的多連線）在 mp_room_list_concurrency_test.mjs。
//
//   cd supabase/tests && npm install && npm run test:mp-list

import { test, before, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join as pjoin } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const here = dirname(fileURLToPath(import.meta.url));
const stubs = readFileSync(pjoin(here, 'supabase_stubs.sql'), 'utf8');
const migrationsDir = pjoin(here, '..', 'migrations');
const migrations = readdirSync(migrationsDir)
  .filter(
    (f) =>
      f.endsWith('.sql') &&
      (f.includes('friends') ||
        f.includes('mp_rooms') ||
        f.includes('mp_seats') ||
        f.includes('mp_presence') ||
        f.includes('mp_quick_match') ||
        f.includes('mp_room_list')),
  )
  .sort()
  .map((f) => readFileSync(pjoin(migrationsDir, f), 'utf8'))
  .join('\n');

const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const A = uid(1); // 房主
const B = uid(2); // A 的好友
const C = uid(3); // 陌生人
const D = uid(4); // 陌生人
const E = uid(5); // 陌生人
const G = uid(6); // 陌生人
const ALL = [A, B, C, D, E, G];

let db;

before(async () => {
  db = new PGlite();
  await db.exec(stubs);
  await db.exec(migrations);
  for (const [i, u] of ALL.entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query(
      `insert into public.profiles (user_id, friend_code, nickname, avatar_preset) values ($1, $2, $3, $4)`,
      [u, String(60000000 + i), `玩家${i}`, (i % 12) + 1],
    );
  }
});

beforeEach(async () => {
  await db.exec('begin');
  // A 和 B 是好友
  await db.query(
    "insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')",
    [A, B],
  );
});
afterEach(async () => {
  await db.exec('rollback');
  await db.exec('reset role');
});

let throttle = false;
async function as(user, q, params = [], role = 'authenticated') {
  if (!throttle) await db.exec('update public.mp_limits set tokens = 30');
  await db.exec(`set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [user ?? '']);
  await db.exec('savepoint as_user');
  try {
    return await db.query(q, params);
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
const block = (x, y) => sql('insert into public.blocks (blocker, blocked) values ($1, $2)', [x, y]);
const make = (u, game = 'xiangqi', seats = 2, vis = 'public') => rpc(u, 'mp_create_room', game, seats, vis);
const list = (u, game = null) => rpc(u, 'mp_list_rooms', game);
const joinListed = (u, room) => rpc(u, 'mp_join_listed', room);
const ids = (res) => res.rooms.map((r) => r.id);
const events = (topic, ev) =>
  sql('select payload from realtime.messages where topic = $1 and event = $2 order by inserted_at, id', [topic, ev]);

// ── 基本 ────────────────────────────────────────────────────────────────

test('list: signed out answers signed_out; anon cannot call; helper is closed', async () => {
  assert.equal((await rpc(null, 'mp_list_rooms', null)).reason, 'signed_out');
  assert.equal((await rpc(null, 'mp_join_listed', uid(99))).reason, 'signed_out');
  assert.equal((await rpc(null, 'mp_create_room', 'xiangqi', 2, 'public')).reason, 'signed_out');
  await assert.rejects(as(null, 'select public.mp_list_rooms()', [], 'anon'), /permission denied/);
  await assert.rejects(as(null, 'select public.mp_join_listed($1)', [uid(99)], 'anon'), /permission denied/);
  await assert.rejects(as(A, 'select public.mp_room_blocked(r, $1) from public.mp_rooms r', [A]), /permission denied/);
});

test('create: visibility defaults to public; old two-argument calls still work; bad value refused', async () => {
  const old = await rpc(A, 'mp_create_room', 'xiangqi', 2);
  assert.equal(old.ok, true);
  assert.equal((await sql('select visibility from public.mp_rooms where id = $1', [old.room.id]))[0].visibility, 'public');
  const one = await rpc(A, 'mp_create_room', 'chess');
  assert.equal(one.ok, true);
  const fr = await make(A, 'mahjong', 4, 'friends');
  assert.equal(fr.ok, true);
  assert.equal((await sql('select visibility from public.mp_rooms where id = $1', [fr.room.id]))[0].visibility, 'friends');
});

test('create: null visibility counts as public', async () => {
  const nul = await rpc(A, 'mp_create_room', 'holdem', 4, null);
  assert.equal(nul.ok, true);
  assert.equal((await sql('select visibility from public.mp_rooms where id = $1', [nul.room.id]))[0].visibility, 'public');
});

test('create: a bad visibility is refused before anything is written', async () => {
  assert.equal((await make(A, 'xiangqi', 2, 'secret')).reason, 'bad_visibility');
  assert.equal((await make(A, 'xiangqi', 2, 'PUBLIC')).reason, 'bad_visibility');
  assert.equal((await make(A, 'xiangqi', 2, '')).reason, 'bad_visibility');
  assert.equal((await make(A, 'Bad Game!', 2, 'public')).reason, 'bad_game');
  assert.equal((await make(A, 'xiangqi', 9, 'public')).reason, 'bad_seats');
  assert.equal((await sql('select count(*)::int as n from public.mp_rooms'))[0].n, 0);
});

// ── 列表 ────────────────────────────────────────────────────────────────

test('list: a public room shows to a stranger with host nickname, avatar, seats and seated; no ids or code', async () => {
  const r = await make(A, 'xiangqi', 2, 'public');
  const l = await list(C);
  assert.equal(l.ok, true);
  assert.equal(l.rooms.length, 1);
  const x = l.rooms[0];
  assert.equal(x.id, r.room.id);
  assert.equal(x.game, 'xiangqi');
  assert.equal(x.seats, 2);
  assert.equal(x.seated, 1);
  assert.equal(x.hostName, '玩家0');
  assert.equal(x.hostAvatar, 1);
  assert.equal(x.friend, false);
  assert.equal(x.visibility, 'public');
  assert.deepEqual(Object.keys(x).sort(), ['createdAt', 'friend', 'game', 'hostAvatar', 'hostName', 'id', 'seated', 'seats', 'visibility']);
  const text = JSON.stringify(l);
  assert.ok(!text.includes(A), 'no host user id');
  assert.ok(!text.includes(r.room.code), 'no room code');
});

test('list: a friend sees the room marked friend, and friends-only rooms too; a stranger does not see friends-only', async () => {
  const pub = await make(A, 'xiangqi', 2, 'public');
  const fr = await make(A, 'chess', 2, 'friends');
  await sql("update public.mp_rooms set created_at = now() - interval '1 minute' where id = $1", [pub.room.id]);
  // one room per host: B sees the newest of the two (the friends-only one)
  const lb = await list(B);
  assert.deepEqual(ids(lb), [fr.room.id]);
  assert.equal(lb.rooms[0].friend, true);
  assert.equal(lb.rooms[0].visibility, 'friends');
  // the stranger only sees the public one (the host's newest *visible* room)
  const lc = await list(C);
  assert.deepEqual(ids(lc), [pub.room.id]);
});

test('list: one room per host (the newest that matches); the game filter picks among them', async () => {
  const x = await make(A, 'xiangqi', 2, 'public');
  const c = await make(A, 'chess', 2, 'public');
  await sql("update public.mp_rooms set created_at = now() - interval '1 minute' where id = $1", [x.room.id]);
  assert.deepEqual(ids(await list(C)), [c.room.id]);
  assert.deepEqual(ids(await list(C, 'xiangqi')), [x.room.id]);
  assert.deepEqual(ids(await list(C, 'chess')), [c.room.id]);
  assert.deepEqual(ids(await list(C, 'mahjong')), []);
  assert.equal((await list(C, 'Bad Game!')).reason, 'bad_game');
});

test('list: my own rooms and rooms I already sit in are not shown', async () => {
  const mine = await make(C, 'xiangqi', 2, 'public');
  const other = await make(A, 'chess', 4, 'public');
  assert.deepEqual(ids(await list(C)), [other.room.id]);
  await joinListed(C, other.room.id);
  assert.deepEqual(ids(await list(C)), [], 'C sits in A\'s room now; their own is invisible to themselves');
  // D sees both hosts' rooms (A's has a seat free: 4 seats, only C sits)
  assert.deepEqual(new Set(ids(await list(D))), new Set([other.room.id, mine.room.id]));
});

test('list: full rooms, started rooms, personal invites and quick-match rooms are not shown', async () => {
  const two = await make(A, 'xiangqi', 2, 'public');
  const four = await make(B, 'mahjong', 4, 'public');
  assert.equal(new Set(ids(await list(C))).size, 2);
  // 2-seat room fills
  assert.equal((await joinListed(D, two.room.id)).ok, true);
  assert.deepEqual(ids(await list(C)), [four.room.id]);
  // 4-seat room: seated count goes up, disappears when full
  await joinListed(C, four.room.id);
  const l = await list(E);
  assert.equal(l.rooms[0].seated, 2);
  await joinListed(E, four.room.id);
  await joinListed(G, four.room.id);
  assert.deepEqual(ids(await list(uid(1))), [], 'nothing left');
  // personal invite (invited is set) never lists
  const inv = await rpc(A, 'mp_invite', B, 'chess');
  assert.equal(inv.ok, true);
  assert.deepEqual(ids(await list(C)), []);
  // quick match room (playing, no code)
  await rpc(C, 'mp_queue_join', 'holdem', 2);
  await rpc(D, 'mp_queue_join', 'holdem', 2);
  assert.deepEqual(ids(await list(E)), []);
});

test('list: rooms quiet for 10 minutes are not shown (but still joinable by code)', async () => {
  const r = await make(A, 'xiangqi', 2, 'public');
  await sql("update public.mp_rooms set updated_at = now() - interval '11 minutes' where id = $1", [r.room.id]);
  assert.deepEqual(ids(await list(C)), []);
  assert.equal((await joinListed(C, r.room.id)).reason, 'gone');
  const byCode = await rpc(C, 'mp_join_room', r.room.code, 'xiangqi');
  assert.equal(byCode.ok, true, 'the code still works');
  const r2 = await make(A, 'chess', 2, 'public');
  await sql("update public.mp_rooms set updated_at = now() - interval '9 minutes' where id = $1", [r2.room.id]);
  assert.deepEqual(ids(await list(D)), [r2.room.id]);
});

test('list: blocks hide the room in both directions, also for a seated guest', async () => {
  const r = await make(A, 'mahjong', 4, 'public');
  await block(C, A); // C blocked the host
  assert.deepEqual(ids(await list(C)), []);
  await sql('delete from public.blocks');
  await block(A, D); // the host blocked D
  assert.deepEqual(ids(await list(D)), []);
  assert.equal((await joinListed(D, r.room.id)).reason, 'gone');
  assert.deepEqual(ids(await list(E)), [r.room.id]);
  await joinListed(E, r.room.id);
  await block(G, E); // G blocked someone who already sits there
  assert.deepEqual(ids(await list(G)), []);
  assert.equal((await joinListed(G, r.room.id)).reason, 'gone');
  assert.deepEqual(ids(await list(C)), [r.room.id], 'C was unblocked above (delete from blocks)');
});

test('list: a friend who blocked the host cannot see the friends-only room; unfriended people cannot either', async () => {
  const r = await make(A, 'chess', 2, 'friends');
  assert.deepEqual(ids(await list(B)), [r.room.id]);
  await block(B, A);
  assert.deepEqual(ids(await list(B)), []);
  assert.equal((await joinListed(B, r.room.id)).reason, 'gone');
  await sql('delete from public.blocks');
  await sql('delete from public.friendships');
  assert.deepEqual(ids(await list(B)), []);
  assert.equal((await joinListed(B, r.room.id)).reason, 'gone');
});

test('list: friends first, then newest; at most 50 rooms; a flood of strangers does not push a friend out', async () => {
  // 55 strangers each with one public room
  for (let i = 0; i < 55; i++) {
    const u = uid(200 + i);
    await sql('insert into auth.users (id) values ($1)', [u]);
    await sql('insert into public.profiles (user_id, friend_code, nickname) values ($1, $2, $3)', [u, String(70000000 + i), `陌${i}`]);
    await sql(
      "insert into public.mp_rooms (game, code, host, created_at, updated_at) values ('xiangqi', $1, $2, now() - ($3 || ' seconds')::interval, now())",
      [String(1000 + i), u, String(100 - i)],
    );
  }
  const fr = await make(A, 'chess', 2, 'friends'); // newest? created now, but friend → first anyway
  await sql("update public.mp_rooms set created_at = now() - interval '9 minutes' where id = $1", [fr.room.id]);
  const l = await list(B);
  assert.equal(l.rooms.length, 50);
  assert.equal(l.rooms[0].id, fr.room.id, 'the friend\'s room is first even though older');
  assert.equal(l.rooms[0].friend, true);
  const times = l.rooms.slice(1).map((x) => x.createdAt);
  assert.deepEqual(times, [...times].sort().reverse(), 'then newest first');
  assert.equal((await list(C)).rooms.length, 50);
});

test('list: costs rate limit tokens', async () => {
  throttle = true;
  await db.exec('update public.mp_limits set tokens = 30');
  let limited = 0;
  for (let i = 0; i < 20; i++) {
    const r = await list(C);
    if (r.reason === 'rate_limited') limited++;
  }
  throttle = false;
  assert.ok(limited >= 8, `limited ${limited}`);
});

// ── 從列表加入 ──────────────────────────────────────────────────────────

test('join_listed (2 seats): the stranger sits as guest, the game starts, host is told', async () => {
  const r = await make(A, 'xiangqi', 2, 'public');
  const j = await joinListed(C, r.room.id);
  assert.equal(j.ok, true);
  assert.equal(j.room.status, 'playing');
  assert.equal(j.room.side, 1);
  assert.equal(j.room.guest, C);
  const row = (await sql('select * from public.mp_rooms where id = $1', [r.room.id]))[0];
  assert.equal(row.status, 'playing');
  assert.equal(row.turn, 0);
  assert.equal((await events('room:' + r.room.id, 'joined')).length, 1);
  // a second person: the room is not available any more
  assert.equal((await joinListed(D, r.room.id)).reason, 'full');
  // the same person again (an answer got lost): ok, nothing changes
  const again = await joinListed(C, r.room.id);
  assert.equal(again.ok, true);
  assert.equal(again.room.side, 1);
  assert.equal((await events('room:' + r.room.id, 'joined')).length, 1, 'no second push');
  // the host can read the guest names for the game screen
  const peers = await rpc(A, 'mp_room_peers', r.room.id);
  assert.equal(peers.peers[0].name, '玩家2');
});

test('join_listed (4 seats): seats fill 1,2,3 in order; the 4th person starts the game; a 5th is refused', async () => {
  const r = await make(A, 'mahjong', 4, 'public');
  const j1 = await joinListed(C, r.room.id);
  assert.equal(j1.room.side, 1);
  assert.equal(j1.room.status, 'waiting');
  const j2 = await joinListed(D, r.room.id);
  assert.equal(j2.room.side, 2);
  const j3 = await joinListed(E, r.room.id);
  assert.equal(j3.room.side, 3);
  assert.equal(j3.room.status, 'playing');
  assert.equal(j3.room.bots, 0);
  assert.equal((await joinListed(G, r.room.id)).reason, 'full');
});

test('join_listed: friends-only room only for the host\'s friend; everybody else gets gone', async () => {
  const r = await make(A, 'chess', 2, 'friends');
  assert.equal((await joinListed(C, r.room.id)).reason, 'gone');
  assert.equal((await sql('select guest from public.mp_rooms where id = $1', [r.room.id]))[0].guest, null);
  const j = await joinListed(B, r.room.id);
  assert.equal(j.ok, true);
  assert.equal(j.room.guest, B);
});

test('join_listed: all the "no" answers look the same (no way to tell a room exists)', async () => {
  const fr = await make(A, 'chess', 2, 'friends');
  const gone = (await joinListed(C, uid(777))).reason;
  assert.equal(gone, 'gone');
  assert.equal((await joinListed(C, fr.room.id)).reason, gone, 'friends-only seen by a stranger');
  await block(A, D);
  const pub = await make(A, 'xiangqi', 2, 'public');
  assert.equal((await joinListed(D, pub.room.id)).reason, gone, 'blocked');
  const inv = await rpc(A, 'mp_invite', B, 'holdem');
  assert.equal((await joinListed(C, inv.room.id)).reason, gone, 'a personal invite');
  assert.equal((await joinListed(C, null)).reason, gone);
  // a room that ended
  await sql("update public.mp_rooms set status = 'abandoned' where id = $1", [pub.room.id]);
  assert.equal((await joinListed(C, pub.room.id)).reason, gone);
});

test('join_listed: own room refused; limit of 3 live rooms; counts for the host\'s room cap too', async () => {
  const mine = await make(C, 'xiangqi', 2, 'public');
  assert.equal((await joinListed(C, mine.room.id)).reason, 'own_room');
  await make(C, 'chess', 2, 'public');
  await make(C, 'mahjong', 4, 'public');
  const r = await make(A, 'holdem', 4, 'public');
  assert.equal((await joinListed(C, r.room.id)).reason, 'too_many_rooms');
  assert.equal((await sql('select guest from public.mp_rooms where id = $1', [r.room.id]))[0].guest, null);
});

test('join_listed: a guest who left a waiting 4-seat room frees the seat in the list', async () => {
  const r = await make(A, 'mahjong', 4, 'public');
  await joinListed(C, r.room.id);
  await joinListed(D, r.room.id);
  await joinListed(E, r.room.id);
  assert.deepEqual(ids(await list(G)), []);
  // fresh room again: one guest leaves before it is full
  const r2 = await make(B, 'holdem', 4, 'public');
  await joinListed(C, r2.room.id);
  assert.equal((await list(G)).rooms[0].seated, 2);
  await rpc(C, 'mp_leave', r2.room.id, 'resign');
  assert.equal((await list(G)).rooms[0].seated, 1);
});

test('join_listed: random uuids never count as a wrong guess and never lock the joiner', async () => {
  for (let i = 0; i < 12; i++) assert.equal((await joinListed(C, uid(900 + i))).reason, 'gone');
  const r = await make(A, 'xiangqi', 2, 'public');
  assert.equal((await joinListed(C, r.room.id)).ok, true);
  const lim = (await sql('select join_fails, join_locked_until from public.mp_limits where user_id = $1', [C]))[0];
  assert.equal(lim.join_fails, 0);
  assert.equal(lim.join_locked_until, null);
});

test('join_listed: rate limited', async () => {
  const r = await make(A, 'xiangqi', 2, 'public');
  throttle = true;
  await db.exec('update public.mp_limits set tokens = 30');
  let limited = 0;
  for (let i = 0; i < 20; i++) {
    const x = await joinListed(C, i < 19 ? uid(800 + i) : r.room.id);
    if (x.reason === 'rate_limited') limited++;
  }
  throttle = false;
  assert.ok(limited >= 8, `limited ${limited}`);
});

// ── 用房號加入也要守 friends／封鎖 ─────────────────────────────────────

test('join by code: a friends-only room refuses a stranger like a wrong code, lets the friend in', async () => {
  const r = await make(A, 'chess', 2, 'friends');
  const c = await rpc(C, 'mp_join_room', r.room.code, 'chess');
  assert.equal(c.reason, 'bad_code');
  assert.equal((await sql('select join_fails from public.mp_limits where user_id = $1', [C]))[0].join_fails, 1, 'counts as a wrong guess');
  const b = await rpc(B, 'mp_join_room', r.room.code, 'chess');
  assert.equal(b.ok, true);
  assert.equal(b.room.status, 'playing');
});

test('join by code: public rooms stay open to strangers; a blocked person is refused, in 2-seat and 4-seat rooms', async () => {
  const pub = await make(A, 'xiangqi', 2, 'public');
  assert.equal((await rpc(C, 'mp_join_room', pub.room.code, 'xiangqi')).ok, true);
  const four = await make(B, 'mahjong', 4, 'public');
  await block(B, D);
  assert.equal((await rpc(D, 'mp_join_room', four.room.code, 'mahjong')).reason, 'bad_code');
  assert.equal((await rpc(E, 'mp_join_room', four.room.code, 'mahjong')).ok, true);
  await block(G, E);
  assert.equal((await rpc(G, 'mp_join_room', four.room.code, 'mahjong')).reason, 'bad_code', 'blocked with a seated guest');
});

test('join by code: someone already seated keeps working even if a friendship ended afterwards', async () => {
  const r = await make(A, 'chess', 2, 'friends');
  assert.equal((await rpc(B, 'mp_join_room', r.room.code, 'chess')).ok, true);
  await sql('delete from public.friendships');
  const again = await rpc(B, 'mp_join_room', r.room.code, 'chess');
  assert.equal(again.ok, true, 'an answer that got lost can be asked again');
});

test('join by code: the old flows are not changed (personal invite, code room with 2 seats)', async () => {
  const inv = await rpc(A, 'mp_invite', B, 'xiangqi');
  assert.equal((await rpc(C, 'mp_join_room', inv.room.code, 'xiangqi')).reason, 'bad_code', 'only the invited friend');
  assert.equal((await rpc(B, 'mp_join_room', inv.room.code, 'xiangqi')).ok, true);
});

// ── 整個流程：開房 → 列表 → 加入 → 下棋 ─────────────────────────────────

test('flow: A opens a public xiangqi room, C finds it in the list, joins, both play a move', async () => {
  const r = await make(A, 'xiangqi', 2, 'public');
  const l = await list(C, 'xiangqi');
  assert.equal(l.rooms.length, 1);
  const j = await joinListed(C, l.rooms[0].id);
  assert.equal(j.ok, true);
  assert.equal(j.room.id, r.room.id);
  assert.deepEqual(ids(await list(C, 'xiangqi')), [], 'gone from the list once it started');
  await sql("update public.mp_rooms set last_move_at = now() - interval '5 seconds' where id = $1", [r.room.id]);
  assert.equal((await rpc(A, 'mp_submit_move', r.room.id, 1, '{"m":1}', null, null)).ok, true);
  await sql("update public.mp_rooms set last_move_at = now() - interval '5 seconds' where id = $1", [r.room.id]);
  assert.equal((await rpc(C, 'mp_submit_move', r.room.id, 2, '{"m":2}', null, null)).ok, true);
});
