// supabase/tests/friends_concurrency_test.mjs
//
// The cases PGlite cannot play (one connection): many requests from one person
// at the same instant. Starts a real PostgreSQL on this machine
// (embedded-postgres, MIT), applies supabase_stubs.sql plus the migrations, and
// fires the calls from separate connections at once.
//
//   cd supabase/tests && npm install && npm run test:concurrency
//
// Each case runs twice: on the first migration alone (shows the hole the
// 2026-10-26 audit found) and on all migrations (must hold).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
// Roles belong to the whole server, not one database: create them only once.
const stubs = readFileSync(join(here, 'supabase_stubs.sql'), 'utf8').replace(
  /create role (\w+) ([^;]+);/g,
  'do $r$ begin create role $1 $2; exception when duplicate_object then null; end $r$;',
);
const migrationsDir = join(here, '..', 'migrations');
const files = readdirSync(migrationsDir)
  .filter((f) => f.endsWith('.sql') && f.includes('friends'))
  .sort();
const read = (f) => readFileSync(join(migrationsDir, f), 'utf8');
const before = read(files[0]);
const after = files.map(read).join('\n');

const PORT = 54890;
const me = '00000000-0000-4000-8000-000000000001';
const uid = (n) => `00000000-0000-4000-9000-${String(n).padStart(12, '0')}`;
const ORG = '00000000-0000-4000-a000-000000000001';

let server;
let dir;

test.before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'friends-pg-'));
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

/** A fresh database with [migration] applied, me plus [n] people in one org. */
async function freshDb(name, migration, n, { noRateLimit = false } = {}) {
  const admin = await connect('postgres');
  await admin.query(`drop database if exists ${name}`);
  await admin.query(`create database ${name}`);
  await admin.end();
  const db = await connect(name);
  await db.query(stubs);
  await db.query(migration);
  if (noRateLimit) {
    // Isolate the lock under test from the per-user rate limit (which alone would stop at ~10).
    await db.query(
      "create or replace function public.friends_take(p_me uuid, p_cost real) returns void language plpgsql as $$ begin end $$",
    );
  }
  await db.query("insert into public.orgs (id, name, kind, join_code) values ($1, '據點', 'community_center', '52013140')", [ORG]);
  for (const [i, u] of [me, ...Array.from({ length: n }, (_, i) => uid(i))].entries()) {
    await db.query('insert into auth.users (id) values ($1)', [u]);
    await db.query(
      `insert into public.profiles (user_id, friend_code, nickname, created_at)
       values ($1, $2, $3, now() - interval '7 days')`,
      [u, String(30000000 + i), `朋友${i}`],
    );
    await db.query('insert into public.org_members (org_id, user_id) values ($1, $2)', [ORG, u]);
  }
  await db.end();
}

/**
 * Runs every job as [user], each on its own connection: all connections are
 * opened and signed in first, then every query is fired in the same tick, so
 * they really overlap. Resolves to one result per job (rows, or {error}).
 */
async function burst(database, user, jobs) {
  const clients = await Promise.all(
    jobs.map(async () => {
      const c = await connect(database);
      await c.query('set role authenticated');
      await c.query("select set_config('request.jwt.claim.sub', $1, false)", [user]);
      return c;
    }),
  );
  try {
    return await Promise.all(
      jobs.map(([sql, params], i) =>
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

async function send60(database) {
  const res = await burst(
    database,
    me,
    Array.from({ length: 60 }, (_, i) => ['select public.send_friend_request($1, $2) as r', ['org', uid(i)]]),
  );
  const c = await connect(database);
  const [{ n }] = (
    await c.query("select count(*)::int as n from public.friend_requests where from_user = $1 and status = 'pending'", [me])
  ).rows;
  await c.end();
  return { n, res };
}

async function upload30(database) {
  const res = await burst(
    database,
    me,
    Array.from({ length: 30 }, (_, i) => [
      "insert into storage.objects (bucket_id, name) values ('avatars', $1) returning name",
      [`${me}/17600000${String(i).padStart(5, '0')}.jpg`],
    ]),
  );
  return res.filter((r) => Array.isArray(r)).length;
}

test('audit 6: 60 requests to 60 people at once — before the fix more than 20 get through', async (t) => {
  await freshDb('f_before_send', before, 60);
  const { n } = await send60('f_before_send');
  t.diagnostic(`old code: ${n} of 60 waiting (limit is 20)`);
  assert.ok(n > 20, `expected the old code to let more than 20 through, got ${n}`);
});

test('audit 6: 60 requests to 60 people at once — after the fix exactly 20 are waiting', async () => {
  await freshDb('f_after_send', after, 60, { noRateLimit: true });
  const { n, res } = await send60('f_after_send');
  assert.equal(n, 20);
  assert.equal(res.filter((r) => r[0]?.r?.error === 'pending_limit').length, 40);
});

test('audit 4: 30 photo uploads at once — before the fix more than 5 land', async (t) => {
  await freshDb('f_before_up', before, 0);
  const ok = await upload30('f_before_up');
  t.diagnostic(`old policy: ${ok} of 30 uploads landed (limit is 5)`);
  assert.ok(ok > 5, `expected the old policy to let more than 5 through, got ${ok}`);
});

test('audit 4: 30 photo uploads at once — after the fix exactly 5 land', async () => {
  await freshDb('f_after_up', after, 0);
  assert.equal(await upload30('f_after_up'), 5);
});

test('audit 8: 50 calls at once from one person — some are refused, nothing breaks', async () => {
  await freshDb('f_after_rate', after, 0);
  const res = await burst(
    'f_after_rate',
    me,
    Array.from({ length: 50 }, () => ['select public.get_friends() as r', []]),
  );
  const ok = res.filter((r) => Array.isArray(r)).length;
  const limited = res.filter((r) => r.error === 'rate_limited').length;
  assert.equal(ok + limited, 50, JSON.stringify(res.filter((r) => !Array.isArray(r) && r.error !== 'rate_limited')));
  assert.ok(ok <= 31 && limited >= 19, `ok ${ok}, limited ${limited}`);
});
