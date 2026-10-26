// supabase/tests/friends_rpc_test.mjs
//
// Runs supabase/migrations/*_friends.sql in PGlite (PostgreSQL 17 compiled to
// WASM) on top of supabase_stubs.sql, then checks the RPCs and RLS against the
// friends spec §10 — the same cases as test/friends/fake_friends_repository_test.dart.
//
//   cd supabase/tests && npm install && npm test
//
// PGlite is one connection, so the concurrency cases in §10 (two people
// asking each other at the same instant, unfriending during a locked steal)
// are not covered here; run those on a Supabase branch.
//
// Time does not move: a case that needs "7 days later" rewrites the stored
// timestamps as the table owner instead.

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
  .filter((f) => f.endsWith('.sql') && f.includes('friends'))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const ids = {
  me: '00000000-0000-4000-8000-000000000001',
  wang: '00000000-0000-4000-8000-000000000002',
  chen: '00000000-0000-4000-8000-000000000003',
  lin: '00000000-0000-4000-8000-000000000004',
  tsai: '00000000-0000-4000-8000-000000000005',
};

const uid = (n) => `00000000-0000-4000-9000-${String(n).padStart(12, '0')}`;

class World {
  constructor(db) {
    this.db = db;
    // Time does not move in PGlite, so the per-user rate limit never refills.
    // Every call starts with a full bucket unless a test switches this on.
    this.throttle = false;
  }

  /** Runs [sql] as a signed-in user (role authenticated, RLS on). */
  async as(user, sql, params = []) {
    if (!this.throttle) await this.db.exec('delete from public.friend_rate_buckets');
    await this.db.exec('set role authenticated');
    await this.db.query("select set_config('request.jwt.claim.sub', $1, false)", [
      user ?? '',
    ]);
    try {
      return await this.db.query(sql, params);
    } finally {
      await this.db.exec('reset role');
      await this.db.query("select set_config('request.jwt.claim.sub', '', false)");
    }
  }

  /** Calls public.fn(...args) as [user] and returns its value. */
  async rpc(user, fn, ...args) {
    const ph = args.map((_, i) => `$${i + 1}`).join(', ');
    const res = await this.as(user, `select public.${fn}(${ph}) as r`, args);
    return res.rows[0].r;
  }

  /** Expects the call to fail with [code], raised or returned as {error}. */
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

  /** As the table owner (bypasses RLS) — seeding and time travel. */
  async sql(sql, params = []) {
    return (await this.db.query(sql, params)).rows;
  }

  async addUser(user, nickname, code) {
    await this.sql('insert into auth.users (id) values ($1)', [user]);
    await this.rpc(user, 'get_my_profile');
    // Seeded people are not brand-new accounts (reports need 3 days).
    await this.sql("update public.profiles set created_at = now() - interval '7 days' where user_id = $1", [user]);
    if (nickname) await this.rpc(user, 'update_profile', nickname, null, null);
    if (code) {
      await this.sql('update public.profiles set friend_code = $2 where user_id = $1', [
        user,
        code,
      ]);
    }
  }

  async addOrg(id, name, code, kind = 'community_center') {
    await this.sql(
      'insert into public.orgs (id, name, kind, join_code) values ($1, $2, $3, $4)',
      [id, name, kind, code],
    );
  }

  async addMember(org, user) {
    await this.sql('insert into public.org_members (org_id, user_id) values ($1, $2)', [
      org,
      user,
    ]);
  }

  async addFriendship(a, b) {
    await this.sql(
      `insert into public.friendships (user_low, user_high, source)
       values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')`,
      [a, b],
    );
  }

  async areFriends(a, b) {
    return (await this.sql('select public.are_friends($1, $2) as r', [a, b]))[0].r;
  }

  async uploadAvatar(user, name) {
    await this.as(
      user,
      "insert into storage.objects (bucket_id, name) values ('avatars', $1)",
      [name],
    );
  }
}

const ORG = '00000000-0000-4000-a000-000000000001';

/** Me plus 王阿姨 (31415926) and 陳伯伯 (27182818), sharing an org. */
async function world() {
  const db = new PGlite();
  await db.exec(stubs);
  await db.exec(migration);
  const w = new World(db);
  await w.addUser(ids.me, '我自己', '11223344');
  await w.addUser(ids.wang, '王阿姨', '31415926');
  await w.addUser(ids.chen, '陳伯伯', '27182818');
  await w.addOrg(ORG, '三峽示範據點', '52013140');
  for (const u of [ids.me, ids.wang, ids.chen]) await w.addMember(ORG, u);
  return w;
}

// ── adding by code ─────────────────────────────────────────────────────

test('a code previews the person without their photo', async () => {
  const w = await world();
  await w.uploadAvatar(ids.wang, `${ids.wang}/1760000000000.jpg`);
  await w.rpc(ids.wang, 'set_avatar_photo', `${ids.wang}/1760000000000.jpg`);
  const p = await w.rpc(ids.me, 'preview_by_code', '31415926');
  assert.equal(p.nickname, '王阿姨');
  assert.equal(p.avatar_path, null);
});

test('sending needs their consent: nothing changes until they accept', async () => {
  const w = await world();
  await w.rpc(ids.me, 'preview_by_code', '31415926');
  const r = await w.rpc(ids.me, 'send_friend_request', 'code', '31415926');
  assert.equal(r.result, 'sent');
  assert.equal(await w.areFriends(ids.me, ids.wang), false);
  const out = await w.rpc(ids.me, 'get_friend_requests');
  assert.equal(out.length, 1);
  assert.equal(out[0].incoming, false);
  assert.equal(out[0].other.user_id, ids.wang);
  const inc = await w.rpc(ids.wang, 'get_friend_requests');
  assert.equal(inc[0].incoming, true);
  await w.rpc(ids.wang, 'respond_friend_request', inc[0].id, 'accept');
  assert.equal(await w.areFriends(ids.me, ids.wang), true);
  assert.equal(await w.areFriends(ids.wang, ids.me), true);
});

test('asking someone who already asked me makes us friends at once', async () => {
  const w = await world();
  await w.rpc(ids.wang, 'send_friend_request', 'code', '11223344');
  const r = await w.rpc(ids.me, 'send_friend_request', 'code', '31415926');
  assert.equal(r.result, 'became_friends');
  assert.equal(await w.areFriends(ids.me, ids.wang), true);
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  assert.equal((await w.sql('select public.friend_count($1) as n', [ids.me]))[0].n, 1);
  assert.equal((await w.sql('select count(*)::int as n from public.friendships'))[0].n, 1);
  const pending = await w.sql(
    "select count(*)::int as n from public.friend_requests where status = 'pending'",
  );
  assert.equal(pending[0].n, 0);
});

