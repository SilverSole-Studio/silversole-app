// supabase/tests/friend_share_link_test.mjs
//
// 社群連結加好友（20261109120000_friend_share_link.sql）：在 PGlite 裡跑 friends 系列 migration
// ＋ mp_*（friend_suggest 要用 mp_take）＋ friend_suggest ＋ friend_share_link，然後像攻擊者一樣
// 直接打 RPC：過期、停用、一人一條、換連結洗額度、陌生人拿到什麼、封鎖、直接讀表。
//
//   cd supabase/tests && npm install && npm run test:share-link
//
// PGlite 只有一條連線，時間不會動：需要「7 天後」「隔天」的案例用表擁有者直接改時間欄。
// 並發的案例在 friend_share_link_concurrency_test.mjs（embedded-postgres）。

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
  .filter(
    (f) =>
      f.endsWith('.sql') &&
      (f.includes('friends') ||
        f.includes('mp_rooms') ||
        f.includes('mp_seats') ||
        f.includes('mp_presence') ||
        f.includes('mp_quick_match') ||
        f.includes('friend_suggest') ||
        f.includes('friend_share_link')),
  )
  .sort()
  .map((f) => {
    const text = readFileSync(join(migrationsDir, f), 'utf8');
    // pg_cron 不在測試用的資料庫裡；排程那段與連結無關。
    return text.replace(/select cron\.schedule\([\s\S]*?\$cron\$\s*\);/g, '');
  })
  .join('\n');

const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const ids = { me: uid(1), wang: uid(2), chen: uid(3), lin: uid(4) };

class World {
  constructor(db) {
    this.db = db;
  }

  async as(user, sql, params = [], role = 'authenticated') {
    // PGlite 的時間不會動，每人限流桶永遠不補：每次呼叫前補滿。
    await this.db.exec('delete from public.friend_rate_buckets');
    await this.db.exec(`set role ${role}`);
    await this.db.query("select set_config('request.jwt.claim.sub', $1, false)", [user ?? '']);
    try {
      return await this.db.query(sql, params);
    } finally {
      await this.db.exec('reset role');
      await this.db.query("select set_config('request.jwt.claim.sub', '', false)");
    }
  }

  async rpc(user, fn, ...args) {
    const ph = args.map((_, i) => `$${i + 1}`).join(', ');
    return (await this.as(user, `select public.${fn}(${ph}) as r`, args)).rows[0].r;
  }

  /** 預期失敗：回傳 {error} 的代碼，或 raise 的訊息。 */
  async rpcErr(user, fn, ...args) {
    try {
      const r = await this.rpc(user, fn, ...args);
      if (r && typeof r === 'object' && 'error' in r) return r.error;
      assert.fail(`expected ${fn} to fail, got ${JSON.stringify(r)}`);
    } catch (e) {
      if (e.code === 'ERR_ASSERTION') throw e;
      return e.message;
    }
  }

  async sql(sql, params = []) {
    return (await this.db.query(sql, params)).rows;
  }

  async addUser(user, nickname) {
    await this.sql('insert into auth.users (id) values ($1)', [user]);
    await this.rpc(user, 'get_my_profile');
    await this.sql(
      "update public.profiles set created_at = now() - interval '7 days' where user_id = $1",
      [user],
    );
    if (nickname) await this.rpc(user, 'update_profile', nickname, null, null);
  }

  async areFriends(a, b) {
    return (await this.sql('select public.are_friends($1, $2) as r', [a, b]))[0].r;
  }
}

async function world() {
  const db = new PGlite();
  await db.exec(stubs);
  await db.exec(migration);
  const w = new World(db);
  await w.addUser(ids.me, '我自己');
  await w.addUser(ids.wang, '王阿姨');
  await w.addUser(ids.chen, '陳伯伯');
  return w;
}

/** 王阿姨產生連結，回 token。 */
async function wangLink(w) {
  const r = await w.rpc(ids.wang, 'create_share_link');
  assert.match(r.token, /^[0-9a-f]{32}$/);
  return r.token;
}

async function senders(w, n, from = 100) {
  const out = [];
  for (let i = 0; i < n; i++) {
    const u = uid(from + i);
    await w.addUser(u, `路人${i}`);
    out.push(u);
  }
  return out;
}

// ── 產生、重用、一人一條 ─────────────────────────────────────────────

