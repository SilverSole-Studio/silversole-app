// supabase/tests/mp_queue_test.mjs
//
// 快速配對（mp_queue_join、mp_queue_leave、mp_queue_status、mp_room_peers）。
// 跟 mp_presence_test.mjs 一樣在 PGlite 裡跑：friends、mp_rooms、mp_seats、mp_presence、
// mp_quick_match 幾支 migration 套在 supabase_stubs.sql 上，用攻擊者的角度直接打 RPC。
// 同一瞬間很多人按的案例（要真的多連線）在 mp_queue_concurrency_test.mjs。
//
//   cd supabase/tests && npm install && npm run test:mp-queue

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
        f.includes('mp_quick_match')),
  )
  .sort()
  .map((f) => readFileSync(pjoin(migrationsDir, f), 'utf8'))
  .join('\n');

const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const A = uid(1);
const B = uid(2);
const C = uid(3);
const D = uid(4);
const E = uid(5);
const G = uid(6);
const H = uid(7);
const ALL = [A, B, C, D, E, G, H];

let db;
let throttle = false;

before(async () => {
  db = new PGlite();
  await db.exec(stubs);
  await db.exec(migrations);
  for (const [i, u] of ALL.entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query(
      `insert into public.profiles (user_id, friend_code, nickname, avatar_preset) values ($1, $2, $3, $4)`,
      [u, String(40000000 + i), `玩家${i}`, (i % 12) + 1],
    );
  }
});

beforeEach(async () => {
  throttle = false;
  await db.exec('begin');
});
afterEach(async () => {
  await db.exec('rollback');
  await db.exec('reset role');
});

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
const join = (u, game = 'xiangqi', seats = 2) => rpc(u, 'mp_queue_join', game, seats);
const status = (u) => rpc(u, 'mp_queue_status');
const leave = (u) => rpc(u, 'mp_queue_leave');
const events = (topic, ev) =>
  sql('select payload from realtime.messages where topic = $1 and event = $2 order by inserted_at, id', [topic, ev]);
const rows = (q = '') => sql(`select * from public.mp_queue ${q}`);
const waiting = () => rows('where room is null');
/** 讓某人的排隊列「早就排了」：把 joined_at 往前推，順序才固定。 */
const early = (u, secs) =>
  sql("update public.mp_queue set joined_at = now() - ($2 || ' seconds')::interval where user_id = $1", [u, String(secs)]);
const block = (x, y) => sql('insert into public.blocks (blocker, blocked) values ($1, $2)', [x, y]);

// ── 基本 ────────────────────────────────────────────────────────────────

test('queue: signed out answers signed_out for every RPC', async () => {
  assert.equal((await rpc(null, 'mp_queue_join', 'xiangqi', 2)).reason, 'signed_out');
  assert.equal((await rpc(null, 'mp_queue_leave')).reason, 'signed_out');
  assert.equal((await rpc(null, 'mp_queue_status')).reason, 'signed_out');
  assert.equal((await rpc(null, 'mp_room_peers', uid(99))).reason, 'signed_out');
});

test('queue: anon cannot call them; internal helpers and the table are closed to the app', async () => {
  await assert.rejects(as(null, "select public.mp_queue_join('xiangqi', 2)", [], 'anon'), /permission denied/);
  await assert.rejects(as(null, 'select public.mp_queue_status()', [], 'anon'), /permission denied/);
  await assert.rejects(as(A, "select public.mp_queue_count('xiangqi', 2)"), /permission denied/);
  await assert.rejects(as(A, "select public.mp_queue_tell('xiangqi', 2, null)"), /permission denied/);
  await assert.rejects(as(A, 'select * from public.mp_queue'), /permission denied/);
  await assert.rejects(as(A, "insert into public.mp_queue (user_id, game, seats) values ($1, 'xiangqi', 2)", [A]), /permission denied/);
  await assert.rejects(as(A, 'update public.mp_queue set seats = 4'), /permission denied/);
  await assert.rejects(as(A, 'delete from public.mp_queue'), /permission denied/);
});

test('queue: bad game and bad seats are refused without touching the queue', async () => {
  assert.equal((await join(A, 'Bad Game!')).reason, 'bad_game');
  assert.equal((await join(A, null)).reason, 'bad_game');
  assert.equal((await join(A, 'xiangqi', 1)).reason, 'bad_seats');
  assert.equal((await join(A, 'xiangqi', 5)).reason, 'bad_seats');
  assert.equal((await join(A, 'xiangqi', null)).reason, 'bad_seats');
  assert.equal((await rows()).length, 0);
});

