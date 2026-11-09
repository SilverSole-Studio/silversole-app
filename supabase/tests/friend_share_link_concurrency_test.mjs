// supabase/tests/friend_share_link_concurrency_test.mjs
//
// PGlite 只有一條連線，測不到並發。這裡用 embedded-postgres 起一個真的 PostgreSQL，
// 每個請求一條連線、同一個 tick 一起打：
//   - 30 個人同時用同一條連結加同一個人：恰好 10 封進得去。
//   - 同一個人同時按 20 次「產生連結」：只剩一列、全都拿到同一個 token。
//   - 同時「產生」和「停用」：結果只能是「有效的一條」或「停用的一條」，不會有兩條。
//
//   cd supabase/tests && npm install && npm run test:share-link-concurrency

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
// 角色屬於整個伺服器，不是單一資料庫：只建一次。
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8').replace(
  /create role (\w+) ([^;]+);/g,
  'do $r$ begin create role $1 $2; exception when duplicate_object then null; end $r$;',
);
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
  .map((f) =>
    readFileSync(join(migrationsDir, f), 'utf8').replace(/select cron\.schedule\([\s\S]*?\$cron\$\s*\);/g, ''),
  )
  .join('\n');

const PORT = 54891;
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const wang = uid(1);

let server;
let dir;

test.before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'sharelink-pg-'));
  server = new EmbeddedPostgres({
    databaseDir: dir,
    user: 'postgres',
    password: 'postgres',
    port: PORT,
    persistent: false,
    initdbFlags: ['--encoding=UTF8', '--locale=C'],
    postgresFlags: ['-c', 'max_connections=200'],
  });
  await server.initialise();
  await server.start();
});

test.after(async () => {
  await server?.stop();
  if (dir) rmSync(dir, { recursive: true, force: true });
});

const connect = async (database) => {
  const c = new pg.Client({ host: 'localhost', port: PORT, user: 'postgres', password: 'postgres', database });
  await c.connect();
  return c;
};

/** 新資料庫：套好 migration，王阿姨（uid 1）加 [n] 個路人（uid 100+），全是滿 7 天的帳號。 */
async function freshDb(name, n) {
  const admin = await connect('postgres');
  await admin.query(`drop database if exists ${name}`);
  await admin.query(`create database ${name}`);
  await admin.end();
  const db = await connect(name);
  await db.query(stubs);
  await db.query(migration);
  // 隔離出要測的鎖：每人限流（一分鐘 30 次）另有自己的測試。
  await db.query(
    'create or replace function public.friends_take(p_me uuid, p_cost real) returns void language plpgsql as $$ begin end $$',
  );
  for (const [i, u] of [wang, ...Array.from({ length: n }, (_, i) => uid(100 + i))].entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query(
      `insert into public.profiles (user_id, friend_code, nickname, created_at)
       values ($1, $2, $3, now() - interval '7 days')`,
      [u, String(30000000 + i), `朋友${i}`],
    );
  }
  await db.end();
}

/** 每個工作一條連線、先全部登入好，再同一個 tick 一起送出。 */
async function burst(database, jobs) {
  const clients = await Promise.all(
    jobs.map(async ([user]) => {
      const c = await connect(database);
      await c.query('set role authenticated');
      await c.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
      return c;
    }),
  );
  try {
    return await Promise.all(
      jobs.map(([, sql, params], i) =>
        clients[i].query(sql, params).then(
          (r) => r.rows,
          (e) => ({ error: e.message }),
        ),
      ),
    );
  } finally {
    await Promise.all(clients.map((c) => c.end()));
  }
}

async function one(database, sql, params = []) {
  const c = await connect(database);
  try {
    return (await c.query(sql, params)).rows;
  } finally {
    await c.end();
  }
}

test('30 people send through one link at the same instant: exactly 10 get in', async () => {
  await freshDb('sl_inbox', 30);
  const [{ r }] = (await burst('sl_inbox', [[wang, 'select public.create_share_link() as r', []]]))[0];
  const res = await burst(
    'sl_inbox',
    Array.from({ length: 30 }, (_, i) => [
      uid(100 + i),
      "select public.send_friend_request('link', $1) as r",
      [r.token],
    ]),
  );
  const sent = res.filter((x) => x[0]?.r?.result === 'sent').length;
  const refused = res.filter((x) => x[0]?.r?.error === 'link_limit').length;
  assert.equal(sent, 10, JSON.stringify(res.slice(0, 3)));
  assert.equal(refused, 20);
  const [{ n }] = await one('sl_inbox', "select count(*)::int as n from public.friend_requests where to_user = $1 and source = 'link'", [wang]);
  assert.equal(n, 10);
  const [{ received }] = await one('sl_inbox', 'select received from public.friend_link_inbox');
  assert.equal(received, 10);
});

test('20 simultaneous "make my link" calls leave one row and one token', async () => {
  await freshDb('sl_create', 0);
  const res = await burst(
    'sl_create',
    Array.from({ length: 20 }, () => [wang, 'select public.create_share_link() as r', []]),
  );
  const tokens = new Set(res.map((x) => x[0]?.r?.token));
  assert.equal(tokens.size, 1, JSON.stringify(res.slice(0, 2)));
  const [{ n }] = await one('sl_create', 'select count(*)::int as n from public.friend_share_links');
  assert.equal(n, 1);
});

test('make and disable at the same time never leave two live links', async () => {
  await freshDb('sl_race', 0);
  await burst('sl_race', [[wang, 'select public.create_share_link() as r', []]]);
  const jobs = [];
  for (let i = 0; i < 10; i++) {
    jobs.push([wang, 'select public.disable_share_link() as r', []]);
    jobs.push([wang, 'select public.create_share_link() as r', []]);
  }
  const res = await burst('sl_race', jobs);
  assert.ok(res.every((x) => Array.isArray(x)), JSON.stringify(res.filter((x) => !Array.isArray(x))));
  const rows = await one('sl_race', 'select * from public.friend_share_links');
  assert.equal(rows.length, 1);
});