test('20 lookups a day, then refused; the next day the budget is back', async () => {
  const w = await world();
  for (let i = 0; i < 20; i++) await w.rpc(ids.me, 'preview_by_code', '31415926');
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', '31415926'), 'limit_reached');
  // Org codes share the same budget.
  assert.equal(await w.rpcErr(ids.me, 'preview_org', '52013140'), 'limit_reached');
  await w.sql("update public.friend_daily_limits set day = day - 1");
  assert.equal((await w.rpc(ids.me, 'preview_by_code', '31415926')).nickname, '王阿姨');
});

test('5 wrong codes in a row lock lookups for 10 minutes', async () => {
  const w = await world();
  for (let i = 0; i < 5; i++) {
    assert.equal(await w.rpcErr(ids.me, 'preview_by_code', '99999999'), 'not_found');
  }
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', '31415926'), 'locked');
  const [row] = await w.sql('select locked_until - now() as left from public.friend_daily_limits');
  assert.ok(row.left, 'locked_until is set');
  await w.sql("update public.friend_daily_limits set locked_until = now() - interval '1 second'");
  assert.equal((await w.rpc(ids.me, 'preview_by_code', '31415926')).nickname, '王阿姨');
});

test('a lock set just before midnight still holds after it', async () => {
  const w = await world();
  for (let i = 0; i < 5; i++) await w.rpcErr(ids.me, 'preview_by_code', '99999999');
  await w.sql('update public.friend_daily_limits set day = day - 1');
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', '31415926'), 'locked');
});

test('sending to a code that was never previewed spends the budget', async () => {
  const w = await world();
  for (let i = 0; i < 5; i++) {
    assert.equal(
      await w.rpcErr(ids.me, 'send_friend_request', 'code', `1234567${i}`),
      'not_found',
    );
  }
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'code', '31415926'), 'locked');
});

test('a previewed code can be sent without spending another lookup', async () => {
  const w = await world();
  for (let i = 0; i < 19; i++) await w.rpc(ids.me, 'preview_by_code', '27182818');
  await w.rpc(ids.me, 'preview_by_code', '31415926'); // 20th
  const r = await w.rpc(ids.me, 'send_friend_request', 'code', '31415926');
  assert.equal(r.result, 'sent');
});

test('someone who never set up friends cannot be found by code', async () => {
  const w = await world();
  await w.sql('insert into auth.users (id) values ($1)', [ids.lin]);
  // Reading the red dot (the plaza and the games hub do) creates nothing…
  assert.deepEqual(await w.rpc(ids.lin, 'get_friend_requests'), []);
  assert.deepEqual(await w.rpc(ids.lin, 'get_friends'), []);
  const [none] = await w.sql('select count(*)::int as n from public.profiles where user_id = $1', [
    ids.lin,
  ]);
  assert.equal(none.n, 0);
  // …and a profile without a name (friends opened, setup not finished) is not
  // reachable by its code.
  await w.rpc(ids.lin, 'get_my_profile');
  const [{ friend_code: code }] = await w.sql(
    'select friend_code from public.profiles where user_id = $1',
    [ids.lin],
  );
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', code), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'code', code), 'not_found');
  await w.rpc(ids.lin, 'update_profile', '林阿嬤', null, null);
  assert.equal((await w.rpc(ids.me, 'preview_by_code', code)).nickname, '林阿嬤');
});

test('a rotated code stops working immediately', async () => {
  const w = await world();
  const before = (await w.rpc(ids.wang, 'get_my_profile')).friend_code;
  const after = (await w.rpc(ids.wang, 'rotate_friend_code')).friend_code;
  assert.notEqual(after, before);
  assert.match(after, /^[1-9]\d{7}$/);
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', before), 'not_found');
  assert.equal((await w.rpc(ids.me, 'preview_by_code', after)).nickname, '王阿姨');
});

test('a malformed code is not found and counts as a miss', async () => {
  const w = await world();
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', '01234567'), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', 'abc'), 'not_found');
  const [r] = await w.sql('select failed_lookups_streak as s from public.friend_daily_limits');
  assert.equal(r.s, 2);
});

// ── adding by QR ───────────────────────────────────────────────────────

test("someone else's token works for 5 minutes, then reads as expired", async () => {
  const w = await world();
  const { token, expires_at } = await w.rpc(ids.wang, 'create_qr_token');
  assert.match(token, /^[0-9a-f]{32}$/);
  const ttl = (await w.sql('select ($1::timestamptz - now()) as d', [expires_at]))[0].d;
  assert.ok(ttl, 'expires_at returned');
  assert.equal((await w.rpc(ids.me, 'preview_by_qr', token)).nickname, '王阿姨');
  // Several people can scan the same token.
  assert.equal((await w.rpc(ids.chen, 'preview_by_qr', token)).nickname, '王阿姨');
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'qr', token)).result, 'sent');
  // Past the 60 s grace a preview no longer helps either (see the grace tests).
  await w.sql("update public.qr_tokens set expires_at = now() - interval '2 minutes'");
  assert.equal(await w.rpcErr(ids.chen, 'preview_by_qr', token), 'qr_expired');
  assert.equal(await w.rpcErr(ids.chen, 'send_friend_request', 'qr', token), 'qr_expired');
});

test('my own token and unknown tokens are not found', async () => {
  const w = await world();
  const { token } = await w.rpc(ids.me, 'create_qr_token');
  assert.equal(await w.rpcErr(ids.me, 'preview_by_qr', token), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'preview_by_qr', 'nope'), 'not_found');
});

test('a token previewed before it expired can still be sent for 60 s', async () => {
  const w = await world();
  const { token } = await w.rpc(ids.wang, 'create_qr_token');
  assert.equal((await w.rpc(ids.me, 'preview_by_qr', token)).nickname, '王阿姨');
  await w.sql("update public.qr_tokens set expires_at = now() - interval '30 seconds'");
  // I was reading her name when it ran out: it still goes through.
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'qr', token)).result, 'sent');
  // 陳伯伯 never previewed it, and previewing now is too late.
  assert.equal(await w.rpcErr(ids.chen, 'send_friend_request', 'qr', token), 'qr_expired');
  assert.equal(await w.rpcErr(ids.chen, 'preview_by_qr', token), 'qr_expired');
});

test('the QR grace ends 60 s after the token expired', async () => {
  const w = await world();
  const { token } = await w.rpc(ids.wang, 'create_qr_token');
  await w.rpc(ids.me, 'preview_by_qr', token);
  await w.sql("update public.qr_tokens set expires_at = now() - interval '61 seconds'");
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'qr', token), 'qr_expired');
});