test('a link is 32 hex chars and lasts 7 days; asking again returns the same one', async () => {
  const w = await world();
  const a = await w.rpc(ids.wang, 'create_share_link');
  assert.match(a.token, /^[0-9a-f]{32}$/);
  const [{ days }] = await w.sql(
    'select extract(epoch from ($1::timestamptz - now())) / 86400 as days',
    [a.expires_at],
  );
  assert.ok(Math.abs(Number(days) - 7) < 0.01, `expires in ~7 days, got ${days}`);
  const b = await w.rpc(ids.wang, 'create_share_link');
  assert.equal(b.token, a.token);
  assert.equal(b.expires_at, a.expires_at);
  const rows = await w.sql('select count(*)::int as n from public.friend_share_links');
  assert.equal(rows[0].n, 1);
});

test('one link per person: a new one replaces the old, and the old one stops working', async () => {
  const w = await world();
  const old = await wangLink(w);
  await w.sql("update public.friend_share_links set expires_at = now() - interval '1 second'");
  const fresh = await w.rpc(ids.wang, 'create_share_link');
  assert.notEqual(fresh.token, old);
  assert.equal((await w.sql('select count(*)::int as n from public.friend_share_links'))[0].n, 1);
  assert.equal(await w.rpcErr(ids.me, 'preview_by_share_link', old), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'link', old), 'not_found');
  assert.equal((await w.rpc(ids.me, 'preview_by_share_link', fresh.token)).nickname, '王阿姨');
});

test('get_share_link says whether there is a live link', async () => {
  const w = await world();
  assert.deepEqual(await w.rpc(ids.wang, 'get_share_link'), { active: false });
  const { token } = await w.rpc(ids.wang, 'create_share_link');
  const g = await w.rpc(ids.wang, 'get_share_link');
  assert.equal(g.active, true);
  assert.equal(g.token, token);
  // 別人看不到我的連結。
  assert.deepEqual(await w.rpc(ids.me, 'get_share_link'), { active: false });
});

test('someone with no nickname cannot make a link', async () => {
  const w = await world();
  await w.addUser(ids.lin, null);
  assert.equal(await w.rpcErr(ids.lin, 'create_share_link'), 'nickname_invalid');
});

// ── 過期、停用 ───────────────────────────────────────────────────────

test('after 7 days the link reads as expired for preview and for sending', async () => {
  const w = await world();
  const token = await wangLink(w);
  assert.equal((await w.rpc(ids.me, 'preview_by_share_link', token)).nickname, '王阿姨');
  await w.sql("update public.friend_share_links set expires_at = now() - interval '1 second'");
  assert.equal(await w.rpcErr(ids.me, 'preview_by_share_link', token), 'link_expired');
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'link', token), 'link_expired');
  assert.deepEqual(await w.rpc(ids.wang, 'get_share_link'), { active: false });
});

test('disabling kills the link at once; making a new one works', async () => {
  const w = await world();
  const token = await wangLink(w);
  assert.deepEqual(await w.rpc(ids.wang, 'disable_share_link'), { ok: true });
  assert.equal(await w.rpcErr(ids.me, 'preview_by_share_link', token), 'link_expired');
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'link', token), 'link_expired');
  // 再按一次、或根本沒有連結的人按，都不報錯。
  assert.deepEqual(await w.rpc(ids.wang, 'disable_share_link'), { ok: true });
  assert.deepEqual(await w.rpc(ids.chen, 'disable_share_link'), { ok: true });
  const fresh = await w.rpc(ids.wang, 'create_share_link');
  assert.notEqual(fresh.token, token);
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'link', fresh.token)).result, 'sent');
  assert.equal(await w.rpcErr(ids.chen, 'send_friend_request', 'link', token), 'not_found');
});

test('a request already sent survives the link being disabled', async () => {
  const w = await world();
  const token = await wangLink(w);
  await w.rpc(ids.me, 'send_friend_request', 'link', token);
  await w.rpc(ids.wang, 'disable_share_link');
  const inc = await w.rpc(ids.wang, 'get_friend_requests');
  assert.equal(inc.length, 1);
  assert.equal(inc[0].source, 'link');
  await w.rpc(ids.wang, 'respond_friend_request', inc[0].id, 'accept');
  assert.equal(await w.areFriends(ids.me, ids.wang), true);
});

// ── 陌生人看到什麼、加好友要對方同意 ───────────────────────────────────

test('a stranger sees only nickname and preset avatar, never the photo or the code', async () => {
  const w = await world();
  await w.sql('update public.profiles set avatar_path = $2, avatar_preset = 7 where user_id = $1', [
    ids.wang,
    `${ids.wang}/1760000000000.jpg`,
  ]);
  const token = await wangLink(w);
  const p = await w.rpc(ids.me, 'preview_by_share_link', token);
  assert.deepEqual(Object.keys(p).sort(), ['avatar_path', 'avatar_preset', 'nickname', 'user_id']);
  assert.equal(p.nickname, '王阿姨');
  assert.equal(p.avatar_preset, 7);
  assert.equal(p.avatar_path, null);
  assert.equal(JSON.stringify(p).includes('friend_code'), false);
});

