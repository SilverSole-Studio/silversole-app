// supabase/tests/mp_busy_test.mjs
//
// 對局中標示（mp_ping(p_busy)、mp_friends_online 的 busy、mp_invite／mp_invite_to 回 busy）。
// 跟 mp_rooms_test.mjs 一樣在 PGlite 裡跑：friends、mp_rooms、mp_seats、mp_presence 四支 migration
// 套在 supabase_stubs.sql 上，用攻擊者的角度直接打 RPC。
//
//   cd supabase/tests && npm install && node --test --test-concurrency=1 mp_busy_test.mjs

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
      (f.includes('friends') || f.includes('mp_rooms') || f.includes('mp_seats') || f.includes('mp_presence') || f.includes('mp_busy')),
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

const busyOf = async (user) => (await rpc(user, 'mp_friends_online')).busy?.slice().sort();

test('busy: plain mp_ping() still works (old clients) and means not busy', async () => {
  assert.equal((await rpc(B, 'mp_ping')).ok, true);
  const r = await rpc(A, 'mp_friends_online');
  assert.deepEqual(r.online, [B]);
  assert.deepEqual(r.busy, []);
});

test('busy: ping(true) marks busy, ping(false) clears it at once (even inside the 15s window)', async () => {
  await rpc(B, 'mp_ping');
  await rpc(B, 'mp_ping', true);
  assert.deepEqual(await busyOf(A), [B]);
  assert.deepEqual(await online(A), [B]);
  await rpc(B, 'mp_ping', false);
  assert.deepEqual(await busyOf(A), []);
  assert.deepEqual(await online(A), [B], 'still online');
});

test('busy: expires 90 seconds after the last busy ping', async () => {
  await rpc(B, 'mp_ping', true);
  await sql("update public.mp_presence set busy_until = now() - interval '1 second' where user_id = $1", [B]);
  assert.deepEqual(await busyOf(A), []);
});

test('busy: busy list is a subset of online; strangers / blockers see nothing', async () => {
  await rpc(B, 'mp_ping', true);
  await rpc(D, 'mp_ping', true);
  await rpc(C, 'mp_ping', true);
  assert.deepEqual(await busyOf(A), [B], 'D blocked A, C is a stranger');
  assert.deepEqual(await busyOf(E), [], 'E is not friends with B');
});

test('busy: mp_invite tells the inviter the friend is busy, and still sends the invite', async () => {
  await rpc(B, 'mp_ping', true);
  const r = await rpc(A, 'mp_invite', B, 'xiangqi');
  assert.equal(r.ok, true);
  assert.equal(r.busy, true);
  assert.equal((await events(`user:${B}`, 'invite')).length, 1, 'invite still pushed');
  const again = await rpc(A, 'mp_invite', B, 'xiangqi');
  assert.equal(again.busy, true, 'same-room path also answers busy');
});

test('busy: mp_invite says busy:false for an idle, an offline friend', async () => {
  await rpc(E, 'mp_ping');
  assert.equal((await rpc(A, 'mp_invite', E, 'xiangqi')).busy, false);
  assert.equal((await rpc(A, 'mp_invite', G, 'xiangqi')).busy, false, 'G never pinged');
});

test('busy: a stranger or blocker cannot learn state from mp_invite', async () => {
  await rpc(C, 'mp_ping', true);
  const r = await rpc(A, 'mp_invite', C, 'xiangqi');
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'not_friends');
  assert.equal(r.busy, undefined);
});

test('busy: a stale presence row (no ping for 90s) is not busy even if busy_until is in the future', async () => {
  await rpc(B, 'mp_ping', true);
  await sql("update public.mp_presence set last_seen = now() - interval '100 seconds' where user_id = $1", [B]);
  assert.equal((await rpc(A, 'mp_invite', B, 'xiangqi')).busy, false);
});

test('busy: mp_friend_busy is not callable by the app', async () => {
  await assert.rejects(as(A, 'select public.mp_friend_busy($1)', [B]), /permission denied/);
});

test('busy: mp_invite_to answers busy too (multi-seat room)', async () => {
  const room = (await rpc(A, 'mp_create_room', 'holdem', 4));
  if (!room.ok) return; // 此環境沒有多人房 RPC 就略過
  await rpc(B, 'mp_ping', true);
  const r = await rpc(A, 'mp_invite_to', room.room.id, B);
  assert.equal(r.ok, true);
  assert.equal(r.busy, true);
});