test("a blocker's token looks unknown, not expired", async () => {
  const w = await world();
  const { token } = await w.rpc(ids.wang, 'create_qr_token');
  await w.rpc(ids.wang, 'block_user', ids.me);
  await w.sql("update public.qr_tokens set expires_at = now() - interval '1 hour'");
  assert.equal(await w.rpcErr(ids.me, 'preview_by_qr', token), 'not_found');
});

// ── requests ───────────────────────────────────────────────────────────

test('declining is silent: the sender still sees it as waiting', async () => {
  const w = await world();
  const sent = await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me);
  assert.equal(sent.result, 'sent');
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  await w.rpc(ids.me, 'respond_friend_request', r.id, 'decline');
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
  assert.equal(await w.areFriends(ids.me, ids.wang), false);
  // 王阿姨 still sees it waiting, and asking again is quietly a no-op.
  const theirs = await w.rpc(ids.wang, 'get_friend_requests');
  assert.equal(theirs.length, 1);
  assert.equal(theirs[0].id, r.id);
  assert.equal(theirs[0].incoming, false);
  const again = await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me);
  assert.equal(again.result, 'sent');
  assert.equal((await w.rpc(ids.wang, 'get_friend_requests'))[0].id, r.id);
  // The org list keeps showing "waiting" too.
  const members = await w.rpc(ids.wang, 'get_org_members', ORG);
  assert.equal(members.find((m) => m.user_id === ids.me).status, 'pending_out');
});

/** 王阿姨 asks me through the org and I quietly decline. */
async function declinedByMe(w) {
  await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me);
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  await w.rpc(ids.me, 'respond_friend_request', r.id, 'decline');
  return r;
}

/** Asking again inside the cooldown looks exactly like a normal send to the
 * sender — `sent`, a 7-day request waiting on her side — and nothing reaches
 * me. Returns the request as she sees it. */
async function assertSilentResend(w) {
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
  const theirs = await w.rpc(ids.wang, 'get_friend_requests');
  assert.equal(theirs.length, 1);
  assert.equal(theirs[0].incoming, false);
  assert.equal(theirs[0].other.user_id, ids.me);
  assert.equal(theirs[0].org_name, '三峽示範據點');
  const [{ d }] = await w.sql(
    'select extract(epoch from expires_at - created_at)::int as d from public.friend_requests where id = $1',
    [theirs[0].id],
  );
  assert.equal(d, 7 * 24 * 3600);
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
  const mine = await w.rpc(ids.me, 'get_org_members', ORG);
  assert.equal(mine.find((m) => m.user_id === ids.wang).status, 'none');
  const hers = await w.rpc(ids.wang, 'get_org_members', ORG);
  assert.equal(hers.find((m) => m.user_id === ids.me).status, 'pending_out');
  return theirs[0];
}

test('after a declined request expires, asking again is quietly held for 30 days', async () => {
  const w = await world();
  await declinedByMe(w);
  await w.sql("update public.friend_requests set expires_at = now() - interval '1 second'");
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  // No "cooldown" answer: that would tell her I said no.
  const held = await assertSilentResend(w);
  // Asking once more is the usual quiet no-op on the same request.
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
  assert.equal((await w.rpc(ids.wang, 'get_friend_requests'))[0].id, held.id);
  // It never reached me, so I cannot accept it.
  assert.equal(await w.rpcErr(ids.me, 'respond_friend_request', held.id, 'accept'), 'not_found');
  // Once the held one has run out and the 30 days are over, a real one goes out.
  await w.sql(
    `update public.friend_requests
     set expires_at = now() - interval '1 second',
         responded_at = now() - interval '30 days 1 second'`,
  );
  await w.sql("update public.friend_cooldowns set until = now() - interval '1 second'");
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
  assert.equal((await w.rpc(ids.me, 'get_friend_requests')).length, 1);
});

test('cancelling a declined request and asking again does not reach me either', async () => {
  const w = await world();
  const r = await declinedByMe(w);
  await w.rpc(ids.wang, 'cancel_friend_request', r.id);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  const held = await assertSilentResend(w);
  // She can withdraw the held one like any other, and asking again is held too.
  await w.rpc(ids.wang, 'cancel_friend_request', held.id);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  await assertSilentResend(w);
});

test('a held request counts toward the 20 waiting, like a real one', async () => {
  const w = await world();
  await declinedByMe(w);
  await w.sql("update public.friend_requests set expires_at = now() - interval '1 second'");
  for (let i = 0; i < 19; i++) {
    await w.addUser(uid(i), `朋友${i}`);
    await w.addMember(ORG, uid(i));
    await w.rpc(ids.wang, 'send_friend_request', 'org', uid(i));
  }
  await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me); // held, the 20th
  assert.equal(
    await w.rpcErr(ids.wang, 'send_friend_request', 'org', ids.chen),
    'pending_limit',
  );
});

test('if I ask her while hers is held, we become friends and nothing is left waiting', async () => {
  const w = await world();
  await declinedByMe(w);
  await w.sql("update public.friend_requests set expires_at = now() - interval '1 second'");
  await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me); // held
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'org', ids.wang)).result, 'sent');
  const [mine] = (await w.rpc(ids.wang, 'get_friend_requests')).filter((r) => r.incoming);
  await w.rpc(ids.wang, 'respond_friend_request', mine.id, 'accept');
  assert.equal(await w.areFriends(ids.me, ids.wang), true);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
});

test('becoming friends closes a quietly declined request the other way', async () => {
  const w = await world();
  await declinedByMe(w);
  // 王阿姨 still sees hers as waiting; then I ask her myself and she says yes.
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'code', '31415926')).result, 'sent');
  const [mine] = (await w.rpc(ids.wang, 'get_friend_requests')).filter((r) => r.incoming);
  await w.rpc(ids.wang, 'respond_friend_request', mine.id, 'accept');
  assert.equal(await w.areFriends(ids.me, ids.wang), true);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  const open = await w.sql(
    "select count(*)::int as n from public.friend_requests where status in ('pending', 'declined')",
  );
  assert.equal(open[0].n, 0);
});

test('a cancelled request can be sent again', async () => {
  const w = await world();
  await w.rpc(ids.me, 'send_friend_request', 'org', ids.wang);
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  await w.rpc(ids.me, 'cancel_friend_request', r.id);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'org', ids.wang)).result, 'sent');
  assert.equal(await w.rpcErr(ids.chen, 'cancel_friend_request', r.id), 'not_found');
});