// ── 兩個人配對 ──────────────────────────────────────────────────────────

test('queue (2 seats): the first waits, the second is matched into a playing room', async () => {
  const a = await join(A);
  assert.equal(a.ok, true);
  assert.equal(a.matched, false);
  assert.equal(a.waiting, 1);
  assert.equal((await status(A)).queued, true);
  assert.equal((await status(A)).waiting, 1);
  await early(A, 30);

  const b = await join(B);
  assert.equal(b.ok, true);
  assert.equal(b.matched, true);
  assert.equal(b.room.status, 'playing');
  assert.equal(b.room.game, 'xiangqi');
  assert.equal(b.room.side, 1, 'B waited less, so B sits second');
  assert.equal(b.room.host, A);
  assert.equal(b.room.guest, B);
  assert.equal(b.room.code, null, 'a quick-match room has no code to guess');
  const r = (await sql('select * from public.mp_rooms where id = $1', [b.room.id]))[0];
  assert.equal(r.seats, 2);
  assert.equal(r.bots, 0);
  assert.equal(r.turn, 0);
  assert.equal(r.invited, null);

  // B has no queue row left; A's row is now a mailbox
  assert.deepEqual((await rows()).map((x) => [x.user_id, x.room !== null]), [[A, true]]);
  const ev = await events('user:' + A, 'matched');
  assert.equal(ev.length, 1);
  assert.equal(ev[0].payload.room, b.room.id);
  assert.equal(ev[0].payload.game, 'xiangqi');
  assert.equal((await events('user:' + B, 'matched')).length, 0, 'the one who pressed last gets it from the reply');

  // A collects it with status, once
  const sa = await status(A);
  assert.equal(sa.matched, true);
  assert.equal(sa.queued, false);
  assert.equal(sa.room.id, b.room.id);
  assert.equal(sa.room.side, 0);
  assert.equal((await rows()).length, 0);
  const again = await status(A);
  assert.equal(again.matched, false);
  assert.equal(again.queued, false);
});

test('queue: strangers (not friends) can be matched, and the matched room plays like any other', async () => {
  await join(A);
  await early(A, 5);
  const b = await join(B);
  const id = b.room.id;
  // host moves first (turn 0), the guest cannot
  assert.equal((await rpc(B, 'mp_submit_move', id, 1, '{"m":1}', null, null)).reason, 'not_your_turn');
  await sql("update public.mp_rooms set last_move_at = now() - interval '5 seconds' where id = $1", [id]);
  const m = await rpc(A, 'mp_submit_move', id, 1, '{"m":1}', null, null);
  assert.equal(m.ok, true);
  await sql("update public.mp_rooms set last_move_at = now() - interval '5 seconds' where id = $1", [id]);
  assert.equal((await rpc(B, 'mp_submit_move', id, 2, '{"m":2}', null, null)).ok, true);
  // a third person cannot read it or move
  assert.equal((await rpc(C, 'mp_submit_move', id, 3, '{"m":3}', null, null)).reason, 'not_found');
  const seen = await as(C, 'select id from public.mp_rooms where id = $1', [id]);
  assert.equal(seen.rows.length, 0);
});

test('queue: different game, or different seats, never match', async () => {
  await join(A, 'xiangqi', 2);
  const b = await join(B, 'chess', 2);
  assert.equal(b.matched, false);
  assert.equal(b.waiting, 1);
  const c = await join(C, 'xiangqi', 4);
  assert.equal(c.matched, false);
  assert.equal(c.waiting, 1);
  assert.equal((await rows()).length, 3);
});

test('queue: one row per person — pressing again keeps the place, another game moves the row', async () => {
  await join(A);
  await early(A, 100);
  const before = (await rows())[0].joined_at;
  const again = await join(A);
  assert.equal(again.matched, false);
  assert.equal(again.waiting, 1);
  const r1 = await rows();
  assert.equal(r1.length, 1);
  assert.equal(String(r1[0].joined_at), String(before), 'same group: the waiting time is kept');
  const other = await join(A, 'chess', 2);
  assert.equal(other.waiting, 1);
  const r2 = await rows();
  assert.equal(r2.length, 1);
  assert.equal(r2[0].game, 'chess');
  // the old group no longer has A
  const b = await join(B, 'xiangqi', 2);
  assert.equal(b.matched, false, 'A moved to chess');
});

test('queue: you cannot be matched with yourself', async () => {
  await join(A);
  const again = await join(A);
  assert.equal(again.matched, false);
  assert.equal((await rows()).length, 1);
});

// ── 四個人 ──────────────────────────────────────────────────────────────