test('opening the link does nothing by itself; the request needs consent', async () => {
  const w = await world();
  const token = await wangLink(w);
  await w.rpc(ids.me, 'preview_by_share_link', token);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'link', token)).result, 'sent');
  assert.equal(await w.areFriends(ids.me, ids.wang), false);
  const inc = await w.rpc(ids.wang, 'get_friend_requests');
  assert.equal(inc[0].incoming, true);
  assert.equal(inc[0].other.user_id, ids.me);
  await w.rpc(ids.wang, 'respond_friend_request', inc[0].id, 'accept');
  assert.equal(await w.areFriends(ids.me, ids.wang), true);
  const [f] = await w.sql('select source from public.friendships');
  assert.equal(f.source, 'link');
});

test('if she already asked me, my click on her link makes us friends', async () => {
  const w = await world();
  const token = await wangLink(w);
  const qr = (await w.rpc(ids.me, 'create_qr_token')).token;
  await w.rpc(ids.wang, 'send_friend_request', 'qr', qr);
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'link', token)).result, 'became_friends');
});

test('already friends: preview says so, sending says already_friends', async () => {
  const w = await world();
  const token = await wangLink(w);
  await w.rpc(ids.me, 'send_friend_request', 'link', token);
  const inc = await w.rpc(ids.wang, 'get_friend_requests');
  await w.rpc(ids.wang, 'respond_friend_request', inc[0].id, 'accept');
  assert.equal((await w.rpc(ids.me, 'preview_by_share_link', token)).already_friends, true);
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'link', token)).result, 'already_friends');
});

// ── 自己、封鎖、壞 token ────────────────────────────────────────────

test('my own link and junk tokens are not found; upper case still works', async () => {
  const w = await world();
  const token = await wangLink(w);
  assert.equal(await w.rpcErr(ids.wang, 'preview_by_share_link', token), 'not_found');
  assert.equal(await w.rpcErr(ids.wang, 'send_friend_request', 'link', token), 'not_found');
  for (const junk of ['', 'nope', 'x'.repeat(32), "'; drop table x; --", token.slice(1)]) {
    assert.equal(await w.rpcErr(ids.me, 'preview_by_share_link', junk), 'not_found');
    assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'link', junk), 'not_found');
  }
  assert.equal((await w.rpc(ids.me, 'preview_by_share_link', token.toUpperCase())).nickname, '王阿姨');
});

test('a blocked person (either direction) gets not_found, not even "expired"', async () => {
  const w = await world();
  const token = await wangLink(w);
  await w.rpc(ids.wang, 'block_user', ids.me);
  assert.equal(await w.rpcErr(ids.me, 'preview_by_share_link', token), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'link', token), 'not_found');
  await w.rpc(ids.wang, 'unblock_user', ids.me);
  await w.rpc(ids.me, 'block_user', ids.wang);
  assert.equal(await w.rpcErr(ids.me, 'preview_by_share_link', token), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'link', token), 'not_found');
});

// ── 每天最多 10 封 ───────────────────────────────────────────────────

test('the 11th person to send through links in a day is refused', async () => {
  const w = await world();
  const token = await wangLink(w);
  const people = await senders(w, 11);
  for (const u of people.slice(0, 10)) {
    assert.equal((await w.rpc(u, 'send_friend_request', 'link', token)).result, 'sent');
  }
  assert.equal(await w.rpcErr(people[10], 'send_friend_request', 'link', token), 'link_limit');
  assert.equal((await w.rpc(ids.wang, 'get_friend_requests')).length, 10);
});

test('a new link, a disabled link or cancelled requests do not wash the count', async () => {
  const w = await world();
  let token = await wangLink(w);
  const people = await senders(w, 12);
  for (const u of people.slice(0, 10)) await w.rpc(u, 'send_friend_request', 'link', token);
  // 換連結。
  await w.rpc(ids.wang, 'disable_share_link');
  token = await wangLink(w);
  assert.equal(await w.rpcErr(people[10], 'send_friend_request', 'link', token), 'link_limit');
  // 送的人取消，名額不還。
  const out = await w.rpc(people[0], 'get_friend_requests');
  await w.rpc(people[0], 'cancel_friend_request', out[0].id);
  assert.equal(await w.rpcErr(people[11], 'send_friend_request', 'link', token), 'link_limit');
  // 王阿姨拒絕也不還。
  const inc = await w.rpc(ids.wang, 'get_friend_requests');
  await w.rpc(ids.wang, 'respond_friend_request', inc[0].id, 'decline');
  assert.equal(await w.rpcErr(people[11], 'send_friend_request', 'link', token), 'link_limit');
  const [{ received }] = await w.sql('select received from public.friend_link_inbox');
  assert.equal(received, 10);
});