test('requests expire after 7 days', async () => {
  const w = await world();
  await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me);
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  const [{ d }] = await w.sql(
    "select extract(epoch from expires_at - created_at)::int as d from public.friend_requests",
  );
  assert.equal(d, 7 * 24 * 3600);
  await w.sql("update public.friend_requests set expires_at = now() - interval '1 second'");
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
  assert.equal(await w.rpcErr(ids.me, 'respond_friend_request', r.id, 'accept'), 'not_found');
  const [{ status }] = await w.sql('select status from public.friend_requests');
  assert.equal(status, 'expired');
  // Expired is not a decline: no cooldown.
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
});

test('at most 20 outgoing requests waiting at once', async () => {
  const w = await world();
  for (let i = 0; i < 20; i++) {
    await w.addUser(uid(i), `朋友${i}`);
    await w.addMember(ORG, uid(i));
    assert.equal((await w.rpc(ids.me, 'send_friend_request', 'org', uid(i))).result, 'sent');
  }
  assert.equal(
    await w.rpcErr(ids.me, 'send_friend_request', 'org', ids.wang),
    'pending_limit',
  );
});

test('100 friends is the cap, on either side', async () => {
  const w = await world();
  for (let i = 0; i < 100; i++) {
    await w.sql('insert into auth.users (id) values ($1)', [uid(i)]);
    await w.rpc(uid(i), 'get_my_profile');
    await w.addFriendship(ids.me, uid(i));
  }
  assert.equal(
    await w.rpcErr(ids.me, 'send_friend_request', 'org', ids.wang),
    'friend_limit',
  );
  // 王阿姨 can ask me, but I cannot accept while full.
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  assert.equal(await w.rpcErr(ids.me, 'respond_friend_request', r.id, 'accept'), 'friend_limit');
});

test('when the other person is full, the answer says it is them', async () => {
  const w = await world();
  // 王阿姨 asks me, then fills up before I answer.
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
  for (let i = 0; i < 100; i++) {
    await w.sql('insert into auth.users (id) values ($1)', [uid(i)]);
    await w.rpc(uid(i), 'get_my_profile');
    await w.addFriendship(ids.wang, uid(i));
  }
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  assert.equal(
    await w.rpcErr(ids.me, 'respond_friend_request', r.id, 'accept'),
    'other_friend_limit',
  );
  // Asking her back (which would accept hers) says the same.
  assert.equal(
    await w.rpcErr(ids.me, 'send_friend_request', 'org', ids.wang),
    'other_friend_limit',
  );
  assert.equal(await w.areFriends(ids.me, ids.wang), false);
});

test('respond only works for the recipient', async () => {
  const w = await world();
  await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me);
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  assert.equal(await w.rpcErr(ids.chen, 'respond_friend_request', r.id, 'accept'), 'not_found');
  assert.equal(await w.rpcErr(ids.wang, 'respond_friend_request', r.id, 'accept'), 'not_found');
});

// ── blocking ───────────────────────────────────────────────────────────

test('a blocked person cannot tell they are blocked', async () => {
  const w = await world();
  await w.addFriendship(ids.me, ids.wang);
  await w.rpc(ids.wang, 'block_user', ids.me);
  assert.equal(await w.areFriends(ids.me, ids.wang), false);
  assert.equal(await w.areFriends(ids.wang, ids.me), false);
  assert.equal((await w.rpc(ids.me, 'is_my_friend', ids.wang)), false);
  assert.deepEqual(await w.rpc(ids.me, 'get_friends'), []);
  // Her code reads exactly like a wrong number…
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', '31415926'), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'code', '31415926'), 'not_found');
  // …she is gone from the shared org list, and I from hers…
  const mine = await w.rpc(ids.me, 'get_org_members', ORG);
  assert.deepEqual(mine.map((m) => m.user_id), [ids.chen]);
  const hers = await w.rpc(ids.wang, 'get_org_members', ORG);
  assert.deepEqual(hers.map((m) => m.user_id), [ids.chen]);
  // …asking through the org fails the same way…
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'org', ids.wang), 'not_found');
  // …and I cannot see that she blocked me, even reading the table directly.
  assert.deepEqual(await w.rpc(ids.me, 'get_blocked'), []);
  assert.equal((await w.as(ids.me, 'select * from public.blocks')).rows.length, 0);
  assert.equal((await w.as(ids.wang, 'select * from public.blocks')).rows.length, 1);
});

test('blocking removes the friendship and pending requests', async () => {
  const w = await world();
  await w.addFriendship(ids.me, ids.wang);
  await w.rpc(ids.chen, 'send_friend_request', 'org', ids.me);
  await w.rpc(ids.me, 'block_user', ids.wang);
  await w.rpc(ids.me, 'block_user', ids.chen);
  assert.deepEqual(await w.rpc(ids.me, 'get_friends'), []);
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
  assert.deepEqual(await w.rpc(ids.chen, 'get_friend_requests'), []);
  const blocked = (await w.rpc(ids.me, 'get_blocked')).map((p) => p.user_id).sort();
  assert.deepEqual(blocked, [ids.wang, ids.chen].sort());
  // Nothing is left waiting, but the history stays (a decline's cooldown must survive a block).
  assert.equal(
    (await w.sql("select count(*)::int as n from public.friend_requests where status = 'pending'"))[0].n,
    0,
  );
});

test('unblocking does not bring the friendship back', async () => {
  const w = await world();
  await w.addFriendship(ids.me, ids.wang);
  await w.rpc(ids.me, 'block_user', ids.wang);
  await w.rpc(ids.me, 'unblock_user', ids.wang);
  assert.equal(await w.areFriends(ids.me, ids.wang), false);
  assert.deepEqual(await w.rpc(ids.me, 'get_blocked'), []);
  assert.equal((await w.rpc(ids.me, 'preview_by_code', '31415926')).nickname, '王阿姨');
});

test('decline-and-block from a request', async () => {
  const w = await world();
  await w.rpc(ids.wang, 'send_friend_request', 'code', '11223344');
  const [r] = await w.rpc(ids.me, 'get_friend_requests');
  await w.rpc(ids.me, 'respond_friend_request', r.id, 'decline_and_block');
  assert.equal((await w.rpc(ids.me, 'get_blocked'))[0].user_id, ids.wang);
  assert.equal(await w.rpcErr(ids.me, 'preview_by_code', '31415926'), 'not_found');
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
});

test('blocked people cannot report or be reported through the block', async () => {
  const w = await world();
  await w.rpc(ids.wang, 'block_user', ids.me);
  assert.equal(
    await w.rpcErr(ids.me, 'report_profile', ids.wang, 'nickname', 'ads'),
    'not_found',
  );
});

// ── orgs ───────────────────────────────────────────────────────────────

