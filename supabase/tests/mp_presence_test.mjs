// supabase/tests/mp_presence_test.mjs
//
// 好友在線上（mp_ping、mp_friends_online）與拒絕邀請通知房主（mp_leave 的 'declined'）。
// 跟 mp_rooms_test.mjs 一樣在 PGlite 裡跑：friends、mp_rooms、mp_seats、mp_presence 四支 migration
// 套在 supabase_stubs.sql 上，用攻擊者的角度直接打 RPC。
//
//   cd supabase/tests && npm install && node --test --test-concurrency=1 mp_presence_test.mjs

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
  .filter(
    (f) =>
      f.endsWith('.sql') &&
      (f.includes('friends') || f.includes('mp_rooms') || f.includes('mp_seats') || f.includes('mp_presence')),
  )
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const A = uid(1); // 房主
const B = uid(2); // A 的好友
const C = uid(3); // 陌生人
const D = uid(4); // A 的好友、但封鎖了 A
const E = uid(5); // A 的好友
const G = uid(6); // A 的好友

let db;
let throttle = false;

before(async () => {
  db = new PGlite();
  await db.exec(stubs);
  await db.exec(migrations);
  const people = [A, B, C, D, E, G];
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
  await friend(A, E);
  await friend(A, G);
  await friend(B, C);
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
const online = async (user) => (await rpc(user, 'mp_friends_online')).online?.slice().sort();
const sortIds = (...ids) => ids.slice().sort();
const seen = (u, ago) =>
  sql(
    `insert into public.mp_presence (user_id, last_seen) values ($1, now() - ($2 || ' seconds')::interval)
     on conflict (user_id) do update set last_seen = excluded.last_seen`,
    [u, String(ago)],
  );
const events = (topic, ev) =>
  sql('select payload from realtime.messages where topic = $1 and event = $2 order by inserted_at', [topic, ev]);

// ── 在線上 ──────────────────────────────────────────────────────────────

test('presence: signed out answers signed_out for both RPCs', async () => {
  assert.equal((await rpc(null, 'mp_ping')).reason, 'signed_out');
  assert.equal((await rpc(null, 'mp_friends_online')).reason, 'signed_out');
});

test('presence: anon cannot call them; the table is closed to the app', async () => {
  await assert.rejects(as(null, 'select public.mp_ping()', [], 'anon'), /permission denied/);
  await assert.rejects(as(null, 'select public.mp_friends_online()', [], 'anon'), /permission denied/);
  await assert.rejects(as(A, 'select * from public.mp_presence'), /permission denied/);
  await assert.rejects(as(A, 'insert into public.mp_presence (user_id) values ($1)', [A]), /permission denied/);
  await assert.rejects(as(A, 'update public.mp_presence set last_seen = now()'), /permission denied/);
});

test('presence: a ping makes the caller (and only the caller) show up', async () => {
  assert.deepEqual(await online(A), []);
  assert.equal((await rpc(B, 'mp_ping')).ok, true);
  assert.deepEqual(await online(A), [B]);
  const rows = await sql('select user_id from public.mp_presence');
  assert.deepEqual(rows.map((r) => r.user_id), [B]);
});

test('presence: only friends — a stranger is never listed, and cannot see friends of friends', async () => {
  await rpc(B, 'mp_ping');
  await rpc(C, 'mp_ping');
  // A is not C's friend; C is B's friend only
  assert.deepEqual(await online(A), [B]);
  assert.deepEqual(await online(C), [B]);
  assert.deepEqual(await online(E), [], 'E has no online friend');
});

test('presence: a friend who blocked me (or whom I blocked) never shows', async () => {
  await rpc(D, 'mp_ping');
  await rpc(B, 'mp_ping');
  assert.deepEqual(await online(A), [B], 'D blocked A');
  assert.deepEqual(await online(D), [], 'D blocked A: D does not see A either');
  await rpc(A, 'mp_ping');
  assert.deepEqual(await online(D), [], 'still nothing');
  // and the other direction
  await sql('delete from public.blocks');
  await sql('insert into public.blocks (blocker, blocked) values ($1, $2)', [A, B]);
  assert.deepEqual(await online(A), [D]);
});

test('presence: an ended friendship removes the person from the list', async () => {
  await rpc(B, 'mp_ping');
  assert.deepEqual(await online(A), [B]);
  await sql('delete from public.friendships where user_low = least($1::uuid, $2::uuid) and user_high = greatest($1::uuid, $2::uuid)', [A, B]);
  assert.deepEqual(await online(A), []);
});

test('presence: 90 seconds is the edge', async () => {
  await seen(B, 60);
  await seen(E, 89);
  await seen(G, 91);
  assert.deepEqual(await online(A), sortIds(B, E));
});

test('presence: pinging again within 15 s does not rewrite the row; after that it does', async () => {
  await seen(B, 5);
  const before = (await sql('select last_seen from public.mp_presence where user_id = $1', [B]))[0].last_seen;
  assert.equal((await rpc(B, 'mp_ping')).ok, true);
  const same = (await sql('select last_seen from public.mp_presence where user_id = $1', [B]))[0].last_seen;
  assert.equal(String(same), String(before), 'inside 15 s: untouched');
  await seen(B, 30);
  await rpc(B, 'mp_ping');
  const later = (await sql('select (now() - last_seen) < interval \'1 second\' as fresh from public.mp_presence where user_id = $1', [B]))[0];
  assert.equal(later.fresh, true, 'after 30 s: refreshed to now');
});

test('presence: both RPCs spend from the same bucket and stop at rate_limited', async () => {
  throttle = true;
  await db.exec('delete from public.mp_limits');
  let limited = null;
  for (let i = 0; i < 40 && !limited; i++) {
    const r = await rpc(A, i % 2 ? 'mp_ping' : 'mp_friends_online');
    if (r.ok === false) limited = r;
  }
  assert.equal(limited?.reason, 'rate_limited');
});

test('presence: the answer lists user ids only (no names, no times)', async () => {
  await rpc(B, 'mp_ping');
  const r = await rpc(A, 'mp_friends_online');
  assert.deepEqual(Object.keys(r).sort(), ['ok', 'online']);
  assert.deepEqual(r.online, [B]);
});

test('presence: mp_cleanup removes rows older than a day, keeps fresh ones', async () => {
  await seen(B, 3 * 86400);
  await seen(E, 10);
  await db.exec('reset role');
  await db.exec('select public.mp_cleanup()');
  const rows = await sql('select user_id from public.mp_presence');
  assert.deepEqual(rows.map((r) => r.user_id), [E]);
});

// ── 拒絕通知房主 ─────────────────────────────────────────────────────────

test('decline (2 seats): the host gets left and declined, with who declined', async () => {
  const inv = await rpc(A, 'mp_invite', B, 'xiangqi');
  assert.equal(inv.ok, true);
  const out = await rpc(B, 'mp_leave', inv.room.id, 'resign');
  assert.equal(out.ok, true);
  const topic = 'room:' + inv.room.id;
  assert.equal((await events(topic, 'left')).length, 1);
  const d = await events(topic, 'declined');
  assert.equal(d.length, 1);
  assert.equal(d[0].payload.by, B);
  assert.equal(d[0].payload.status, 'abandoned');
  // a second try does not push again
  await rpc(B, 'mp_leave', inv.room.id, 'resign');
  assert.equal((await events(topic, 'declined')).length, 1);
});

test('decline (2 seats): the host cancelling their own invite is not a decline', async () => {
  const inv = await rpc(A, 'mp_invite', B, 'xiangqi');
  await rpc(A, 'mp_leave', inv.room.id, 'resign');
  assert.equal((await events('room:' + inv.room.id, 'declined')).length, 0);
});

test('decline (4 seats): the host is told, the room stays open, the cool-down starts', async () => {
  const c = await rpc(A, 'mp_create_room', 'holdem', 4);
  assert.equal(c.ok, true);
  assert.equal((await rpc(A, 'mp_invite_to', c.room.id, B)).ok, true);
  assert.equal((await rpc(A, 'mp_invite_to', c.room.id, E)).ok, true);
  const out = await rpc(B, 'mp_leave', c.room.id, 'resign');
  assert.equal(out.ok, true);
  const topic = 'room:' + c.room.id;
  const d = await events(topic, 'declined');
  assert.equal(d.length, 1);
  assert.equal(d[0].payload.by, B);
  assert.equal(d[0].payload.status, 'waiting');
  const r = (await sql('select status, end_reason from public.mp_rooms where id = $1', [c.room.id]))[0];
  assert.equal(r.status, 'waiting', 'the room is still open');
  assert.equal((await rpc(E, 'mp_accept_invite', c.room.id)).ok, true, 'the other invite still works');
  assert.equal((await rpc(A, 'mp_invite_to', c.room.id, B)).reason, 'invitee_busy', '5 minute cool-down');
  // declining twice, or someone never invited: nothing more is pushed
  await rpc(B, 'mp_leave', c.room.id, 'resign');
  const stranger = await rpc(C, 'mp_leave', c.room.id, 'resign');
  assert.equal(stranger.reason, 'not_found');
  assert.equal((await events(topic, 'declined')).length, 1);
});

test('decline (4 seats): a seated guest leaving is not a decline', async () => {
  const c = await rpc(A, 'mp_create_room', 'mahjong', 4);
  assert.equal((await rpc(A, 'mp_invite_to', c.room.id, B)).ok, true);
  assert.equal((await rpc(B, 'mp_accept_invite', c.room.id)).ok, true);
  await rpc(B, 'mp_leave', c.room.id, 'resign');
  assert.equal((await events('room:' + c.room.id, 'declined')).length, 0);
  assert.equal((await events('room:' + c.room.id, 'left')).length, 1);
});

test('decline: who can listen — only the room members get the push', async () => {
  const c = await rpc(A, 'mp_create_room', 'holdem', 4);
  await rpc(A, 'mp_invite_to', c.room.id, B);
  await rpc(B, 'mp_leave', c.room.id, 'resign');
  const topic = 'room:' + c.room.id;
  const read = async (u) => {
    await db.exec("update public.mp_limits set tokens = 30");
    await db.exec('set role authenticated');
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [u]);
    await db.query("select set_config('realtime.topic', $1, false)", [topic]);
    try {
      return (await db.query("select event from realtime.messages where event = 'declined'")).rows.length;
    } finally {
      await db.exec('reset role');
      await db.query("select set_config('realtime.topic', '', false)");
      await db.query("select set_config('request.jwt.claim.sub', '', false)");
    }
  };
  assert.equal(await read(A), 1, 'host reads it');
  assert.equal(await read(C), 0, 'a stranger does not');
  assert.equal(await read(B), 0, 'the one who declined is no longer a member');
});
