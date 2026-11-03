// supabase/tests/friend_farm_test.mjs
//
// Runs the friends migrations, game_saves and *_friend_farm.sql in PGlite on top
// of supabase_stubs.sql and plays the friend-farm RPCs the way an attacker would:
// calling the API directly, a stranger, a blocked friend, a save full of garbage,
// the 6th friend of the day, helping twice, claiming twice.
//
//   cd supabase/tests && npm install && npm run test:friend-farm
//
// Every case runs inside `begin; ... rollback;` on one shared database.
// Time does not move inside a transaction (now() is fixed), so a case that needs
// "another day" rewrites the stored day as the table owner instead.

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
  .filter((f) => f.endsWith('.sql') && (f.includes('friends') || f.includes('game_saves') || f.includes('friend_farm')))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const A = uid(1); // me
const B = uid(2); // A's friend
const C = uid(3); // stranger
const D = uid(4); // A's friend who blocked A
const F = (n) => uid(10 + n); // F(1)..F(6): more friends of A

let db;
let throttle = false;

/** A save blob the way cloud_save.js makes it: {"v":1,"keys":{"silversole.farm":"<json text>"}} */
function blob(farm, extraKeys = {}) {
  return JSON.stringify({ v: 1, keys: { 'silversole.farm': JSON.stringify(farm), ...extraKeys } });
}
const plot = (o = {}) => ({ owned: true, crop: null, stage: 0, stageEndsAt: null, harvests: 0, fertilizedStages: [], ...o });
const dryPlot = (o = {}) => plot({ crop: 'bokChoy', stage: 1, dry: true, ...o });
/** Twelve plots; [0] is dry, [1] is growing and wet, [2] is ripe, the rest empty. */
function farm(xp, extra = {}) {
  const plots = [dryPlot(), plot({ crop: 'corn', stage: 2, dry: false, stageEndsAt: 1790000000000 }), plot({ crop: 'radish', stage: 4 })];
  while (plots.length < 12) plots.push(plot({ owned: false }));
  return {
    coins: 12345,
    xp,
    plots,
    inventory: { secret: 99 },
    decor: [
      { uid: 1, decorId: 'bench', x: 3, y: 4 },
      { uid: 2, decorId: 'well', x: null, y: null }, // in the barn: not drawn
    ],
    ...extra,
  };
}
const setSave = (user, data) =>
  db.query(
    `insert into public.game_saves (user_id, rev, data) values ($1, 1, $2)
     on conflict (user_id) do update set data = excluded.data`,
    [user, data],
  );