test('the list hides people who switched it off, but they still see it', async () => {
  const w = await world();
  await w.addUser(ids.tsai, '蔡阿公');
  await w.rpc(ids.tsai, 'update_profile', null, null, false);
  await w.addMember(ORG, ids.tsai);
  const ids1 = (await w.rpc(ids.me, 'get_org_members', ORG)).map((m) => m.user_id);
  assert.ok(!ids1.includes(ids.tsai));
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'org', ids.tsai), 'not_found');
  // Hidden himself, he can still read the list and ask others.
  assert.equal((await w.rpc(ids.tsai, 'get_org_members', ORG)).length, 3);
  assert.equal((await w.rpc(ids.tsai, 'send_friend_request', 'org', ids.me)).result, 'sent');
});

test('member status: friend, waiting, wants me, none', async () => {
  const w = await world();
  await w.addUser(ids.lin, '林阿嬤');
  await w.addUser(ids.tsai, '蔡阿公');
  await w.addMember(ORG, ids.lin);
  await w.addMember(ORG, ids.tsai);
  await w.addFriendship(ids.me, ids.wang);
  await w.rpc(ids.me, 'send_friend_request', 'org', ids.chen);
  await w.rpc(ids.lin, 'send_friend_request', 'org', ids.me);
  const status = Object.fromEntries(
    (await w.rpc(ids.me, 'get_org_members', ORG)).map((m) => [m.user_id, m.status]),
  );
  assert.deepEqual(status, {
    [ids.wang]: 'friend',
    [ids.chen]: 'pending_out',
    [ids.lin]: 'pending_in',
    [ids.tsai]: 'none',
  });
  const reqs = await w.rpc(ids.me, 'get_friend_requests');
  assert.equal(reqs.find((r) => r.incoming).org_name, '三峽示範據點');
});

test('photos: only friends get the path, never on the org list or requests', async () => {
  const w = await world();
  const path = `${ids.wang}/1760000000000.jpg`;
  await w.uploadAvatar(ids.wang, path);
  await w.rpc(ids.wang, 'set_avatar_photo', path);
  await w.rpc(ids.wang, 'send_friend_request', 'org', ids.chen);
  assert.equal((await w.rpc(ids.chen, 'get_friend_requests'))[0].other.avatar_path, null);
  await w.addFriendship(ids.me, ids.wang);
  const onList = (await w.rpc(ids.me, 'get_org_members', ORG)).find(
    (m) => m.user_id === ids.wang,
  );
  assert.equal(onList.avatar_path, null);
  const [friend] = await w.rpc(ids.me, 'get_friends');
  assert.equal(friend.avatar_path, path);
  assert.equal(friend.relation, 'friend');
});

test('storage: a friend can read the current photo; others and old photos cannot', async () => {
  const w = await world();
  const old = `${ids.wang}/1760000000000.jpg`;
  const cur = `${ids.wang}/1760000000999.jpg`;
  await w.uploadAvatar(ids.wang, old);
  await w.uploadAvatar(ids.wang, cur);
  await w.rpc(ids.wang, 'set_avatar_photo', cur);
  await w.addFriendship(ids.me, ids.wang);
  const read = async (user) =>
    (await w.as(user, 'select name from storage.objects order by name')).rows.map((r) => r.name);
  assert.deepEqual(await read(ids.me), [cur]);
  assert.deepEqual(await read(ids.chen), []);
  assert.deepEqual(await read(ids.wang), [old, cur]);
  await w.rpc(ids.wang, 'block_user', ids.me);
  assert.deepEqual(await read(ids.me), []);
});

test('storage: uploads only into your own folder, 5 a day', async () => {
  const w = await world();
  await assert.rejects(w.uploadAvatar(ids.me, `${ids.wang}/1760000000000.jpg`));
  for (let i = 0; i < 5; i++) await w.uploadAvatar(ids.me, `${ids.me}/176000000000${i}.jpg`);
  await assert.rejects(w.uploadAvatar(ids.me, `${ids.me}/1760000000009.jpg`));
});

test('set_avatar_photo only takes an uploaded file in your own folder', async () => {
  const w = await world();
  assert.equal(
    await w.rpcErr(ids.me, 'set_avatar_photo', `${ids.me}/1760000000000.jpg`),
    'not_found',
  );
  await w.uploadAvatar(ids.wang, `${ids.wang}/1760000000000.jpg`);
  assert.equal(
    await w.rpcErr(ids.me, 'set_avatar_photo', `${ids.wang}/1760000000000.jpg`),
    'not_found',
  );
  await w.uploadAvatar(ids.me, `${ids.me}/1760000000000.jpg`);
  const p = await w.rpc(ids.me, 'set_avatar_photo', `${ids.me}/1760000000000.jpg`);
  assert.equal(p.avatar_path, `${ids.me}/1760000000000.jpg`);
  assert.equal((await w.rpc(ids.me, 'clear_avatar_photo')).avatar_path, null);
  // PNG and WebP keep their own extension; anything else is refused.
  for (const [i, ext] of [[1, 'png'], [2, 'webp']]) {
    const name = `${ids.me}/176000000000${i}.${ext}`;
    await w.uploadAvatar(ids.me, name);
    assert.equal((await w.rpc(ids.me, 'set_avatar_photo', name)).avatar_path, name);
  }
  await w.uploadAvatar(ids.me, `${ids.me}/1760000000003.gif`);
  assert.equal(
    await w.rpcErr(ids.me, 'set_avatar_photo', `${ids.me}/1760000000003.gif`),
    'not_found',
  );
  const [bucket] = await w.sql("select allowed_mime_types from storage.buckets where id = 'avatars'");
  assert.deepEqual([...bucket.allowed_mime_types].sort(), ['image/jpeg', 'image/png', 'image/webp']);
});

test('at most 3 orgs; leaving keeps the friends', async () => {
  const w = await world();
  const org = (n) => `00000000-0000-4000-a000-00000000000${n}`;
  await w.addOrg(org(2), 'B', '60000002', 'day_care');
  await w.addOrg(org(3), 'C', '60000003', 'other');
  await w.addOrg(org(4), 'D', '60000004', 'other');
  await w.addFriendship(ids.me, ids.wang);
  const joined = await w.rpc(ids.me, 'join_org', '60000002');
  assert.deepEqual(joined, { id: org(2), name: 'B', kind: 'day_care' });
  await w.rpc(ids.me, 'join_org', '60000003');
  assert.equal(await w.rpcErr(ids.me, 'join_org', '60000004'), 'org_limit');
  await w.rpc(ids.me, 'leave_org', ORG);
  await w.rpc(ids.me, 'join_org', '60000004');
  assert.equal(await w.areFriends(ids.me, ids.wang), true);
  const mine = (await w.rpc(ids.me, 'get_my_orgs')).map((o) => o.name);
  assert.deepEqual(mine, ['B', 'C', 'D']);
  // A deactivated org disappears and frees a slot.
  await w.sql('update public.orgs set is_active = false where id = $1', [org(2)]);
  assert.equal((await w.rpc(ids.me, 'get_my_orgs')).length, 2);
  assert.equal(await w.rpcErr(ids.me, 'get_org_members', org(2)), 'not_found');
  assert.equal(await w.rpcErr(ids.me, 'preview_org', '60000002'), 'not_found');
  await w.rpc(ids.me, 'join_org', '52013140');
});

