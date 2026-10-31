// supabase/tests/game_saves_concurrency_test.mjs
//
// The game_saves cases PGlite cannot play (one connection): one account saving
// from several phones at the same instant. Starts a real PostgreSQL on this
// machine (embedded-postgres, MIT), same harness as friends_concurrency_test.mjs.
//
//   cd supabase/tests && npm install && npm run test:saves-concurrency

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
const migration = readdirSync(migrationsDir)
  .filter((f) => f.endsWith('.sql') && f.includes('game_saves'))
  .sort()
  .map((f) => readFileSync(join(migrationsDir, f), 'utf8'))
  .join('\n');

const PORT = 54891;
const me = '00000000-0000-4000-8000-000000000001';

let server;
let dir;

test.before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'saves-pg-'));
  server = new EmbeddedPostgres({
    databaseDir: dir,
    user: 'postgres',
    password: 'postgres',
    port: PORT,
    persistent: false,
    initdbFlags: ['--encoding=UTF8', '--locale=C'],
    postgresFlags: ['-c', 'max_connections=100'],
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

async function freshDb(name) {
  const admin = await connect('postgres');
  await admin.query(`drop database if exists ${name}`);
  await admin.query(`create database ${name}`);
  await admin.end();
  const db = await connect(name);
  await db.query(stubs);
  await db.query(migration);
  await db.query('insert into auth.users (id) values ($1)', [me]);
  await db.end();
}

/** Every job as [user] on its own connection, all fired in the same tick. */
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
          (r) => r.rows[0].r,
          (e) => ({ error: e.message }),
        ),
      ),
    );
  } finally {
    await Promise.all(clients.map((c) => c.end()));
  }
}

test('eight phones save the same rev at once: exactly one wins, the rest get conflict', async () => {
  await freshDb('s_cas');
  const rs = await burst(
    's_cas',
    me,
    Array.from({ length: 8 }, (_, i) => ['select public.game_save_store($1, $2) as r', [0, JSON.stringify({ phone: i })]]),
  );
  assert.equal(rs.filter((r) => r.ok === true).length, 1, JSON.stringify(rs));
  assert.equal(rs.filter((r) => r.reason === 'conflict' && r.rev === 1).length, 7, JSON.stringify(rs));
});

test('30 loads at once from one person: 10 pass, 20 are rate limited, nothing errors', async () => {
  await freshDb('s_rate');
  const rs = await burst('s_rate', me, Array.from({ length: 30 }, () => ['select public.game_save_load() as r', []]));
  assert.equal(rs.filter((r) => r.ok === true).length, 10, JSON.stringify(rs.filter((r) => r.error)));
  assert.equal(rs.filter((r) => r.reason === 'rate_limited').length, 20);
});
