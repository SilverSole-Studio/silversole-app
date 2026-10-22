-- supabase/migrations/20261019120000_friends.sql
--
-- 好友系統：資料表、RLS、RPC、avatars bucket
--
-- 狀態：未套用到任何 Supabase 專案。只在本機 PGlite（PostgreSQL 17，auth／storage
--   換成最小替身）跑過 supabase/tests/friends_rpc_test.mjs。套用到正式庫之前要先問 user，
--   並先跑 supabase/README.md 的「套用前比對」查詢。
-- 規格：動域科技總倉庫 02_產品/鞋墊_SilverSole/_好友系統規格書_2026-10-18.md 第 7、8 節。
-- App 端：lib/core/friends/supabase_friends_repository.dart（每支 RPC 一個方法）。
--
-- 慣例：
-- - 每張表都開 RLS。App 只能 select 自己的列（profiles、friendships、blocks、
--   org_members）；寫入一律走下面的 security definer RPC。
-- - 每支 security definer 函式都 set search_path = ''，表與函式都寫 public.／auth.。
-- - 錯誤：raise exception '<代碼>'，代碼＝規格 8.3 節（not_found、limit_reached…），
--   App 換成 FriendError。會動到「查號次數」的函式改成回傳 {"error": "<代碼>"}，
--   不用 raise，否則交易回滾，猜錯的次數就記不住。
-- - 「今天」用台灣時間（跟菜園的 farm_today() 一樣）。
-- - 數字＝lib/core/friends/friend_rules.dart 的常數；要調就兩邊一起改。
--
-- 跟規格書刻意不同的地方（理由寫在 supabase/README.md）：
-- 1. friend_requests 不開 select：送的人直接讀表會看到 status = 'declined'，
--    「按不要不通知」就破功了。App 一律用 get_friend_requests()。
-- 2. 照片網址：Postgres 產生不了 Storage 的簽名網址。改成 RPC 只回照片路徑，
--    App 用 createSignedUrls(…, 3600) 換網址；avatars 的 SELECT 政策只放行
--    「自己的資料夾」與「好友目前那一張照片」，非好友簽不出網址。
-- 3. 多了幾個欄位：profiles.nickname_removed／avatar_removed（「被抽掉了」的提示）、
--    profiles.nickname_changed_on（配 nickname_changed_today 換日）、
--    friend_daily_limits.previewed_codes（預覽過的號碼送出時不再扣次數）、
--    profile_reports.handled_by（中控台操作人）。
-- 4. 多一支 acknowledge_removals()：App 顯示過「照片被移除了」之後清掉提示。
-- 5. 冷卻期間再邀不回 cooldown：照常回 sent，但存成 declined、不送到對方那裡
--    （send_friend_request 裡有說明）。其餘差異（QR 寬限、other_friend_limit…）
--    見 README 的表。

begin;

-- ── 資料表 ────────────────────────────────────────────────────────────

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  nickname text,
  avatar_preset smallint not null default 1 check (avatar_preset between 1 and 12),
  avatar_path text,
  avatar_removed_count integer not null default 0,
  avatar_upload_banned_until timestamptz,
  friend_code text not null unique check (friend_code ~ '^[1-9][0-9]{7}$'),
  show_in_org_list boolean not null default true,
  nickname_changed_today smallint not null default 0,
  nickname_changed_on date,
  nickname_removed boolean not null default false,
  avatar_removed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 一對好友只存一列，小的 user_id 放前面。
create table public.friendships (
  user_low uuid not null references public.profiles (user_id) on delete cascade,
  user_high uuid not null references public.profiles (user_id) on delete cascade,
  source text not null check (source in ('qr', 'code', 'org')),
  created_at timestamptz not null default now(),
  last_interaction_at timestamptz,
  primary key (user_low, user_high),
  check (user_low < user_high)
);
create index friendships_user_high_idx on public.friendships (user_high);
-- can_read_avatar() 每次簽網址都用照片路徑反查是誰的照片。
create index profiles_avatar_path_idx on public.profiles (avatar_path)
  where avatar_path is not null;