test('queue (4 seats): waits for four real players, counts 1/2/3, seats them in queue order', async () => {
  const order = [A, B, C, D];
  const out = [];
  for (const [i, u] of order.entries()) {
    out.push(await join(u, 'mahjong', 4));
    if (i < 3) await early(u, 400 - i * 100);
  }
  assert.deepEqual(out.slice(0, 3).map((x) => [x.matched, x.waiting]), [[false, 1], [false, 2], [false, 3]]);
  assert.equal(out[3].matched, true);
  const r = (await sql('select * from public.mp_rooms where id = $1', [out[3].room.id]))[0];
  assert.deepEqual([r.host, r.guest, r.guest2, r.guest3], [A, B, C, D]);
  assert.equal(r.seats, 4);
  assert.equal(r.status, 'playing');
  assert.equal(r.bots, 0, 'no computer players');
  assert.equal(out[3].room.side, 3);
  for (const [seat, u] of [[0, A], [1, B], [2, C]]) {
    const s = await status(u);
    assert.equal(s.matched, true);
    assert.equal(s.room.side, seat);
  }
  assert.equal((await rows()).length, 0);
});

test('queue (4 seats): 3 players never start; the queue count is pushed to the others', async () => {
  await join(A, 'holdem', 4);
  await join(B, 'holdem', 4);
  await join(C, 'holdem', 4);
  assert.equal((await rows()).length, 3);
  assert.equal((await sql('select 1 from public.mp_rooms')).length, 0);
  // A hears "2" when B came, "3" when C came (and nothing for its own press)
  const toA = (await events('user:' + A, 'queue')).map((e) => e.payload.waiting).sort();
  assert.deepEqual(toA, [2, 3]);
  assert.equal((await events('user:' + C, 'queue')).length, 0);
  const p = (await events('user:' + A, 'queue'))[0].payload;
  assert.equal(p.game, 'holdem');
  assert.equal(p.seats, 4);
  assert.equal((await status(A)).waiting, 3);
});

test('queue (4 seats): a fifth person waits for the next table', async () => {
  for (const u of [A, B, C]) await join(u, 'mahjong', 4);
  const d = await join(D, 'mahjong', 4);
  assert.equal(d.matched, true);
  const e = await join(E, 'mahjong', 4);
  assert.equal(e.matched, false);
  assert.equal(e.waiting, 1);
});

// ── 取消 ────────────────────────────────────────────────────────────────

test('leave: cancelling removes me; nobody is matched to a ghost', async () => {
  await join(A);
  const l = await leave(A);
  assert.equal(l.ok, true);
  assert.equal(l.matched, false);
  assert.equal((await rows()).length, 0);
  const b = await join(B);
  assert.equal(b.matched, false);
  assert.equal((await status(A)).queued, false);
});

test('leave: telling the others the count dropped; leaving twice or never joining is ok', async () => {
  await join(A, 'mahjong', 4);
  await join(B, 'mahjong', 4);
  await leave(B);
  const toA = (await events('user:' + A, 'queue')).map((e) => e.payload.waiting).sort();
  assert.deepEqual(toA, [1, 2]);
  assert.equal((await leave(B)).ok, true);
  assert.equal((await leave(C)).ok, true);
});

test('leave: if I was already matched, cancelling hands me the room instead of losing it', async () => {
  await join(A);
  await early(A, 5);
  const b = await join(B);
  const l = await leave(A);
  assert.equal(l.ok, true);
  assert.equal(l.matched, true);
  assert.equal(l.room.id, b.room.id);
  assert.equal(l.room.side, 0);
  assert.equal((await rows()).length, 0);
  assert.equal((await leave(A)).matched, false, 'only once');
});

// ── 封鎖 ────────────────────────────────────────────────────────────────

test('block: two people who blocked each other are never matched (either direction)', async () => {
  await block(B, A);
  await join(A);
  const b = await join(B);
  assert.equal(b.matched, false);
  assert.equal(b.waiting, 2, 'both are waiting');
  // C takes the longest-waiting person they may be with: A
  await early(A, 100);
  await early(B, 50);
  const c = await join(C);
  assert.equal(c.matched, true);
  assert.equal(c.room.host, A);
  assert.equal(c.room.guest, C);
  assert.deepEqual((await waiting()).map((x) => x.user_id), [B], 'B still waits');
});

test('block: the other direction (A blocked B) works the same way', async () => {
  await block(A, B);
  await join(A);
  const b = await join(B);
  assert.equal(b.matched, false);
});

