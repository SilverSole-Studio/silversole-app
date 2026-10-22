-- supabase/tests/supabase_stubs.sql
--
-- 只給本機測試用：在一個空的 PostgreSQL（PGlite）裡放 Supabase 會有的最小替身，
-- 好讓 migrations/ 能原封不動套上去。正式庫已經有這些，絕對不要套到正式庫。
--
-- - 角色 anon、authenticated、service_role，以及 Supabase 的預設權限
--   （public 的新表與新函式開給 anon、authenticated），這樣 migration 裡的 revoke 才測得到。
-- - auth.users、auth.uid()：uid 讀 request.jwt.claim.sub，跟 Supabase 一樣。
-- - storage.buckets、storage.objects、storage.foldername()：只放政策會用到的欄位。

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role;

create table auth.users (
  id uuid primary key,
  email text
);

create function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create schema storage;
grant usage on schema storage to anon, authenticated, service_role;

create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text not null,
  owner uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;
grant select, insert on storage.objects to authenticated;

create function storage.foldername(name text)
returns text[]
language sql
immutable
as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