create table public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kind text not null check (kind in ('community_center', 'day_care', 'other')),
  join_code text not null unique check (join_code ~ '^[1-9][0-9]{7}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references public.profiles (user_id) on delete cascade,
  to_user uuid not null references public.profiles (user_id) on delete cascade,
  source text not null check (source in ('qr', 'code', 'org')),
  org_id uuid references public.orgs (id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  -- 對方同意或拒絕的時間。取消不寫這欄，拒絕後的 30 天冷卻從這裡算。
  responded_at timestamptz,
  check (from_user <> to_user)
);
-- 同一對（不分方向）同時只能有一封 pending。互邀走的是「直接成立」，
-- 兩人同時送的話 send_friend_request 的 advisory lock 先排隊，這個索引是最後防線。
create unique index friend_requests_one_pending_idx
  on public.friend_requests (least(from_user, to_user), greatest(from_user, to_user))
  where status = 'pending';
create index friend_requests_to_idx on public.friend_requests (to_user, status);
create index friend_requests_from_idx on public.friend_requests (from_user, status);

create table public.blocks (
  blocker uuid not null references public.profiles (user_id) on delete cascade,
  blocked uuid not null references public.profiles (user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index blocks_blocked_idx on public.blocks (blocked);

create table public.qr_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index qr_tokens_user_idx on public.qr_tokens (user_id);
create index qr_tokens_expires_idx on public.qr_tokens (expires_at);

create table public.org_members (
  org_id uuid not null references public.orgs (id) on delete cascade,
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (org_id, user_id)
);
create index org_members_user_idx on public.org_members (user_id);

create table public.profile_reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid references public.profiles (user_id) on delete set null,
  target_user uuid not null references public.profiles (user_id) on delete cascade,
  kind text not null check (kind in ('photo', 'nickname')),
  -- 檢舉當下的照片路徑或暱稱；之後他改掉了，中控台還看得到被檢舉的是什麼。
  snapshot text,
  reason text not null
    check (reason in ('indecent', 'violent', 'impersonation', 'ads', 'other')),
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by text,
  result text check (result in ('removed', 'kept'))
);
create index profile_reports_open_idx on public.profile_reports (created_at)
  where handled_at is null;

create table public.friend_daily_limits (
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  day date not null,
  lookups integer not null default 0,
  failed_lookups_streak integer not null default 0,
  locked_until timestamptz,
  reports integer not null default 0,
  uploads integer not null default 0,
  previewed_codes text[] not null default '{}',
  primary key (user_id, day)
);

-- ── RLS：只讀自己的列，沒有任何寫入政策 ─────────────────────────────

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.friend_requests enable row level security;
alter table public.blocks enable row level security;
alter table public.qr_tokens enable row level security;
alter table public.orgs enable row level security;
alter table public.org_members enable row level security;
alter table public.profile_reports enable row level security;
alter table public.friend_daily_limits enable row level security;

revoke all on
  public.profiles, public.friendships, public.friend_requests, public.blocks,
  public.qr_tokens, public.orgs, public.org_members, public.profile_reports,
  public.friend_daily_limits
from anon, authenticated;

grant select on
  public.profiles, public.friendships, public.blocks, public.org_members
to authenticated;

create policy "profiles: read own" on public.profiles
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy "friendships: read own" on public.friendships
  for select to authenticated
  using ((select auth.uid()) in (user_low, user_high));

-- 被封鎖的人查不到自己被封鎖。
create policy "blocks: blocker reads own" on public.blocks
  for select to authenticated
  using (blocker = (select auth.uid()));

create policy "org_members: read own" on public.org_members
  for select to authenticated
  using (user_id = (select auth.uid()));

-- friend_requests、qr_tokens、orgs、profile_reports、friend_daily_limits：
-- 開了 RLS 但沒有政策，App 直接讀寫一律拿不到。

-- ── 內部小工具（不開放給 App）────────────────────────────────────────

create function public.friends_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Taipei')::date
$$;

-- 8 位數字、不以 0 開頭；好友碼與據點代碼共用一個號碼空間。
create function public.friends_new_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  loop
    v_code := (
      ('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint
        % 90000000 + 10000000
    )::text;
    exit when not exists (select 1 from public.profiles where friend_code = v_code)
      and not exists (select 1 from public.orgs where join_code = v_code);
  end loop;
  return v_code;
end
$$;

-- 每支 App RPC 的第一行：要登入，第一次呼叫順便建 profiles（暱稱是空的，App 會請他取）。
create function public.friends_me()
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'not_signed_in';
  end if;
  if not exists (select 1 from public.profiles where user_id = v_me) then
    loop
      begin
        insert into public.profiles (user_id, friend_code)
        values (v_me, public.friends_new_code())
        on conflict (user_id) do nothing;
        exit;
      exception when unique_violation then
        -- friend_code 剛好被別人同時拿走，換一組再試。
      end;
    end loop;
  end if;
  return v_me;
end
$$;

-- 只確認有登入、不建 profiles。只讀、而且「還沒用過好友」也該回空的 RPC 用這支
-- （紅點、好友卡），免得沒打開過好友的人也被配了一組好友碼。
create function public.friends_uid()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    raise exception 'not_signed_in';
  end if;
  return v_me;
end
$$;

create function public.friends_blocked_either(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks
    where (blocker = a and blocked = b) or (blocker = b and blocked = a)
  )
$$;

-- 同一對人的動作排隊（互邀、同意、封鎖），避免兩邊同時做出兩列。
create function public.friends_lock_pair(a uuid, b uuid)
returns void
language sql
volatile
set search_path = ''
as $$
  select pg_advisory_xact_lock(
    hashtextextended(least(a, b)::text || greatest(a, b)::text, 0)
  )
$$;

-- 別人看到的樣子。p_with_photo 只有好友名單才是 true；
-- 據點名單、預覽、邀請、封鎖名單一律只給粗哥頭像（規格 2.2）。
create function public.friends_profile_json(p_user uuid, p_with_photo boolean)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'user_id', p.user_id,
    'nickname', coalesce(p.nickname, '銀足朋友'),
    'avatar_preset', p.avatar_preset,
    'avatar_path', case when p_with_photo then p.avatar_path end
  )
  from public.profiles p
  where p.user_id = p_user
$$;

create function public.friends_my_profile_json(p_me uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'user_id', p.user_id,
    'nickname', p.nickname,
    'avatar_preset', p.avatar_preset,
    'avatar_path', p.avatar_path,
    'friend_code', p.friend_code,
    'show_in_org_list', p.show_in_org_list,
    'avatar_upload_banned_until', p.avatar_upload_banned_until,
    'nickname_removed', p.nickname_removed,
    'avatar_removed', p.avatar_removed
  )
  from public.profiles p
  where p.user_id = p_me
$$;

-- 邀請 7 天過期不跑排程，相關 RPC 順手改。拒絕過的保留 declined：
-- 送的人那邊看起來還在「等回覆」，到期才消失。
create function public.friends_expire_requests(p_me uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.friend_requests
  set status = 'expired'
  where status = 'pending'
    and expires_at <= now()
    and (from_user = p_me or to_user = p_me)
$$;

-- 在送的人眼裡還在等：pending 或被悄悄拒絕，而且還沒到期。
create function public.friends_open_out(p_from uuid, p_to uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friend_requests
    where from_user = p_from and to_user = p_to
      and status in ('pending', 'declined')
      and expires_at > now()
  )
$$;

create function public.friends_accept(p_request_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  r public.friend_requests;
begin
  update public.friend_requests
  set status = 'accepted', responded_at = now()
  where id = p_request_id
  returning * into r;
  -- 兩人之間其他還開著的邀請（反方向在等的、被悄悄拒絕或暫扣的）一起結掉，
  -- 不然送的人那邊會一直顯示「等回覆」給已經是好友的人。
  update public.friend_requests
  set status = 'accepted', responded_at = now()
  where status in ('pending', 'declined')
    and id <> r.id
    and ((from_user = r.from_user and to_user = r.to_user)
      or (from_user = r.to_user and to_user = r.from_user));
  insert into public.friendships (user_low, user_high, source)
  values (least(r.from_user, r.to_user), greatest(r.from_user, r.to_user), r.source)
  on conflict do nothing;
end
$$;

-- 今天的次數那一列（鎖住）。順手清掉前天以前的。
create function public.friends_limits(p_me uuid)
returns public.friend_daily_limits
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  r public.friend_daily_limits;
begin
  delete from public.friend_daily_limits
  where user_id = p_me and day < public.friends_today() - 1;
  insert into public.friend_daily_limits (user_id, day)
  values (p_me, public.friends_today())
  on conflict do nothing;
  select * into r from public.friend_daily_limits
  where user_id = p_me and day = public.friends_today()
  for update;
  return r;
end
$$;

-- 查好友碼／據點代碼之前：連錯 5 次鎖 10 分鐘（跨午夜也算），一天 20 次。
-- 回傳錯誤代碼，可以查就回 null 並先扣一次。
create function public.friends_lookup_begin(p_me uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  r public.friend_daily_limits := public.friends_limits(p_me);
begin
  if exists (
    select 1 from public.friend_daily_limits
    where user_id = p_me and day >= public.friends_today() - 1 and locked_until > now()
  ) then
    return 'locked';
  end if;
  if r.lookups >= 20 then
    return 'limit_reached';
  end if;
  update public.friend_daily_limits set lookups = lookups + 1
  where user_id = p_me and day = r.day;
  return null;
end
$$;

create function public.friends_lookup_end(p_me uuid, p_code text, p_found boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_found then
    update public.friend_daily_limits
    set failed_lookups_streak = 0,
        previewed_codes = case
          when p_code = any (previewed_codes) then previewed_codes
          else previewed_codes || p_code
        end
    where user_id = p_me and day = public.friends_today();
  else
    update public.friend_daily_limits
    set failed_lookups_streak = case
          when failed_lookups_streak + 1 >= 5 then 0 else failed_lookups_streak + 1
        end,
        locked_until = case
          when failed_lookups_streak + 1 >= 5 then now() + interval '10 minutes'
          else locked_until
        end
    where user_id = p_me and day = public.friends_today();
  end if;
end
$$;

-- 今天預覽過的號碼送出或加入時不再扣次數；沒預覽過的照樣扣，送出不能拿來白猜號碼。
create function public.friends_was_previewed(p_me uuid, p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friend_daily_limits
    where user_id = p_me and day = public.friends_today()
      and p_code = any (previewed_codes)
  )
$$;

create function public.friends_user_by_code(p_me uuid, p_code text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  -- 封鎖（任一方向）跟號碼不存在一模一樣。還沒取名字的（打開過好友、沒設定完）
  -- 也當作不存在：他還沒決定要用好友功能。
  select p.user_id from public.profiles p
  where p_code ~ '^[1-9][0-9]{7}$'
    and p.friend_code = p_code
    and p.nickname is not null
    and p.user_id <> p_me
    and not public.friends_blocked_either(p_me, p.user_id)
$$;

create function public.friends_org_by_code(p_code text)
returns public.orgs
language sql
stable
security definer
set search_path = ''
as $$
  select * from public.orgs
  where p_code ~ '^[1-9][0-9]{7}$' and join_code = p_code and is_active
$$;

-- QR 代碼換成本人。找不到、是自己、雙方有封鎖 → not_found（先判斷，被封鎖的人
-- 看到的跟亂掃一樣）；過期 → qr_expired。
create function public.friends_resolve_qr(p_me uuid, p_token text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t public.qr_tokens;
begin
  select * into t from public.qr_tokens where token = p_token;
  if t.token is null or t.user_id = p_me
     or public.friends_blocked_either(p_me, t.user_id) then
    return 'not_found';
  end if;
  if t.expires_at <= now() then
    return 'qr_expired';
  end if;
  return t.user_id::text;
end
$$;

-- QR 剛過期的寬限：過期 60 秒內、而且這個人在過期前預覽過，照樣算數
-- （掃到 4:59、還在看名字就過期，不要讓他重來）。回傳對方，不符合回 null。
-- 預覽過的 QR 記在 friend_daily_limits.previewed_codes，前面加 'qr:'。
create function public.friends_qr_grace(p_me uuid, p_token text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select t.user_id from public.qr_tokens t
  where t.token = p_token
    and t.expires_at <= now()
    and t.expires_at > now() - interval '60 seconds'
    and t.user_id <> p_me
    and not public.friends_blocked_either(p_me, t.user_id)
    and exists (
      select 1 from public.friend_daily_limits l
      where l.user_id = p_me
        and l.day >= public.friends_today() - 1
        and ('qr:' || p_token) = any (l.previewed_codes)
    )
$$;

create function public.friends_org_json(o public.orgs)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('id', o.id, 'name', o.name, 'kind', o.kind)
$$;

-- 暱稱：去頭尾空白後 2–8 個字、沒有控制字元、至少一個字或數字（不能全是符號）。
-- 「字」用 Unicode 區段白名單判斷：Postgres 的 [[:alpha:]] 在 C 語系不認中文。
create function public.friends_clean_nickname(p_raw text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text := regexp_replace(coalesce(p_raw, ''), '^[\s　]+|[\s　]+$', '', 'g');
begin
  if char_length(v) not between 2 and 8
     or v ~ '[\u0001-\u001F\u007F]'
     or v !~ '[0-9A-Za-zÀ-ɏͰ-ϿЀ-ӿ฀-๿぀-ヿ㄀-ㄯ㐀-䶿一-鿿가-힯豈-﫿０-９Ａ-Ｚａ-ｚ]'
  then
    return null;
  end if;
  return v;
end
$$;

-- ── 給菜園與其他功能（伺服器內部用，規格 8.1）──────────────────────

-- 有好友關係、而且雙方都沒封鎖對方才是 true。lock = true 時對那一列 FOR SHARE，
-- 偷菜 RPC 在同一個交易裡判斷完，解除好友與封鎖都要等它結束才刪得掉那一列。
-- FOR SHARE 只能在 volatile 函式裡，所以這支不宣告 stable。
create function public.are_friends(a uuid, b uuid, lock boolean default false)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if a is null or b is null or a = b then
    return false;
  end if;
  if lock then
    perform 1 from public.friendships
    where user_low = least(a, b) and user_high = greatest(a, b)
    for share;
  else
    perform 1 from public.friendships
    where user_low = least(a, b) and user_high = greatest(a, b);
  end if;
  if not found then
    return false;
  end if;
  return not public.friends_blocked_either(a, b);
end
$$;

create function public.friend_count(u uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.friendships f
  where (f.user_low = u or f.user_high = u)
    and not public.friends_blocked_either(f.user_low, f.user_high)
$$;

create function public.touch_friendship(a uuid, b uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.friendships
  set last_interaction_at = now()
  where user_low = least(a, b) and user_high = greatest(a, b)
$$;

-- ── 給 App 呼叫（規格 8.2）──────────────────────────────────────────

-- 這個人是不是「我的」好友。不加鎖、stable，菜園的 RLS 政策（好友讀田）也用這支。
create function public.is_my_friend(other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and other is not null
    and other <> auth.uid()
    and exists (
      select 1 from public.friendships
      where user_low = least(auth.uid(), other) and user_high = greatest(auth.uid(), other)
    )
    and not public.friends_blocked_either(auth.uid(), other)
$$;

-- 個人檔案 ─────────────────────────────────────────────────────────

create function public.get_my_profile()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  return public.friends_my_profile_json(v_me);
end
$$;

-- 只改有給的欄位（null＝不改）。第一次取名、或重取被抽掉的名字不算在一天 3 次裡。
create function public.update_profile(
  p_nickname text default null,
  p_avatar_preset integer default null,
  p_show_in_org_list boolean default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  p public.profiles;
  v_name text;
  v_today date := public.friends_today();
begin
  select * into p from public.profiles where user_id = v_me for update;

  if p_nickname is not null then
    v_name := public.friends_clean_nickname(p_nickname);
    if v_name is null then
      raise exception 'nickname_invalid';
    end if;
    if p.nickname is distinct from v_name then
      if p.nickname is not null and not p.nickname_removed then
        if p.nickname_changed_on = v_today and p.nickname_changed_today >= 3 then
          raise exception 'nickname_change_limit';
        end if;
        update public.profiles
        set nickname_changed_today = case
              when nickname_changed_on = v_today then nickname_changed_today + 1 else 1
            end,
            nickname_changed_on = v_today
        where user_id = v_me;
      end if;
      update public.profiles
      set nickname = v_name, nickname_removed = false, updated_at = now()
      where user_id = v_me;
    end if;
  end if;

  if p_avatar_preset is not null then
    if p_avatar_preset not between 1 and 12 then
      raise exception 'not_found';
    end if;
    update public.profiles
    set avatar_preset = p_avatar_preset, updated_at = now()
    where user_id = v_me;
  end if;

  if p_show_in_org_list is not null then
    update public.profiles
    set show_in_org_list = p_show_in_org_list, updated_at = now()
    where user_id = v_me;
  end if;

  return public.friends_my_profile_json(v_me);
end
$$;

-- App 先把 512px 以內的照片傳到 avatars/{user_id}/{毫秒時間戳}.{jpg|png|webp}
-- （副檔名照檔案實際格式），再呼叫這支登記。
create function public.set_avatar_photo(p_path text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  p public.profiles;
  r public.friend_daily_limits;
begin
  select * into p from public.profiles where user_id = v_me for update;
  if p.avatar_upload_banned_until > now() then
    raise exception 'upload_banned';
  end if;
  if p_path is null
     or p_path !~ ('^' || v_me::text || '/[0-9]{10,16}\.(jpg|png|webp)$')
     or not exists (
       select 1 from storage.objects where bucket_id = 'avatars' and name = p_path
     ) then
    raise exception 'not_found';
  end if;
  r := public.friends_limits(v_me);
  if r.uploads >= 5 then
    raise exception 'limit_reached';
  end if;
  update public.friend_daily_limits set uploads = uploads + 1
  where user_id = v_me and day = r.day;
  update public.profiles
  set avatar_path = p_path, updated_at = now()
  where user_id = v_me;
  return public.friends_my_profile_json(v_me);
end
$$;

-- 改回粗哥頭像。舊照片檔留在 Storage（Postgres 刪不了 Storage 的檔），
-- 但 avatars 的讀取政策只放行目前那一張，好友已經簽不出舊照片的網址。
create function public.clear_avatar_photo()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  update public.profiles
  set avatar_path = null, updated_at = now()
  where user_id = v_me;
  return public.friends_my_profile_json(v_me);
end
$$;

-- 「你的照片被移除了」顯示過一次就清掉。暱稱的提示要等他重取名字才消失。
create function public.acknowledge_removals()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  update public.profiles set avatar_removed = false where user_id = v_me;
end
$$;

-- 舊號碼馬上失效；已經送出的邀請不受影響（邀請存的是 user_id）。
create function public.rotate_friend_code()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  loop
    begin
      update public.profiles
      set friend_code = public.friends_new_code(), updated_at = now()
      where user_id = v_me;
      exit;
    exception when unique_violation then
    end;
  end loop;
  return public.friends_my_profile_json(v_me);
end
$$;

-- 好友名單 ─────────────────────────────────────────────────────────

-- 不建 profiles：遊戲大廳的好友卡也會讀，沒用過好友的人就是空名單。
create function public.get_friends()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_uid();
begin
  return coalesce((
    select jsonb_agg(
      public.friends_profile_json(x.other, true) || jsonb_build_object(
        'relation', 'friend',
        'since', x.created_at,
        'last_interaction_at', x.last_interaction_at
      )
      order by x.last_interaction_at desc nulls last, x.created_at desc
    )
    from (
      select case when f.user_low = v_me then f.user_high else f.user_low end as other,
             f.created_at, f.last_interaction_at
      from public.friendships f
      where (f.user_low = v_me or f.user_high = v_me)
        and not public.friends_blocked_either(f.user_low, f.user_high)
    ) x
  ), '[]'::jsonb);
end
$$;

-- 不通知對方；之後雙方都能再走三條路重新加。
create function public.remove_friend(p_other uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  delete from public.friendships
  where user_low = least(v_me, p_other) and user_high = greatest(v_me, p_other);
end
$$;

-- 好友關係立刻解除、雙方之間的邀請全部刪掉。不通知對方。
create function public.block_user(p_other uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  if p_other is null or p_other = v_me
     or not exists (select 1 from public.profiles where user_id = p_other) then
    raise exception 'not_found';
  end if;
  perform public.friends_lock_pair(v_me, p_other);
  insert into public.blocks (blocker, blocked) values (v_me, p_other)
  on conflict do nothing;
  delete from public.friendships
  where user_low = least(v_me, p_other) and user_high = greatest(v_me, p_other);
  delete from public.friend_requests
  where (from_user = v_me and to_user = p_other)
     or (from_user = p_other and to_user = v_me);
end
$$;

-- 解除封鎖不會恢復好友。
create function public.unblock_user(p_other uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  delete from public.blocks where blocker = v_me and blocked = p_other;
end
$$;

create function public.get_blocked()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  return coalesce((
    select jsonb_agg(public.friends_profile_json(b.blocked, false) order by b.created_at desc)
    from public.blocks b
    where b.blocker = v_me
  ), '[]'::jsonb);
end
$$;

-- 找人 ─────────────────────────────────────────────────────────────

-- QR 內容是 SSF1:{token}，5 分鐘內可以給好幾個人掃。
create function public.create_qr_token()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  v_token text := left(encode(sha256(convert_to(
    gen_random_uuid()::text || gen_random_uuid()::text, 'UTF8')), 'hex'), 32);
  v_expires timestamptz := now() + interval '5 minutes';
begin
  delete from public.qr_tokens where expires_at < now() - interval '1 day';
  insert into public.qr_tokens (token, user_id, expires_at)
  values (v_token, v_me, v_expires);
  return jsonb_build_object('token', v_token, 'expires_at', v_expires);
end
$$;

create function public.preview_by_qr(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  v_ref text := public.friends_resolve_qr(v_me, p_token);
begin
  if v_ref in ('not_found', 'qr_expired') then
    return jsonb_build_object('error', v_ref);
  end if;
  -- 記下來：送出時剛好過期，60 秒內照樣算（friends_qr_grace）。
  perform public.friends_limits(v_me);
  update public.friend_daily_limits
  set previewed_codes = previewed_codes || ('qr:' || p_token)
  where user_id = v_me and day = public.friends_today()
    and not (('qr:' || p_token) = any (previewed_codes));
  return public.friends_profile_json(v_ref::uuid, false);
end
$$;

create function public.preview_by_code(p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  v_err text := public.friends_lookup_begin(v_me);
  v_target uuid;
begin
  if v_err is not null then
    return jsonb_build_object('error', v_err);
  end if;
  v_target := public.friends_user_by_code(v_me, p_code);
  perform public.friends_lookup_end(v_me, p_code, v_target is not null);
  if v_target is null then
    return jsonb_build_object('error', 'not_found');
  end if;
  return public.friends_profile_json(v_target, false);
end
$$;

-- p_ref：QR 代碼、好友碼、或同據點名單上那個人的 user_id。
-- 回 {"result": "sent" | "became_friends" | "already_friends"} 或 {"error": …}。
-- 這支整支都用回傳錯誤、不 raise：查號扣掉的次數不能因為後面的錯誤被回滾。
create function public.send_friend_request(p_source text, p_ref text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  v_target uuid;
  v_org uuid;
  v_ref text;
  v_err text;
  v_theirs uuid;
  v_declined_at timestamptz;
begin
  if p_source = 'qr' then
    v_ref := public.friends_resolve_qr(v_me, p_ref);
    if v_ref = 'qr_expired' then
      v_target := public.friends_qr_grace(v_me, p_ref);
      if v_target is null then
        return jsonb_build_object('error', v_ref);
      end if;
    elsif v_ref = 'not_found' then
      return jsonb_build_object('error', v_ref);
    else
      v_target := v_ref::uuid;
    end if;
  elsif p_source = 'code' then
    if public.friends_was_previewed(v_me, p_ref) then
      v_target := public.friends_user_by_code(v_me, p_ref);
    else
      v_err := public.friends_lookup_begin(v_me);
      if v_err is not null then
        return jsonb_build_object('error', v_err);
      end if;
      v_target := public.friends_user_by_code(v_me, p_ref);
      perform public.friends_lookup_end(v_me, p_ref, v_target is not null);
    end if;
  elsif p_source = 'org' then
    if p_ref !~ '^[0-9a-fA-F-]{36}$' then
      return jsonb_build_object('error', 'not_found');
    end if;
    v_target := p_ref::uuid;
    -- 兩人都在、而且他沒關掉「讓同據點的人看到我」的據點。
    select m1.org_id into v_org
    from public.org_members m1
    join public.org_members m2 on m2.org_id = m1.org_id and m2.user_id = v_target
    join public.orgs o on o.id = m1.org_id and o.is_active
    join public.profiles p on p.user_id = v_target and p.show_in_org_list
    where m1.user_id = v_me
    order by m1.joined_at
    limit 1;
    if v_org is null then
      return jsonb_build_object('error', 'not_found');
    end if;
  else
    return jsonb_build_object('error', 'not_found');
  end if;

  if v_target is null or v_target = v_me
     or public.friends_blocked_either(v_me, v_target) then
    return jsonb_build_object('error', 'not_found');
  end if;

  perform public.friends_lock_pair(v_me, v_target);
  perform public.friends_expire_requests(v_me);

  if exists (
    select 1 from public.friendships
    where user_low = least(v_me, v_target) and user_high = greatest(v_me, v_target)
  ) then
    return jsonb_build_object('result', 'already_friends');
  end if;
  if public.friend_count(v_me) >= 100 then
    return jsonb_build_object('error', 'friend_limit');
  end if;

  -- 對方已經邀過我：回邀＝同意。
  select id into v_theirs from public.friend_requests
  where from_user = v_target and to_user = v_me
    and status = 'pending' and expires_at > now();
  if v_theirs is not null then
    if public.friend_count(v_target) >= 100 then
      return jsonb_build_object('error', 'other_friend_limit');
    end if;
    perform public.friends_accept(v_theirs);
    return jsonb_build_object('result', 'became_friends');
  end if;

  -- 已經在等，包括被悄悄拒絕的那封：照樣回 sent，看起來還在等。
  if public.friends_open_out(v_me, v_target) then
    return jsonb_build_object('result', 'sent');
  end if;
  if (
    select count(*) from public.friend_requests
    where from_user = v_me and status in ('pending', 'declined') and expires_at > now()
  ) >= 20 then
    return jsonb_build_object('error', 'pending_limit');
  end if;

  -- 對方 30 天內拒絕過：不回 cooldown（那等於告訴他被拒絕了），照常回 sent，
  -- 但這封直接存成 declined、不送到對方那裡。送的人看到的跟一般邀請一樣
  -- （等回覆 7 天、可以取消、算在 20 封裡），對方完全看不到。
  -- responded_at 沿用原本那次拒絕，冷卻不會因為一直重送而往後延。
  select max(responded_at) into v_declined_at from public.friend_requests
  where from_user = v_me and to_user = v_target
    and status in ('declined', 'cancelled')
    and responded_at > now() - interval '30 days';
  if v_declined_at is not null then
    insert into public.friend_requests
      (from_user, to_user, source, org_id, status, expires_at, responded_at)
    values
      (v_me, v_target, p_source, v_org, 'declined', now() + interval '7 days', v_declined_at);
    return jsonb_build_object('result', 'sent');
  end if;

  insert into public.friend_requests (from_user, to_user, source, org_id, expires_at)
  values (v_me, v_target, p_source, v_org, now() + interval '7 days');
  return jsonb_build_object('result', 'sent');
end
$$;

-- 邀請 ─────────────────────────────────────────────────────────────

-- 不建 profiles：廣場的好友建築紅點每次都會讀。
create function public.get_friend_requests()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_uid();
begin
  perform public.friends_expire_requests(v_me);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id,
      'incoming', r.to_user = v_me,
      'source', r.source,
      'org_name', o.name,
      'created_at', r.created_at,
      'expires_at', r.expires_at,
      'other', public.friends_profile_json(
        case when r.to_user = v_me then r.from_user else r.to_user end, false)
    ) order by r.created_at desc)
    from public.friend_requests r
    left join public.orgs o on o.id = r.org_id
    where r.expires_at > now()
      and (
        (r.to_user = v_me and r.status = 'pending')
        -- 拒絕不通知：送的人那邊照樣顯示在等，到期才消失（規格 3.4）。
        or (r.from_user = v_me and r.status in ('pending', 'declined'))
      )
      and not public.friends_blocked_either(r.from_user, r.to_user)
  ), '[]'::jsonb);
end
$$;

-- p_action：accept／decline／decline_and_block。
create function public.respond_friend_request(p_id uuid, p_action text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  r public.friend_requests;
begin
  select * into r from public.friend_requests
  where id = p_id and to_user = v_me and status = 'pending' and expires_at > now();
  if r.id is null or p_action not in ('accept', 'decline', 'decline_and_block') then
    raise exception 'not_found';
  end if;
  perform public.friends_lock_pair(v_me, r.from_user);
  -- 排隊等到的時候，這封可能已經被取消或被互邀結掉了。
  select * into r from public.friend_requests where id = p_id and status = 'pending';
  if r.id is null then
    raise exception 'not_found';
  end if;

  if p_action = 'accept' then
    if public.friend_count(v_me) >= 100 then
      raise exception 'friend_limit';
    end if;
    if public.friend_count(r.from_user) >= 100 then
      raise exception 'other_friend_limit';
    end if;
    perform public.friends_accept(p_id);
  else
    update public.friend_requests
    set status = 'declined', responded_at = now()
    where id = p_id;
    if p_action = 'decline_and_block' then
      perform public.block_user(r.from_user);
    end if;
  end if;
end
$$;

-- 送的人在「等回覆」裡取消。被拒絕過的那封取消後，30 天冷卻照算（responded_at 還在）。
create function public.cancel_friend_request(p_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  update public.friend_requests
  set status = 'cancelled'
  where id = p_id and from_user = v_me and status in ('pending', 'declined');
  if not found then
    raise exception 'not_found';
  end if;
end
$$;

-- 據點 ─────────────────────────────────────────────────────────────

create function public.preview_org(p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  v_err text := public.friends_lookup_begin(v_me);
  o public.orgs;
begin
  if v_err is not null then
    return jsonb_build_object('error', v_err);
  end if;
  o := public.friends_org_by_code(p_code);
  perform public.friends_lookup_end(v_me, p_code, o.id is not null);
  if o.id is null then
    return jsonb_build_object('error', 'not_found');
  end if;
  return public.friends_org_json(o);
end
$$;

-- 一人最多同時在 3 個（停用的據點不算）。沒預覽過的代碼直接加入也扣查號次數。
create function public.join_org(p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  v_err text;
  o public.orgs;
begin
  if public.friends_was_previewed(v_me, p_code) then
    o := public.friends_org_by_code(p_code);
  else
    v_err := public.friends_lookup_begin(v_me);
    if v_err is not null then
      return jsonb_build_object('error', v_err);
    end if;
    o := public.friends_org_by_code(p_code);
    perform public.friends_lookup_end(v_me, p_code, o.id is not null);
  end if;
  if o.id is null then
    return jsonb_build_object('error', 'not_found');
  end if;

  -- 鎖住自己那列 profiles，同時加兩個據點不會一起超過上限。
  perform 1 from public.profiles where user_id = v_me for update;
  if not exists (select 1 from public.org_members where org_id = o.id and user_id = v_me)
     and (
       select count(*) from public.org_members m
       join public.orgs x on x.id = m.org_id and x.is_active
       where m.user_id = v_me
     ) >= 3 then
    return jsonb_build_object('error', 'org_limit');
  end if;
  insert into public.org_members (org_id, user_id) values (o.id, v_me)
  on conflict do nothing;
  return public.friends_org_json(o);
end
$$;

-- 退出不影響已經加的好友。
create function public.leave_org(p_org_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  delete from public.org_members where org_id = p_org_id and user_id = v_me;
end
$$;

create function public.get_my_orgs()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  return coalesce((
    select jsonb_agg(public.friends_org_json(o) order by m.joined_at)
    from public.org_members m
    join public.orgs o on o.id = m.org_id and o.is_active
    where m.user_id = v_me
  ), '[]'::jsonb);
end
$$;

-- 同據點名單：不含自己、關掉顯示的人、雙方任一方封鎖的人；只給粗哥頭像。
create function public.get_org_members(p_org_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  if not exists (
    select 1 from public.org_members m
    join public.orgs o on o.id = m.org_id and o.is_active
    where m.org_id = p_org_id and m.user_id = v_me
  ) then
    raise exception 'not_found';
  end if;
  perform public.friends_expire_requests(v_me);
  return coalesce((
    select jsonb_agg(
      public.friends_profile_json(m.user_id, false) || jsonb_build_object(
        'status', case
          when exists (
            select 1 from public.friendships
            where user_low = least(v_me, m.user_id) and user_high = greatest(v_me, m.user_id)
          ) then 'friend'
          when public.friends_open_out(v_me, m.user_id) then 'pending_out'
          when exists (
            select 1 from public.friend_requests
            where from_user = m.user_id and to_user = v_me
              and status = 'pending' and expires_at > now()
          ) then 'pending_in'
          else 'none'
        end
      )
      order by m.joined_at
    )
    from public.org_members m
    join public.profiles p on p.user_id = m.user_id
    where m.org_id = p_org_id
      and m.user_id <> v_me
      and p.show_in_org_list
      and not public.friends_blocked_either(v_me, m.user_id)
  ), '[]'::jsonb);
end
$$;

-- 檢舉 ─────────────────────────────────────────────────────────────

-- 一天 10 次。檢舉的人不會被告知結果，被檢舉的人不會知道是誰。
create function public.report_profile(p_target uuid, p_kind text, p_reason text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  p public.profiles;
  r public.friend_daily_limits;
begin
  select * into p from public.profiles where user_id = p_target;
  if p.user_id is null or p_target = v_me
     or public.friends_blocked_either(v_me, p_target)
     or p_kind not in ('photo', 'nickname')
     or p_reason not in ('indecent', 'violent', 'impersonation', 'ads', 'other') then
    raise exception 'not_found';
  end if;
  r := public.friends_limits(v_me);
  if r.reports >= 10 then
    raise exception 'limit_reached';
  end if;
  update public.friend_daily_limits set reports = reports + 1
  where user_id = v_me and day = r.day;
  insert into public.profile_reports (reporter, target_user, kind, snapshot, reason)
  values (
    v_me, p_target, p_kind,
    case when p_kind = 'photo' then p.avatar_path else p.nickname end,
    p_reason
  );
end
$$;

-- ── avatars bucket（私有）──────────────────────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- 上傳：只能放自己的資料夾；停權中或今天已經傳 5 張就擋。
create function public.avatar_upload_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and not exists (
      select 1 from public.profiles
      where user_id = auth.uid() and avatar_upload_banned_until > now()
    )
    and (
      select count(*) from storage.objects
      where bucket_id = 'avatars'
        -- 寫成前綴比對，(bucket_id, name) 的索引用得上；uuid 裡沒有 % 或 _。
        and name like auth.uid()::text || '/%'
        and created_at >= (public.friends_today()::timestamp at time zone 'Asia/Taipei')
    ) < 5
$$;

-- 讀取（含簽網址）：自己的資料夾，或好友「目前」那一張照片。
-- 非好友、換掉的舊照片、被抽掉的照片都簽不出網址。
create function public.can_read_avatar(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and (
    p_name like auth.uid()::text || '/%'
    or exists (
      select 1 from public.profiles p
      where p.avatar_path = p_name and public.is_my_friend(p.user_id)
    )
  )
$$;

create policy "avatars: upload to own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and name like (select auth.uid())::text || '/%'
    and public.avatar_upload_allowed()
  );

create policy "avatars: own folder or a friend's current photo" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and public.can_read_avatar(name));

-- ── 執行權 ──────────────────────────────────────────────────────────
-- Supabase 預設把 public 的新函式開給 anon、authenticated；這裡全部收回再逐支開。

revoke execute on function
  public.friends_today(),
  public.friends_new_code(),
  public.friends_me(),
  public.friends_uid(),
  public.friends_blocked_either(uuid, uuid),
  public.friends_lock_pair(uuid, uuid),
  public.friends_profile_json(uuid, boolean),
  public.friends_my_profile_json(uuid),
  public.friends_expire_requests(uuid),
  public.friends_open_out(uuid, uuid),
  public.friends_accept(uuid),
  public.friends_limits(uuid),
  public.friends_lookup_begin(uuid),
  public.friends_lookup_end(uuid, text, boolean),
  public.friends_was_previewed(uuid, text),
  public.friends_user_by_code(uuid, text),
  public.friends_org_by_code(text),
  public.friends_resolve_qr(uuid, text),
  public.friends_qr_grace(uuid, text),
  public.friends_org_json(public.orgs),
  public.friends_clean_nickname(text),
  public.are_friends(uuid, uuid, boolean),
  public.friend_count(uuid),
  public.touch_friendship(uuid, uuid),
  public.is_my_friend(uuid),
  public.get_my_profile(),
  public.update_profile(text, integer, boolean),
  public.set_avatar_photo(text),
  public.clear_avatar_photo(),
  public.acknowledge_removals(),
  public.rotate_friend_code(),
  public.get_friends(),
  public.remove_friend(uuid),
  public.block_user(uuid),
  public.unblock_user(uuid),
  public.get_blocked(),
  public.create_qr_token(),
  public.preview_by_qr(text),
  public.preview_by_code(text),
  public.send_friend_request(text, text),
  public.get_friend_requests(),
  public.respond_friend_request(uuid, text),
  public.cancel_friend_request(uuid),
  public.preview_org(text),
  public.join_org(text),
  public.leave_org(uuid),
  public.get_my_orgs(),
  public.get_org_members(uuid),
  public.report_profile(uuid, text, text),
  public.avatar_upload_allowed(),
  public.can_read_avatar(text)
from public, anon, authenticated;

grant execute on function
  public.is_my_friend(uuid),
  public.get_my_profile(),
  public.update_profile(text, integer, boolean),
  public.set_avatar_photo(text),
  public.clear_avatar_photo(),
  public.acknowledge_removals(),
  public.rotate_friend_code(),
  public.get_friends(),
  public.remove_friend(uuid),
  public.block_user(uuid),
  public.unblock_user(uuid),
  public.get_blocked(),
  public.create_qr_token(),
  public.preview_by_qr(text),
  public.preview_by_code(text),
  public.send_friend_request(text, text),
  public.get_friend_requests(),
  public.respond_friend_request(uuid, text),
  public.cancel_friend_request(uuid),
  public.preview_org(text),
  public.join_org(text),
  public.leave_org(uuid),
  public.get_my_orgs(),
  public.get_org_members(uuid),
  public.report_profile(uuid, text, text),
  -- storage 政策以呼叫者身分執行，要有執行權。
  public.avatar_upload_allowed(),
  public.can_read_avatar(text)
to authenticated;

commit;