test('block (4 seats): the table must be clean pairwise, not just against me', async () => {
  await block(B, C); // B and C cannot sit together
  for (const [u, s] of [[A, 500], [B, 400], [C, 300]]) {
    await join(u, 'mahjong', 4);
    await early(u, s);
  }
  const d = await join(D, 'mahjong', 4);
  assert.equal(d.matched, false, 'A, B, C, D would put B and C together');
  assert.equal(d.waiting, 4);
  const e = await join(E, 'mahjong', 4);
  // A, B, D, E is a clean table (C is skipped: blocked with B)
  assert.equal(e.matched, true);
  const r = (await sql('select * from public.mp_rooms where id = $1', [e.room.id]))[0];
  assert.deepEqual(new Set([r.host, r.guest, r.guest2, r.guest3]), new Set([A, B, D, E]));
  assert.deepEqual((await waiting()).map((x) => x.user_id), [C]);
});

// ── 過期、離線 ──────────────────────────────────────────────────────────

test('stale: after 10 minutes a waiting row is not matched, and join cleans it', async () => {
  await join(A);
  await early(A, 11 * 60);
  const b = await join(B);
  assert.equal(b.matched, false);
  assert.equal(b.waiting, 1);
  assert.deepEqual((await rows()).map((x) => x.user_id), [B], "A's old row was cleaned");
});

test('stale: status tells an expired waiter, and removes the row', async () => {
  await join(A);
  await early(A, 11 * 60);
  const s = await status(A);
  assert.equal(s.queued, false);
  assert.equal(s.expired, true);
  assert.equal((await rows()).length, 0);
});

test('offline: someone who has not checked in for 40 seconds is not matched; status brings them back', async () => {
  await join(A);
  await sql("update public.mp_queue set seen_at = now() - interval '41 seconds'");
  const b = await join(B);
  assert.equal(b.matched, false);
  assert.equal(b.waiting, 1, 'a ghost is not counted');
  const s = await status(A);
  assert.equal(s.queued, true);
  const c = await join(C);
  assert.equal(c.matched, true);
  assert.equal(c.room.host, A, 'A is back and has waited longest');
});

test('offline: status writes seen_at at most once every 10 seconds', async () => {
  await join(A);
  await sql("update public.mp_queue set seen_at = now() - interval '5 seconds'");
  const t1 = (await rows())[0].seen_at;
  await status(A);
  assert.equal(String((await rows())[0].seen_at), String(t1), 'inside 10 s: untouched');
  await sql("update public.mp_queue set seen_at = now() - interval '30 seconds'");
  await status(A);
  const fresh = await sql("select (now() - seen_at) < interval '1 second' as f from public.mp_queue");
  assert.equal(fresh[0].f, true);
});

test('cleanup: mp_cleanup removes old queue rows and uncollected mailboxes, keeps fresh ones', async () => {
  await join(A);
  await early(A, 11 * 60);
  await join(B, 'chess', 2);
  await join(C, 'xiangqi', 2); // matches nobody (A is stale and not a candidate)
  await join(D, 'mahjong', 4);
  // a mailbox that nobody collected for 11 minutes
  await join(E, 'chess', 2); // matches B
  await sql("update public.mp_queue set matched_at = now() - interval '11 minutes' where room is not null");
  await db.exec('reset role');
  await db.exec('select public.mp_cleanup()');
  const left = (await rows()).map((x) => x.user_id).sort();
  assert.deepEqual(left, [C, D].sort());
});

// ── 房間上限 ────────────────────────────────────────────────────────────

test('rooms: a person who already has 3 live rooms cannot queue', async () => {
  for (let i = 0; i < 3; i++) assert.equal((await rpc(A, 'mp_create_room', 'xiangqi')).ok, true);
  const j = await join(A);
  assert.equal(j.ok, false);
  assert.equal(j.reason, 'too_many_rooms');
  assert.equal((await rows()).length, 0);
});

test('rooms: a waiting person whose rooms filled up meanwhile is skipped, not matched', async () => {
  // A waits; while waiting A fills up 3 rooms some other way
  await join(A);
  await early(A, 100);
  for (let i = 0; i < 3; i++) assert.equal((await rpc(A, 'mp_create_room', 'chess')).ok, true);
  const b = await join(B);
  assert.equal(b.matched, false, 'A cannot take a 4th live room');
  assert.equal(b.waiting, 2);
  // C is matched with B (who has waited longer than C), A is skipped
  const c = await join(C);
  assert.equal(c.matched, true);
  assert.equal(c.room.host, B);
  assert.deepEqual((await waiting()).map((x) => x.user_id), [A]);
});