test('the next day the count starts over', async () => {
  const w = await world();
  const token = await wangLink(w);
  const people = await senders(w, 11);
  for (const u of people.slice(0, 10)) await w.rpc(u, 'send_friend_request', 'link', token);
  assert.equal(await w.rpcErr(people[10], 'send_friend_request', 'link', token), 'link_limit');
  await w.sql('update public.friend_link_inbox set day = day - 1');
  assert.equal((await w.rpc(people[10], 'send_friend_request', 'link', token)).result, 'sent');
});

test('the cap is per recipient: links to someone else are not affected', async () => {
  const w = await world();
  const token = await wangLink(w);
  const chenToken = (await w.rpc(ids.chen, 'create_share_link')).token;
  const people = await senders(w, 11);
  for (const u of people.slice(0, 10)) await w.rpc(u, 'send_friend_request', 'link', token);
  assert.equal((await w.rpc(people[10], 'send_friend_request', 'link', chenToken)).result, 'sent');
});

test('the cap counts only links: QR requests to the same person still go through', async () => {
  const w = await world();
  const token = await wangLink(w);
  const people = await senders(w, 11);
  for (const u of people.slice(0, 10)) await w.rpc(u, 'send_friend_request', 'link', token);
  const qr = (await w.rpc(ids.wang, 'create_qr_token')).token;
  assert.equal((await w.rpc(people[10], 'send_friend_request', 'qr', qr)).result, 'sent');
});

test('sending twice through the same link does not use two slots', async () => {
  const w = await world();
  const token = await wangLink(w);
  await w.rpc(ids.me, 'send_friend_request', 'link', token);
  await w.rpc(ids.me, 'send_friend_request', 'link', token);
  const [{ received }] = await w.sql('select received from public.friend_link_inbox');
  assert.equal(received, 1);
  assert.equal((await w.rpc(ids.wang, 'get_friend_requests')).length, 1);
});

test('a declined sender cooling off: still "sent", hidden from her, no slot used', async () => {
  const w = await world();
  const token = await wangLink(w);
  await w.rpc(ids.me, 'send_friend_request', 'link', token);
  const inc = await w.rpc(ids.wang, 'get_friend_requests');
  await w.rpc(ids.wang, 'respond_friend_request', inc[0].id, 'decline');
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'link', token)).result, 'sent');
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  const [{ received }] = await w.sql('select received from public.friend_link_inbox');
  assert.equal(received, 1);
});

// ── 直接打 API ──────────────────────────────────────────────────────

test('the tables are closed to the app and the RPCs to anonymous callers', async () => {
  const w = await world();
  await wangLink(w);
  for (const t of ['friend_share_links', 'friend_link_inbox']) {
    await assert.rejects(w.as(ids.me, `select * from public.${t}`), /permission denied/);
    await assert.rejects(w.as(ids.me, `delete from public.${t}`), /permission denied/);
  }
  await assert.rejects(
    w.as(ids.me, "update public.friend_share_links set expires_at = now() + interval '99 years'"),
    /permission denied/,
  );
  await assert.rejects(
    w.as(ids.me, "select public.friends_share_link_target($1, 'x')", [ids.me]),
    /permission denied/,
  );
  for (const fn of ['create_share_link()', 'get_share_link()', 'disable_share_link()']) {
    await assert.rejects(w.as(null, `select public.${fn}`, [], 'anon'), /permission denied/);
  }
  await assert.rejects(
    w.as(null, "select public.preview_by_share_link('x')", [], 'anon'),
    /permission denied/,
  );
  // 沒登入（auth.uid() 是空的）也打不通。
  assert.equal(await w.rpcErr(null, 'create_share_link'), 'not_signed_in');
});

test('the per-person rate limit also covers the link calls', async () => {
  const w = await world();
  const token = await wangLink(w);
  // 不補桶：連打預覽，桶見底就 rate_limited。
  await w.db.exec('delete from public.friend_rate_buckets');
  await w.db.exec('set role authenticated');
  await w.db.query("select set_config('request.jwt.claim.sub', $1, false)", [ids.me]);
  let limited = false;
  try {
    for (let i = 0; i < 60; i++) {
      await w.db.query('select public.preview_by_share_link($1)', [token]);
    }
  } catch (e) {
    limited = e.message === 'rate_limited';
  } finally {
    await w.db.exec('reset role');
  }
  assert.equal(limited, true);
});