test('only members can read an org list', async () => {
  const w = await world();
  const org2 = '00000000-0000-4000-a000-000000000002';
  await w.addOrg(org2, 'B', '60000002', 'day_care');
  assert.equal(await w.rpcErr(ids.me, 'get_org_members', org2), 'not_found');
  const p = await w.rpc(ids.me, 'preview_org', '60000002');
  assert.equal(p.name, 'B');
});

// ── profile ────────────────────────────────────────────────────────────

test('first name is free; then 3 changes a day', async () => {
  const w = await world();
  await w.sql('insert into auth.users (id) values ($1)', [ids.lin]);
  const fresh = await w.rpc(ids.lin, 'get_my_profile');
  assert.equal(fresh.nickname, null);
  assert.match(fresh.friend_code, /^[1-9]\d{7}$/);
  assert.equal(fresh.show_in_org_list, true);
  await w.rpc(ids.lin, 'update_profile', '林阿嬤', null, null);
  for (const name of ['阿嬤一', '阿嬤二', '阿嬤三']) {
    await w.rpc(ids.lin, 'update_profile', name, null, null);
  }
  assert.equal(
    await w.rpcErr(ids.lin, 'update_profile', '阿嬤四', null, null),
    'nickname_change_limit',
  );
  // Setting the same name again, or other fields, does not count.
  await w.rpc(ids.lin, 'update_profile', '阿嬤三', 4, false);
  await w.sql('update public.profiles set nickname_changed_on = nickname_changed_on - 1');
  await w.rpc(ids.lin, 'update_profile', '阿嬤四', null, null);
});

test('invalid nicknames are refused; surrounding spaces are trimmed', async () => {
  const w = await world();
  for (const bad of ['王', '！！！', '一二三四五六七八九', '  ', '王\n阿姨', '★★']) {
    assert.equal(await w.rpcErr(ids.me, 'update_profile', bad, null, null), 'nickname_invalid');
  }
  for (const good of ['小美', 'Amy', '陳伯伯88', 'ㄚ寶', 'さくら']) {
    assert.equal((await w.rpc(ids.chen, 'update_profile', good, null, null)).nickname, good);
    await w.sql('update public.profiles set nickname_changed_today = 0');
  }
  assert.equal((await w.rpc(ids.wang, 'update_profile', '　王阿姨 ', null, null)).nickname, '王阿姨');
  assert.equal(await w.rpcErr(ids.me, 'update_profile', null, 13, null), 'not_found');
});

test('a removed nickname becomes 銀足朋友 and asks for a new one', async () => {
  const w = await world();
  // 動域 takes it down from the dashboard.
  await w.sql(
    "update public.profiles set nickname = '銀足朋友', nickname_removed = true where user_id = $1",
    [ids.me],
  );
  const me = await w.rpc(ids.me, 'get_my_profile');
  assert.equal(me.nickname, '銀足朋友');
  assert.equal(me.nickname_removed, true);
  for (const n of ['一號', '二號', '三號']) await w.rpc(ids.me, 'update_profile', n, null, null);
  await w.sql(
    "update public.profiles set nickname = '銀足朋友', nickname_removed = true where user_id = $1",
    [ids.me],
  );
  // Picking the replacement does not use up a daily change.
  await w.rpc(ids.me, 'update_profile', '新名字', null, null);
  assert.equal((await w.rpc(ids.me, 'get_my_profile')).nickname_removed, false);
});

test('a third photo removal bans uploads for 30 days', async () => {
  const w = await world();
  await w.sql(
    `update public.profiles
     set avatar_path = null, avatar_removed = true, avatar_removed_count = 3,
         avatar_upload_banned_until = now() + interval '30 days'
     where user_id = $1`,
    [ids.me],
  );
  const me = await w.rpc(ids.me, 'get_my_profile');
  assert.equal(me.avatar_removed, true);
  assert.ok(me.avatar_upload_banned_until);
  await assert.rejects(w.uploadAvatar(ids.me, `${ids.me}/1760000000000.jpg`));
  await w.sql("insert into storage.objects (bucket_id, name) values ('avatars', $1)", [
    `${ids.me}/1760000000000.jpg`,
  ]);
  assert.equal(
    await w.rpcErr(ids.me, 'set_avatar_photo', `${ids.me}/1760000000000.jpg`),
    'upload_banned',
  );
  await w.rpc(ids.me, 'acknowledge_removals');
  assert.equal((await w.rpc(ids.me, 'get_my_profile')).avatar_removed, false);
  await w.sql("update public.profiles set avatar_upload_banned_until = now() - interval '1 minute'");
  await w.uploadAvatar(ids.me, `${ids.me}/1760000000001.jpg`);
  await w.rpc(ids.me, 'set_avatar_photo', `${ids.me}/1760000000001.jpg`);
});

test('reports are recorded with a snapshot, 10 a day', async () => {
  const w = await world();
  await w.addFriendship(ids.me, ids.wang);
  for (let i = 0; i < 10; i++) {
    await w.rpc(ids.me, 'report_profile', ids.wang, 'nickname', 'ads');
  }
  assert.equal(
    await w.rpcErr(ids.me, 'report_profile', ids.wang, 'photo', 'other'),
    'limit_reached',
  );
  // The same person reporting the same thing again is kept as one open report.
  const rows = await w.sql('select reporter, target_user, snapshot from public.profile_reports');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].snapshot, '王阿姨');
  assert.equal(rows[0].reporter, ids.me);
  assert.equal(await w.rpcErr(ids.me, 'report_profile', ids.me, 'photo', 'other'), 'not_found');
});

test('friends are listed by latest interaction, then newest', async () => {
  const w = await world();
  await w.addUser(ids.lin, '林阿嬤');
  await w.sql(
    `insert into public.friendships (user_low, user_high, source, created_at, last_interaction_at)
     select least($1::uuid, x.id), greatest($1::uuid, x.id), 'code', x.since, x.touched
     from (values
       ($2::uuid, now() - interval '9 days', null::timestamptz),
       ($3::uuid, now() - interval '20 days', null::timestamptz),
       ($4::uuid, now() - interval '1 day', null::timestamptz)
     ) as x(id, since, touched)`,
    [ids.me, ids.wang, ids.chen, ids.lin],
  );
  await w.sql('select public.touch_friendship($1, $2)', [ids.chen, ids.me]);
  const order = (await w.rpc(ids.me, 'get_friends')).map((f) => f.user_id);
  assert.deepEqual(order, [ids.chen, ids.lin, ids.wang]);
});