test('rooms: a stale room (2 hours untouched) does not count against the person', async () => {
  await join(A);
  await early(A, 100);
  for (let i = 0; i < 3; i++) assert.equal((await rpc(A, 'mp_create_room', 'chess')).ok, true);
  await sql("update public.mp_rooms set updated_at = now() - interval '3 hours'");
  const b = await join(B);
  assert.equal(b.matched, true);
});

// ── 信箱 ────────────────────────────────────────────────────────────────

test('mailbox: pressing join again with an uncollected match gives that match back', async () => {
  await join(A);
  await early(A, 100);
  const b = await join(B);
  const a2 = await join(A);
  assert.equal(a2.matched, true);
  assert.equal(a2.room.id, b.room.id);
  assert.equal((await rows()).length, 0, 'not queued a second time');
});

test('mailbox: a match for another game is dropped, and the person queues fresh', async () => {
  await join(A, 'chess', 2);
  await early(A, 100);
  await join(B, 'chess', 2);
  const a2 = await join(A, 'xiangqi', 2);
  assert.equal(a2.matched, false);
  assert.equal(a2.waiting, 1);
  assert.deepEqual((await rows()).map((x) => [x.user_id, x.game, x.room]), [[A, 'xiangqi', null]]);
});

// ── 暱稱與頭像 ──────────────────────────────────────────────────────────

test('peers: members see the others name and preset avatar, nothing else', async () => {
  await join(A);
  await early(A, 100);
  const b = await join(B);
  const pa = await rpc(A, 'mp_room_peers', b.room.id);
  assert.equal(pa.ok, true);
  assert.equal(pa.peers.length, 1);
  assert.deepEqual(Object.keys(pa.peers[0]).sort(), ['avatar', 'id', 'name', 'seat']);
  assert.equal(pa.peers[0].id, B);
  assert.equal(pa.peers[0].name, '玩家1');
  assert.equal(pa.peers[0].seat, 1);
  assert.equal(pa.peers[0].avatar, 2);
  const pb = await rpc(B, 'mp_room_peers', b.room.id);
  assert.equal(pb.peers[0].id, A);
  assert.equal(pb.peers[0].seat, 0);
});

test('peers: 4 seats lists the three others in seat order', async () => {
  const outs = [];
  for (const [i, u] of [A, B, C, D].entries()) {
    outs.push(await join(u, 'mahjong', 4));
    if (i < 3) await early(u, 400 - i * 100);
  }
  const p = await rpc(C, 'mp_room_peers', outs[3].room.id);
  assert.deepEqual(p.peers.map((x) => x.id), [A, B, D]);
  assert.deepEqual(p.peers.map((x) => x.seat), [0, 1, 3]);
});

test('peers: a stranger to the room, or a missing room, gets not_found and learns nothing', async () => {
  await join(A);
  await early(A, 100);
  const b = await join(B);
  assert.equal((await rpc(C, 'mp_room_peers', b.room.id)).reason, 'not_found');
  assert.equal((await rpc(C, 'mp_room_peers', uid(99))).reason, 'not_found');
  assert.equal((await rpc(C, 'mp_room_peers', null)).reason, 'not_found');
});

test('peers: a missing nickname shows the default name', async () => {
  await sql('update public.profiles set nickname = null where user_id = $1', [B]);
  await join(A);
  await early(A, 100);
  const b = await join(B);
  assert.equal((await rpc(A, 'mp_room_peers', b.room.id)).peers[0].name, '銀足朋友');
});

// ── 限流 ────────────────────────────────────────────────────────────────

test('rate limit: join costs 5, leave 3, status 1, peers 2 — and stops at rate_limited', async () => {
  throttle = true;
  await db.exec('delete from public.mp_limits');
  let limited = null;
  let n = 0;
  for (let i = 0; i < 40 && !limited; i++) {
    const r = await join(A);
    n++;
    if (r.ok === false) limited = r;
  }
  assert.equal(limited?.reason, 'rate_limited');
  assert.equal(n, 7, '30 tokens / 5 each: six presses pass, the seventh is refused');
  const lim = await sql('select tokens from public.mp_limits where user_id = $1', [A]);
  assert.ok(lim[0].tokens < 5);
});

test('rate limit: hammering leave/status is limited by the same bucket', async () => {
  throttle = true;
  await db.exec('delete from public.mp_limits');
  let limited = null;
  for (let i = 0; i < 80 && !limited; i++) {
    const r = await (i % 2 ? leave(A) : status(A));
    if (r.ok === false) limited = r;
  }
  assert.equal(limited?.reason, 'rate_limited');
});