before(async () => {
  db = new PGlite();
  await db.exec(stubs);
  await db.exec(migrations);
  const people = [A, B, C, D, ...[1, 2, 3, 4, 5, 6].map(F)];
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
  for (let n = 1; n <= 6; n++) await friend(A, F(n));
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

/** Runs [q] as [user] (role authenticated, RLS on). Refills the bucket first unless a test turned [throttle] on. */
async function as(user, q, params = [], role = 'authenticated') {
  if (!throttle) await db.exec('update public.friend_help_limits set tokens = 30');
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

// ── 身分與權限 ──────────────────────────────────────────────────────────

test('signed out: every RPC says signed_out', async () => {
  for (const [fn, args] of [
    ['friend_farm', [B]],
    ['friends_board', []],
    ['friend_water', [B, 0]],
    ['friend_helps_claim', []],
  ]) {
    assert.deepEqual(await rpc(null, fn, ...args), { ok: false, reason: 'signed_out' }, fn);
  }
});

test('anon cannot call anything; nobody can call the helpers or the cleanup', async () => {
  await assert.rejects(as(null, 'select public.friend_farm($1)', [B], 'anon'), /permission denied/);
  await assert.rejects(as(null, 'select public.friends_board()', [], 'anon'), /permission denied/);
  for (const q of [
    'select public.friend_farm_take($1, 1)',
    'select public.friend_farm_parse($1::text)',
    "select public.friend_farm_xp('{}'::jsonb)",
    "select public.friend_farm_view('{}'::jsonb)",
    'select public.friend_farm_level(1)',
    'select public.friend_helps_cleanup()',
  ]) {
    await assert.rejects(as(A, q, q.includes('$1') ? [A] : []), /permission denied/, q);
  }
});

test('the tables are closed: no direct select, insert or update', async () => {
  for (const t of ['friend_helps', 'friend_help_limits']) {
    await assert.rejects(as(A, `select * from public.${t}`), /permission denied/, t);
  }
  await assert.rejects(
    as(A, 'insert into public.friend_helps (helper, helped, day, plot, helper_xp, helped_xp) values ($1, $2, now(), 0, 20, 20)', [A, B]),
    /permission denied/,
  );
});

// ── 看好友農場 ──────────────────────────────────────────────────────────

test('a friend sees only the whitelisted farm fields', async () => {
  await setSave(B, blob(farm(500), { 'silversole.wallet': '{"coins":999}' }));
  const r = await rpc(A, 'friend_farm', B);
  assert.equal(r.ok, true);
  assert.equal(r.friend.user_id, B);
  assert.equal(r.xp, 500);
  assert.equal(r.level, 3);
  assert.equal(r.title, '小農夫');
  assert.equal(r.plots.length, 12);
  assert.deepEqual(r.plots[0], { i: 0, owned: true, crop: 'bokChoy', stage: 1, endsAt: null, dry: true, harvests: 0 });
  assert.equal(r.plots[1].endsAt, 1790000000000);
  assert.equal(r.plots[2].stage, 4);
  assert.deepEqual(r.decor, [{ uid: 1, decorId: 'bench', x: 3, y: 4 }], 'decor in the barn is not returned');
  assert.deepEqual(r.help, { doneToday: false, leftToday: 5, pendingPlots: [] });
  const text = JSON.stringify(r);
  for (const leak of ['12345', 'inventory', 'secret', 'wallet', '999', 'coins']) {
    assert.ok(!text.includes(leak), `must not leak ${leak}`);
  }
});

test('a stranger, a friend who blocked me, myself and a made-up id are refused', async () => {
  await setSave(B, blob(farm(500)));
  await setSave(C, blob(farm(500)));
  await setSave(D, blob(farm(500)));
  for (const who of [C, D, A, uid(99)]) {
    assert.deepEqual(await rpc(A, 'friend_farm', who), { ok: false, reason: 'not_friend' }, who);
  }
  assert.deepEqual(await rpc(null, 'friend_farm', B), { ok: false, reason: 'signed_out' });
  assert.deepEqual(await rpc(A, 'friend_farm', null), { ok: false, reason: 'not_friend' });
});

test('blocking after the fact closes the door both ways', async () => {
  await setSave(B, blob(farm(500)));
  assert.equal((await rpc(A, 'friend_farm', B)).ok, true);
  await sql('insert into public.blocks (blocker, blocked) values ($1, $2)', [B, A]);
  assert.equal((await rpc(A, 'friend_farm', B)).reason, 'not_friend');
  assert.equal((await rpc(A, 'friend_water', B, 0)).reason, 'not_friend');
  assert.equal((await rpc(B, 'friend_farm', A)).reason, 'not_friend');
});

test('no save, or a save that is not a farm, is no_farm; garbage never raises', async () => {
  assert.equal((await rpc(A, 'friend_farm', B)).reason, 'no_farm', 'no save row');
  for (const data of [
    'not json at all',
    '[]',
    '{"v":1}',
    '{"v":1,"keys":[]}',
    '{"v":1,"keys":{"silversole.farm":7}}',
    '{"v":1,"keys":{"silversole.farm":"{{{"}}',
    '{"v":1,"keys":{"silversole.farm":"[1,2]"}}',
  ]) {
    await setSave(B, data);
    assert.equal((await rpc(A, 'friend_farm', B)).reason, 'no_farm', data);
  }
});

test('a hostile farm is clamped field by field', async () => {
  const evil = {
    xp: 'lots',
    plots: [
      'x',
      { owned: 'yes', crop: '<script>alert(1)</script>', stage: 99, stageEndsAt: 1e30, dry: 'true', harvests: -5 },
      { owned: true, crop: 'corn', stage: -3, stageEndsAt: 1790000000000.7, dry: true, harvests: 5000 },
      ...Array.from({ length: 30 }, () => plot()),
    ],
    decor: [
      { uid: 'a', decorId: 'bench', x: 5, y: 6 },
      { uid: 3, decorId: '<img onerror=1>', x: 1, y: 1 },
      { uid: 4, decorId: 'tree', x: 'left', y: 1 },
      { uid: 5, decorId: 'lamp', x: 9999, y: -4 },
      ...Array.from({ length: 300 }, (_, i) => ({ uid: 100 + i, decorId: 'flower', x: 1, y: 1 })),
    ],
  };
  await setSave(B, blob(evil));
  const r = await rpc(A, 'friend_farm', B);
  assert.equal(r.ok, true);
  assert.equal(r.xp, 0, 'non-number xp');
  assert.equal(r.level, 1);
  assert.equal(r.plots.length, 11, 'only the first 12 slots, the non-object skipped');
  const p1 = r.plots.find((p) => p.i === 1);
  assert.deepEqual(p1, { i: 1, owned: false, crop: null, stage: 4, endsAt: null, dry: false, harvests: 0 });
  const p2 = r.plots.find((p) => p.i === 2);
  assert.equal(p2.stage, 0);
  assert.equal(p2.harvests, 1000);
  assert.equal(p2.endsAt, 1790000000000);
  assert.equal(r.decor.length, 200 - 2, 'cap 200 slots; the two bad ones skipped inside it');
  assert.equal(r.decor[0].uid, null);
  assert.equal(r.decor[1].decorId, 'lamp');
  assert.deepEqual([r.decor[1].x, r.decor[1].y], [100, 0]);
  assert.ok(!JSON.stringify(r).includes('script'));
});

test('xp is clamped and level / title follow the thresholds of rules.js', async () => {
  const cases = [
    [0, 1, '菜鳥農夫'], [149, 1, '菜鳥農夫'], [150, 2, '菜鳥農夫'], [400, 3, '小農夫'], [800, 4, '小農夫'],
    [1500, 5, '勤勞農夫'], [2500, 6, '勤勞農夫'], [4000, 7, '老農'], [7000, 8, '老農'],
    [10000, 9, '農莊主人'], [14000, 10, '小鎮名人'], [99999999999, 10, '小鎮名人'], [-5, 1, '菜鳥農夫'],
  ];
  for (const [xp, level, title] of cases) {
    await setSave(B, blob(farm(xp)));
    const r = await rpc(A, 'friend_farm', B);
    assert.equal(r.level, level, `xp ${xp}`);
    assert.equal(r.title, title, `xp ${xp}`);
    assert.ok(r.xp >= 0 && r.xp <= 100000000);
  }
});

test('reading is rate limited by the bucket', async () => {
  await setSave(B, blob(farm(1)));
  throttle = true;
  await sql('delete from public.friend_help_limits');
  let limited = false;
  for (let i = 0; i < 40; i++) {
    const r = await rpc(A, 'friend_farm', B);
    if (r.reason === 'rate_limited') limited = true;
  }
  assert.ok(limited, 'the 31st read in a burst is refused');
});

// ── 排行 ────────────────────────────────────────────────────────────────

test('board: me and my friends, highest first, no blocked friend, no stranger', async () => {
  await setSave(A, blob(farm(300)));
  await setSave(B, blob(farm(2600)));
  await setSave(C, blob(farm(99999)));
  await setSave(D, blob(farm(5000)));
  await setSave(F(1), 'garbage');
  const r = await rpc(A, 'friends_board');
  assert.equal(r.ok, true);
  assert.equal(r.me, A);
  const ids = r.rows.map((x) => x.user_id);
  assert.ok(!ids.includes(C) && !ids.includes(D));
  assert.deepEqual(r.rows.slice(0, 2).map((x) => [x.user_id, x.xp, x.level, x.title, x.me]), [
    [B, 2600, 6, '勤勞農夫', false],
    [A, 300, 2, '菜鳥農夫', true],
  ]);
  const f1 = r.rows.find((x) => x.user_id === F(1));
  assert.equal(f1.level, 1, 'a garbage save counts as level 1');
  assert.equal(r.rows.length, 1 + 1 + 6, 'me + B + F1..F6');
  assert.ok(r.rows.every((x) => !('plots' in x) && !('inventory' in x)));
});

test('board costs more than a farm view', async () => {
  throttle = true;
  await sql('delete from public.friend_help_limits');
  const seen = [];
  for (let i = 0; i < 8; i++) seen.push((await rpc(A, 'friends_board')).ok);
  assert.deepEqual(seen, [true, true, true, true, true, true, false, false], '30 tokens / 5 = 6 boards in a burst');
});

// ── 澆水 ────────────────────────────────────────────────────────────────

test('help water: records it, gives fixed xp, shows up in the friend farm view', async () => {
  await setSave(B, blob(farm(10)));
  const r = await rpc(A, 'friend_water', B, 0);
  assert.deepEqual(r, { ok: true, helperXp: 3, helpedXp: 5, leftToday: 4 });
  const rows = await sql('select helper, helped, plot, helper_xp, helped_xp from public.friend_helps');
  assert.deepEqual(rows, [{ helper: A, helped: B, plot: 0, helper_xp: 3, helped_xp: 5 }]);
  const view = await rpc(A, 'friend_farm', B);
  assert.deepEqual(view.help, { doneToday: true, leftToday: 4, pendingPlots: [0] });
});

test('only a dry plot with a crop can be watered', async () => {
  await setSave(B, blob(farm(10)));
  for (const p of [1, 2, 3, 11]) {
    assert.equal((await rpc(A, 'friend_water', B, p)).reason, 'nothing_to_water', `plot ${p}`);
  }
  for (const p of [-1, 12, null, 1000]) {
    assert.equal((await rpc(A, 'friend_water', B, p)).reason, 'bad_plot', `plot ${p}`);
  }
  assert.equal((await sql('select count(*)::int as n from public.friend_helps'))[0].n, 0);
});

test('each friend once a day; the next day it works again', async () => {
  await setSave(B, blob(farm(10, { plots: [dryPlot(), dryPlot(), ...Array(10).fill(plot())] })));
  assert.equal((await rpc(A, 'friend_water', B, 0)).ok, true);
  assert.equal((await rpc(A, 'friend_water', B, 1)).reason, 'already_today', 'a different plot of the same friend');
  assert.equal((await rpc(A, 'friend_water', B, 0)).reason, 'already_today');
  await sql("update public.friend_helps set day = day - 1, helped_claimed_at = now()");
  assert.equal((await rpc(A, 'friend_water', B, 1)).ok, true, 'tomorrow is a new day');
});

test('at most 5 friends a day; claiming and unfriending do not reset the count', async () => {
  const friends = [B, F(1), F(2), F(3), F(4), F(5), F(6)];
  for (const f of friends) await setSave(f, blob(farm(10)));
  for (let i = 0; i < 5; i++) {
    const r = await rpc(A, 'friend_water', friends[i], 0);
    assert.equal(r.ok, true, `friend ${i}`);
    assert.equal(r.leftToday, 4 - i);
  }
  assert.equal((await rpc(A, 'friend_water', friends[5], 0)).reason, 'daily_limit');
  // my own claim does not give the quota back
  assert.equal((await rpc(A, 'friend_helps_claim')).ok, true);
  assert.equal((await rpc(A, 'friend_water', friends[5], 0)).reason, 'daily_limit');
  // the helped one claims: still no quota back
  for (const f of friends.slice(0, 5)) await rpc(f, 'friend_helps_claim');
  assert.equal((await rpc(A, 'friend_water', friends[5], 0)).reason, 'daily_limit');
  // unfriending one of them and re-adding does not either
  await sql('delete from public.friendships where user_low = $1 or user_high = $1', [friends[0]]);
  await sql(
    "insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')",
    [A, friends[0]],
  );
  assert.equal((await rpc(A, 'friend_water', friends[5], 0)).reason, 'daily_limit');
  assert.equal((await rpc(A, 'friend_water', friends[0], 0)).reason, 'already_today');
});

test('one person receives at most 5 helps a day', async () => {
  const helpers = [A, F(1), F(2), F(3), F(4), F(5)];
  // make the 6 helpers all friends of B
  for (const h of helpers.slice(1)) {
    await sql(
      "insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')",
      [B, h],
    );
  }
  await setSave(B, blob(farm(10, { plots: Array.from({ length: 12 }, () => dryPlot()) })));
  for (let i = 0; i < 5; i++) assert.equal((await rpc(helpers[i], 'friend_water', B, i)).ok, true, `helper ${i}`);
  assert.equal((await rpc(helpers[5], 'friend_water', B, 5)).reason, 'friend_full');
});

test('a plot already waiting for its owner cannot be watered again; after the claim it can again', async () => {
  await setSave(B, blob(farm(10)));
  await sql(
    "insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')",
    [B, C],
  );
  assert.equal((await rpc(A, 'friend_water', B, 0)).ok, true);
  assert.equal((await rpc(C, 'friend_water', B, 0)).reason, 'plot_waiting');
  await rpc(B, 'friend_helps_claim');
  assert.equal((await rpc(C, 'friend_water', B, 0)).ok, true, 'B applied it; the page now saves a wet plot');
});

test('stranger and blocked friend cannot water; nothing is stored', async () => {
  await setSave(B, blob(farm(10)));
  await setSave(D, blob(farm(10)));
  await setSave(C, blob(farm(10)));
  for (const who of [C, D, A]) {
    assert.equal((await rpc(A, 'friend_water', who, 0)).reason, 'not_friend', who);
  }
  assert.equal((await rpc(C, 'friend_water', B, 0)).reason, 'not_friend');
  assert.equal((await sql('select count(*)::int as n from public.friend_helps'))[0].n, 0);
});

test('a friend without a farm: no_farm', async () => {
  assert.equal((await rpc(A, 'friend_water', B, 0)).reason, 'no_farm');
  await setSave(B, 'garbage');
  assert.equal((await rpc(A, 'friend_water', B, 0)).reason, 'no_farm');
});

test('too many records waiting for one person: friend_full', async () => {
  await setSave(B, blob(farm(10, { plots: Array.from({ length: 12 }, () => dryPlot()) })));
  // 10 old unclaimed records from earlier days by other people
  for (let i = 0; i < 10; i++) {
    const h = uid(100 + i);
    await sql('insert into auth.users (id) values ($1)', [h]);
    await sql(
      "insert into public.friend_helps (helper, helped, day, plot, helper_xp, helped_xp) values ($1, $2, current_date - 3, $3, 3, 5)",
      [h, B, i],
    );
  }
  assert.equal((await rpc(A, 'friend_water', B, 11)).reason, 'friend_full');
});

// ── 領取 ────────────────────────────────────────────────────────────────

test('claim: the helped person gets plot + xp once, the helper gets the helper xp once', async () => {
  await setSave(B, blob(farm(10, { plots: [dryPlot(), dryPlot(), ...Array(10).fill(plot())] })));
  await setSave(F(1), blob(farm(10, { plots: [dryPlot(), dryPlot(), ...Array(10).fill(plot())] })));
  await sql(
    "insert into public.friendships (user_low, user_high, source) values (least($1::uuid, $2::uuid), greatest($1::uuid, $2::uuid), 'code')",
    [B, F(1)],
  );
  await rpc(A, 'friend_water', B, 0);
  await rpc(F(1), 'friend_water', B, 1);

  const b = await rpc(B, 'friend_helps_claim');
  assert.equal(b.ok, true);
  assert.deepEqual(b.received.map((x) => [x.plot, x.xp, x.from]), [[0, 5, '玩家0'], [1, 5, '玩家4']]);
  assert.equal(b.givenXp, 0);
  assert.deepEqual(await rpc(B, 'friend_helps_claim'), { ok: true, received: [], givenXp: 0 }, 'a second claim returns nothing');

  const a = await rpc(A, 'friend_helps_claim');
  assert.deepEqual(a, { ok: true, received: [], givenXp: 3 });
  assert.deepEqual(await rpc(A, 'friend_helps_claim'), { ok: true, received: [], givenXp: 0 });
  assert.equal((await rpc(F(1), 'friend_helps_claim')).givenXp, 3);

  const pend = await rpc(A, 'friend_farm', B);
  assert.deepEqual(pend.help.pendingPlots, [], 'claimed records are no longer pending');
});

test('claim: nobody can claim for someone else, and a stranger gets nothing', async () => {
  await setSave(B, blob(farm(10)));
  await rpc(A, 'friend_water', B, 0);
  assert.deepEqual(await rpc(C, 'friend_helps_claim'), { ok: true, received: [], givenXp: 0 });
  assert.deepEqual(await rpc(D, 'friend_helps_claim'), { ok: true, received: [], givenXp: 0 });
  assert.equal((await rpc(B, 'friend_helps_claim')).received.length, 1, 'still there for B');
});

test('claim: the xp is whatever the server wrote, never more', async () => {
  await setSave(B, blob(farm(10)));
  await rpc(A, 'friend_water', B, 0);
  const rows = await sql('select helper_xp, helped_xp from public.friend_helps');
  assert.ok(rows[0].helper_xp <= 3 && rows[0].helped_xp <= 5);
  await assert.rejects(
    sql("insert into public.friend_helps (helper, helped, day, plot, helper_xp, helped_xp) values ($1, $2, current_date, 1, 21, 5)", [A, C]),
    /check/i,
    'the table itself refuses a big number',
  );
});

test('cleanup: only service_role, only records older than 14 days', async () => {
  await setSave(B, blob(farm(10)));
  await rpc(A, 'friend_water', B, 0);
  await sql(
    "insert into public.friend_helps (helper, helped, day, plot, helper_xp, helped_xp) values ($1, $2, current_date - 20, 5, 3, 5)",
    [F(1), B],
  );
  await db.exec('set role service_role');
  const n = (await db.query('select public.friend_helps_cleanup() as n')).rows[0].n;
  await db.exec('reset role');
  assert.equal(n, 1);
  assert.equal((await sql('select count(*)::int as n from public.friend_helps'))[0].n, 1);
});