test('are_friends with lock => true takes the same answer', async () => {
  const w = await world();
  await w.addFriendship(ids.me, ids.wang);
  const [r] = await w.sql('select public.are_friends($1, $2, lock => true) as r', [
    ids.me,
    ids.wang,
  ]);
  assert.equal(r.r, true);
  const [n] = await w.sql('select public.friend_count($1) as n', [ids.wang]);
  assert.equal(n.n, 1);
});

// ── RLS and execute rights ─────────────────────────────────────────────

test('direct reads return only your own rows; writes are refused', async () => {
  const w = await world();
  await w.addFriendship(ids.wang, ids.chen);
  await w.addFriendship(ids.me, ids.wang);
  await w.rpc(ids.chen, 'send_friend_request', 'org', ids.me);
  await w.rpc(ids.me, 'create_qr_token');
  await w.rpc(ids.me, 'preview_by_code', '31415926');
  const count = async (user, table) =>
    (await w.as(user, `select count(*)::int as n from public.${table}`)).rows[0].n;
  assert.equal(await count(ids.me, 'profiles'), 1);
  assert.equal(await count(ids.me, 'friendships'), 1);
  assert.equal(await count(ids.chen, 'friendships'), 1);
  assert.equal(await count(ids.me, 'org_members'), 1);
  for (const table of [
    'friend_requests',
    'qr_tokens',
    'orgs',
    'profile_reports',
    'friend_daily_limits',
  ]) {
    await assert.rejects(count(ids.me, table), /permission denied/, table);
  }
  await assert.rejects(
    w.as(ids.me, "update public.profiles set friend_code = '12345678'"),
    /permission denied/,
  );
  await assert.rejects(
    w.as(ids.me, "insert into public.friendships values ($1, $2, 'code')", [ids.me, ids.chen]),
    /permission denied/,
  );
  await assert.rejects(
    w.as(ids.me, 'delete from public.blocks'),
    /permission denied/,
  );
});

test('the app cannot call the server-only functions', async () => {
  const w = await world();
  for (const call of [
    `public.are_friends('${ids.wang}', '${ids.chen}')`,
    `public.are_friends('${ids.wang}', '${ids.chen}', true)`,
    `public.friend_count('${ids.wang}')`,
    `public.touch_friendship('${ids.wang}', '${ids.chen}')`,
    `public.friends_accept(gen_random_uuid())`,
    `public.friends_new_code()`,
    `public.friends_uid()`,
    `public.friends_qr_grace('${ids.wang}', 'x')`,
  ]) {
    await assert.rejects(w.as(ids.me, `select ${call}`), /permission denied/, call);
  }
  // is_my_friend is the app's (and the garden policies') way in.
  assert.equal(await w.rpc(ids.me, 'is_my_friend', ids.wang), false);
});

test('signed-out callers get nothing', async () => {
  const w = await world();
  assert.equal(await w.rpcErr(null, 'get_my_profile'), 'not_signed_in');
  await w.db.exec('set role anon');
  try {
    await assert.rejects(w.db.query('select public.get_my_profile()'), /permission denied/);
    await assert.rejects(w.db.query('select * from public.profiles'), /permission denied/);
  } finally {
    await w.db.exec('reset role');
  }
});

test('deleting an account removes everything of theirs', async () => {
  const w = await world();
  await w.addFriendship(ids.me, ids.wang);
  await w.rpc(ids.wang, 'send_friend_request', 'org', ids.chen);
  await w.rpc(ids.wang, 'block_user', ids.chen);
  await w.rpc(ids.chen, 'send_friend_request', 'org', ids.me);
  await w.rpc(ids.wang, 'create_qr_token');
  await w.rpc(ids.wang, 'preview_by_code', '11223344');
  await w.rpc(ids.wang, 'report_profile', ids.me, 'nickname', 'other');
  await w.sql('delete from auth.users where id = $1', [ids.wang]);
  for (const [table, col] of [
    ['profiles', 'user_id'],
    ['friendships', 'user_low'],
    ['friendships', 'user_high'],
    ['friend_requests', 'from_user'],
    ['friend_requests', 'to_user'],
    ['blocks', 'blocker'],
    ['qr_tokens', 'user_id'],
    ['org_members', 'user_id'],
    ['friend_daily_limits', 'user_id'],
    ['profile_reports', 'reporter'],
  ]) {
    const [r] = await w.sql(`select count(*)::int as n from public.${table} where ${col} = $1`, [
      ids.wang,
    ]);
    assert.equal(r.n, 0, `${table}.${col}`);
  }
  // A report they filed stays for 動域, without the reporter.
  assert.equal((await w.sql('select count(*)::int as n from public.profile_reports'))[0].n, 1);
  assert.deepEqual(await w.rpc(ids.me, 'get_friends'), []);
});

// ── 2026-10-26 技術長藍隊核查：RPC 濫用（20261026120000_friends_rpc_abuse.sql）────
// 每個案例照核查的情境重演一次。並發的情境（同時 50 個上傳、同時寄 200 人）PGlite
// 只有一條連線演不出來，要在 Supabase 分支多連線打。

test('audit 1: blocking and unblocking does not wash out a decline', async () => {
  const w = await world();
  await declinedByMe(w);
  // She blocks me and unblocks me to wipe the record, then asks again.
  await w.rpc(ids.wang, 'block_user', ids.me);
  await w.rpc(ids.wang, 'unblock_user', ids.me);
  await w.sql("update public.friend_requests set expires_at = now() - interval '1 second'");
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
  // Same when I block and unblock her.
  await w.rpc(ids.me, 'block_user', ids.wang);
  await w.rpc(ids.me, 'unblock_user', ids.wang);
  await w.sql("update public.friend_requests set expires_at = now() - interval '1 second'");
  assert.equal((await w.rpc(ids.wang, 'send_friend_request', 'org', ids.me)).result, 'sent');
  assert.deepEqual(await w.rpc(ids.me, 'get_friend_requests'), []);
});

