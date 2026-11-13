-- 20261114120000_app_min_version.sql
--
-- 尚未套用到任何資料庫。
--
-- 「最低支援版本」閘門：App 啟動與回到前景時問伺服器，版本低於 min_version 就擋住整個 App、
-- 請使用者更新。準備把 Supabase 從雪梨搬到東京，iOS 沒有強制更新機制，舊版 App 會繼續寫舊伺服器，
-- 所以要有一個伺服器可控的開關。App 端查詢失敗一律放行（fail open），不會因為這支函式壞掉而擋人。
--
-- 資安：匿名只能呼叫 app_min_version，回傳 min_version 與 store_url；資料表本身 RLS 開、無 policy，
-- anon／authenticated 沒有任何直接權限。要調整版本由維運者用 service_role／SQL editor 改。

create table if not exists public.app_release_policy (
  platform    text primary key check (platform in ('ios', 'android')),
  min_version text not null,
  store_url   text not null,
  updated_at  timestamptz not null default now()
);

alter table public.app_release_policy enable row level security;
revoke all on public.app_release_policy from anon, authenticated;

create or replace function public.app_min_version(p_platform text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select jsonb_build_object('min_version', min_version, 'store_url', store_url)
       from public.app_release_policy
      where platform = p_platform),
    '{}'::jsonb
  );
$$;

revoke all on function public.app_min_version(text) from public;
grant execute on function public.app_min_version(text) to anon, authenticated;

insert into public.app_release_policy (platform, min_version, store_url) values
  ('ios', '0.0.0', 'https://apps.apple.com/app/id6826730775'),
  ('android', '0.0.0', 'https://play.google.com/store/apps/details?id=com.dongyutech.silversole')
on conflict do nothing;