test('audit 2: opening the QR again reuses the token instead of adding rows', async () => {
  const w = await world();
  const first = await w.rpc(ids.me, 'create_qr_token');
  for (let i = 0; i < 50; i++) {
    assert.equal((await w.rpc(ids.me, 'create_qr_token')).token, first.token);
  }
  const count = async () =>
    (await w.sql('select count(*)::int as n from public.qr_tokens where user_id = $1', [ids.me]))[0].n;
  assert.equal(await count(), 1);
  // Under a minute left: a fresh one, the old one stays for the 60 s grace.
  await w.sql("update public.qr_tokens set expires_at = now() + interval '30 seconds'");
  assert.notEqual((await w.rpc(ids.me, 'create_qr_token')).token, first.token);
  assert.equal(await count(), 2);
  // Long expired ones of mine are gone as soon as I make a new one.
  await w.sql("update public.qr_tokens set expires_at = now() - interval '2 minutes'");
  await w.rpc(ids.me, 'create_qr_token');
  assert.equal(await count(), 1);
});

test('audit 3: cancelling does not give the send back; asking again right after is held', async () => {
  const w = await world();
  await w.rpc(ids.me, 'send_friend_request', 'org', ids.wang);
  const [r] = await w.rpc(ids.wang, 'get_friend_requests');
  await w.rpc(ids.me, 'cancel_friend_request', r.id);
  // Send → cancel → send: she does not get a second request for 24 hours.
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'org', ids.wang)).result, 'sent');
  assert.deepEqual(await w.rpc(ids.wang, 'get_friend_requests'), []);
  // After 24 hours a new one reaches her again.
  const [held] = await w.rpc(ids.me, 'get_friend_requests');
  await w.rpc(ids.me, 'cancel_friend_request', held.id);
  await w.sql("update public.friend_cooldowns set until = now() - interval '1 second'");
  assert.equal((await w.rpc(ids.me, 'send_friend_request', 'org', ids.wang)).result, 'sent');
  assert.equal((await w.rpc(ids.wang, 'get_friend_requests')).length, 1);
});

test('audit 3: at most 30 requests a day, cancelled ones included', async () => {
  const w = await world();
  for (let i = 0; i < 30; i++) {
    await w.addUser(uid(i), `朋友${i}`);
    await w.addMember(ORG, uid(i));
    assert.equal((await w.rpc(ids.me, 'send_friend_request', 'org', uid(i))).result, 'sent');
    const mine = await w.rpc(ids.me, 'get_friend_requests');
    await w.rpc(ids.me, 'cancel_friend_request', mine[0].id);
  }
  assert.equal(await w.rpcErr(ids.me, 'send_friend_request', 'org', ids.chen), 'send_limit');
});

test('audit 4: at most 10 photo files in a folder; old photos can be deleted, the current one cannot', async () => {
  const w = await world();
  for (let i = 0; i < 10; i++) {
    if (i === 5) await w.sql('update public.friend_daily_limits set storage_uploads = 0');
    await w.uploadAvatar(ids.me, `${ids.me}/17600000000${String(i).padStart(2, '0')}.jpg`);
  }
  await w.sql('update public.friend_daily_limits set storage_uploads = 0');
  await assert.rejects(w.uploadAvatar(ids.me, `${ids.me}/1760000000099.jpg`));
  await w.rpc(ids.me, 'set_avatar_photo', `${ids.me}/1760000000000.jpg`);
  const del = async (user, name) =>
    (
      await w.as(
        user,
        "delete from storage.objects where bucket_id = 'avatars' and name = $1 returning name",
        [name],
      )
    ).rows.length;
  assert.equal(await del(ids.me, `${ids.me}/1760000000000.jpg`), 0); // the current photo stays
  assert.equal(await del(ids.wang, `${ids.me}/1760000000001.jpg`), 0); // not hers to delete
  assert.equal(await del(ids.me, `${ids.me}/1760000000001.jpg`), 1);
  // A freed slot can be used again (today's 5 permitting).
  await w.uploadAvatar(ids.me, `${ids.me}/1760000000098.jpg`);
});

test('audit 5: report bombing — one open report per person, new accounts are not filed, 30 a day per target', async () => {
  const w = await world();
  // A brand-new account: the call succeeds but nothing is filed.
  await w.sql('insert into auth.users (id) values ($1)', [uid(900)]);
  await w.rpc(uid(900), 'update_profile', '新來的', null, null);
  await w.rpc(uid(900), 'report_profile', ids.wang, 'nickname', 'ads');
  const filed = async () =>
    (
      await w.sql('select count(*)::int as n from public.profile_reports where target_user = $1', [
        ids.wang,
      ])
    )[0].n;
  assert.equal(await filed(), 0);
  // Forty older accounts pile on: only 30 are kept for the day.
  for (let i = 0; i < 40; i++) {
    await w.addUser(uid(i), `朋友${i}`);
    await w.rpc(uid(i), 'report_profile', ids.wang, 'nickname', 'ads');
  }
  assert.equal(await filed(), 30);
});

test('audit 7: invisible, reversed and look-alike names are refused', async () => {
  const w = await world();
  const bad = [
    '阿\u200B美', // zero-width space
    '阿美\u202E', // right-to-left override
    '\u2066小明\u2069', // isolates
    '銀足朋友', // the name a taken-down nickname turns into
    '銀足小幫手',
    'ＡＤＭＩＮ',
    'Admin',
    '客服小美',
    '系統通知',
    '粗哥',
    '\u3164\u3164', // Hangul filler, looks empty
    '阿美\u0301\u0301\u0301', // stacked combining marks
  ];
  for (const name of bad) {
    assert.equal(
      await w.rpcErr(ids.me, 'update_profile', name, null, null),
      'nickname_invalid',
      JSON.stringify(name),
    );
  }
  // Full-width digits are stored as ordinary ones; an emoji is fine; 粗哥 inside a name is fine.
  assert.equal((await w.rpc(ids.chen, 'update_profile', '阿美🌸', null, null)).nickname, '阿美🌸');
  await w.sql('update public.profiles set nickname_changed_today = 0');
  assert.equal((await w.rpc(ids.chen, 'update_profile', '小明２號', null, null)).nickname, '小明2號');
  await w.sql('update public.profiles set nickname_changed_today = 0');
  assert.equal((await w.rpc(ids.chen, 'update_profile', '粗哥迷', null, null)).nickname, '粗哥迷');
});

test('audit 8: one person cannot hammer the RPCs; others are not affected', async () => {
  const w = await world();
  await w.sql('delete from public.friend_rate_buckets');
  w.throttle = true;
  let refused = 0;
  for (let i = 0; i < 45; i++) {
    try {
      await w.rpc(ids.me, 'get_friends');
    } catch (e) {
      assert.equal(e.message, 'rate_limited');
      refused++;
    }
  }
  assert.ok(refused > 0, 'some calls were refused');
  assert.ok(refused <= 15, `at most 15 of 45 refused, got ${refused}`);
  assert.deepEqual(await w.rpc(ids.wang, 'get_friends'), []);
});
