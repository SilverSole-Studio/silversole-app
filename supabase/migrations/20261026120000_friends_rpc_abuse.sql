-- supabase/migrations/20261026120000_friends_rpc_abuse.sql
--
-- 好友系統：修技術長 2026-10-26 藍隊核查找到的 RPC 濫用（接在 20261019120000_friends.sql 後面）。
--
-- 狀態：未套用到任何 Supabase 專案。套用前先問 user；並發的情境（4、6、8）PGlite 測不到，
--   要在 Supabase 分支用多連線打一次（supabase/README.md「並發驗證」）。
--
-- 原則：一律假設對方拿自己的 token 直接打 API、會同時送一堆請求、會開分身。
--   - 額度的「檢查」和「扣次數」在同一把「這個人」的鎖裡做（不是只鎖一對）。
--   - 懲罰與冷卻紀錄獨立存，封鎖、取消、刪好友都刪不掉。
--   - 會寫資料的 RPC 都有頻率上限，而且每人能留下的列數有天花板。
--
-- 對應核查的 8 點：
--   1 封鎖洗掉拒絕冷卻      → friend_cooldowns 表；block_user 不再刪邀請，只把等待中的改成 cancelled
--   2 QR token 無限產生      → 5 分鐘內有效的直接重用；每人只留還在寬限內的幾筆；另扣限流
--   3 送→取消→再送不算額度   → 每天送出 30 封（含取消、含暫扣）；取消後 24 小時內再送同一人一律暫扣、對方看不到
--   4 大頭貼上傳並發穿過上限 → 上傳政策先鎖人再扣次數；資料夾總數上限 10 張；可以刪自己的舊照片
--   5 檢舉轟炸              → 同一人對同一人同一類一天只算一筆；檢舉人帳號要滿 3 天；被檢舉人一天最多收 30 筆
--   6 並發寄給 200 個人      → 送邀請、回覆、封鎖先依 user_id 順序鎖兩個人，再算上限
--   7 暱稱隱形字、反向字、冒充 → NFKC 正規化＋逐字白名單；保留名（含「銀足朋友」）不能取
--   8 沒有全域限流            → friend_rate_buckets 每人一個 token bucket，每支 RPC 第一行扣；同一人的呼叫排隊

begin;

-- ── 8：每人限流（token bucket）──────────────────────────────────────────
-- 容量 30、每秒回 0.5（一分鐘 30 次）。一般呼叫扣 1，會寫資料或比較貴的另外多扣。
-- 列鎖住到交易結束，同一個人同時打的 RPC 會排隊一支一支跑。

create table public.friend_rate_buckets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tokens real not null,
  updated_at timestamptz not null default now()
);
alter table public.friend_rate_buckets enable row level security;
revoke all on public.friend_rate_buckets from anon, authenticated;

create function public.friends_take(p_me uuid, p_cost real)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_cap constant real := 30;
  c_rate constant real := 0.5;
  v_left real;
begin
  insert into public.friend_rate_buckets (user_id, tokens, updated_at)
  values (p_me, c_cap, now())
  on conflict (user_id) do nothing;
  update public.friend_rate_buckets
  set tokens = least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) - p_cost,
      updated_at = now()
  where user_id = p_me
    and least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) >= p_cost
  returning tokens into v_left;
  if v_left is null then
    raise exception 'rate_limited';
  end if;
end
$$;

-- 每支 App RPC 的第一行都是 friends_me() 或 friends_uid()，限流放在這兩支裡。
create or replace function public.friends_me()
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
  perform public.friends_take(v_me, 1);
  if not exists (select 1 from public.profiles where user_id = v_me) then
    loop
      begin
        insert into public.profiles (user_id, friend_code)
        values (v_me, public.friends_new_code())
        on conflict (user_id) do nothing;
        exit;
      exception when unique_violation then
      end;
    end loop;
  end if;
  return v_me;
end
$$;

-- 原本是 stable；要扣限流就得改成 volatile（呼叫它的 get_friends、get_friend_requests 本來就是 volatile）。
create or replace function public.friends_uid()
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
  perform public.friends_take(v_me, 1);
  return v_me;
end
$$;

-- ── 6：鎖「人」不是只鎖「一對」──────────────────────────────────────────
-- 兩個人都鎖，依 user_id 大小順序，兩邊同時互動也不會死結。
-- 「我」的 20 封、100 位上限在這把鎖裡算，同時寄給不同的人也會排隊。

create function public.friends_lock_user(u uuid)
returns void
language sql
volatile
set search_path = ''
as $$
  select pg_advisory_xact_lock(hashtextextended('friends-user:' || u::text, 0))
$$;

create or replace function public.friends_lock_pair(a uuid, b uuid)
returns void
language plpgsql
volatile
set search_path = ''
as $$
begin
  perform public.friends_lock_user(least(a, b));
  if a <> b then
    perform public.friends_lock_user(greatest(a, b));
  end if;
end
$$;

-- ── 1、3：冷卻紀錄獨立存 ───────────────────────────────────────────────
-- 「from_user 在 until 之前送給 to_user 的邀請，一律暫扣、對方看不到」。
-- 封鎖、解除封鎖、刪好友、取消邀請都不會刪這張表；只有帳號刪掉才跟著刪。

create table public.friend_cooldowns (
  from_user uuid not null references public.profiles (user_id) on delete cascade,
  to_user uuid not null references public.profiles (user_id) on delete cascade,
  until timestamptz not null,
  reason text not null check (reason in ('declined', 'cancelled')),
  primary key (from_user, to_user),
  check (from_user <> to_user)
);
alter table public.friend_cooldowns enable row level security;
revoke all on public.friend_cooldowns from anon, authenticated;

-- 舊資料：30 天內被拒絕過的補進來。
insert into public.friend_cooldowns (from_user, to_user, until, reason)
select from_user, to_user, max(responded_at) + interval '30 days', 'declined'
from public.friend_requests
where status in ('declined', 'cancelled')
  and responded_at > now() - interval '30 days'
group by from_user, to_user
on conflict (from_user, to_user) do nothing;

create function public.friends_cool(p_from uuid, p_to uuid, p_for interval, p_reason text)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.friend_cooldowns (from_user, to_user, until, reason)
  values (p_from, p_to, now() + p_for, p_reason)
  on conflict (from_user, to_user) do update
  set until = greatest(public.friend_cooldowns.until, excluded.until),
      reason = case
        when excluded.until > public.friend_cooldowns.until then excluded.reason
        else public.friend_cooldowns.reason
      end
$$;

create function public.friends_cooling(p_from uuid, p_to uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friend_cooldowns
    where from_user = p_from and to_user = p_to and until > now()
  )
$$;

-- ── 7：暱稱 ─────────────────────────────────────────────────────────────
-- 先 NFKC（全形英數、相容字、拆開的注音聲調都收成標準寫法），拿掉 emoji 的變體選擇符，
-- 再逐字比白名單：每一個字都要是字母、數字、空白或幾個常用符號。零寬字、雙向控制字、
-- 組合記號、私用區都不在白名單裡，自然擋掉。保留名比對的是去空白、去符號、小寫後的結果。

create table public.friend_reserved_names (
  key text primary key,
  -- true：名字裡只要含這段就不行；false：整個名字等於這段才不行。
  contains boolean not null default true
);
alter table public.friend_reserved_names enable row level security;
revoke all on public.friend_reserved_names from anon, authenticated;

insert into public.friend_reserved_names (key, contains) values
  ('銀足', true),
  ('silversole', true),
  ('官方', true),
  ('客服', true),
  ('管理員', true),
  ('管理者', true),
  ('系統', true),
  ('動域', true),
  ('admin', true),
  ('support', true),
  ('粗哥', false)
on conflict (key) do nothing;

create or replace function public.friends_clean_nickname(p_raw text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v text;
  v_key text;
begin
  v := normalize(coalesce(p_raw, ''), NFKC);
  v := regexp_replace(v, '[\uFE0E\uFE0F]', '', 'g');
  v := regexp_replace(v, '^[\s　]+|[\s　]+$', '', 'g');
  if char_length(v) not between 2 and 8 then
    return null;
  end if;
  -- 逐字白名單：拉丁、希臘、西里爾、泰、假名、注音、中日韓、韓文、數字、
  -- 中間的一般空白、幾個常用符號，和單一碼位的 emoji（不含 ZWJ 組合）。
  if v !~ ('^(?:[0-9A-Za-zÀ-ɏͰ-ϿЀ-ӿ฀-๿぀-ヿ㄀-ㄯ㐀-䶿一-鿿가-힯豈-﫿 ·・\-_.~～!！?？♥♡★☆]'
           || '|[\U0001F300-\U0001FAFF\u2600-\u27BF])+$') then
    return null;
  end if;
  if v !~ '[0-9A-Za-zÀ-ɏͰ-ϿЀ-ӿ฀-๿぀-ヿ㄀-ㄯ㐀-䶿一-鿿가-힯豈-﫿]' then
    return null;
  end if;
  if v ~ '  ' then
    return null;
  end if;
  v_key := lower(regexp_replace(v, '[ ·・\-_.~～!！?？♥♡★☆]', '', 'g'));
  if exists (
    select 1 from public.friend_reserved_names r
    where (r.contains and strpos(v_key, r.key) > 0) or (not r.contains and v_key = r.key)
  ) then
    return null;
  end if;
  return v;
end
$$;

-- ── 2：QR token ─────────────────────────────────────────────────────────
-- 還有 60 秒以上才過期的那張直接回同一張；要新的才產生，而且順手刪掉自己已經過了
-- 寬限（過期 60 秒）的舊 token。一個人同時留在表裡的最多兩三筆。

create or replace function public.create_qr_token()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  t public.qr_tokens;
  v_token text;
  v_expires timestamptz := now() + interval '5 minutes';
begin
  perform public.friends_lock_user(v_me);
  select * into t from public.qr_tokens
  where user_id = v_me and expires_at > now() + interval '60 seconds'
  order by expires_at desc
  limit 1;
  if t.token is not null then
    return jsonb_build_object('token', t.token, 'expires_at', t.expires_at);
  end if;
  perform public.friends_take(v_me, 4);
  delete from public.qr_tokens
  where user_id = v_me and expires_at < now() - interval '60 seconds';
  delete from public.qr_tokens where expires_at < now() - interval '1 day';
  v_token := left(encode(sha256(convert_to(
    gen_random_uuid()::text || gen_random_uuid()::text, 'UTF8')), 'hex'), 32);
  insert into public.qr_tokens (token, user_id, expires_at)
  values (v_token, v_me, v_expires);
  return jsonb_build_object('token', v_token, 'expires_at', v_expires);
end
$$;

-- ── 1：封鎖不再刪紀錄 ───────────────────────────────────────────────────
-- 等待中的邀請改成 cancelled（雙方都看不到）；拒絕過的、冷卻表都留著。
-- 解除封鎖之後，拒絕當時的 30 天冷卻照算。

create or replace function public.block_user(p_other uuid)
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
  update public.friend_requests
  set status = 'cancelled'
  where status = 'pending'
    and ((from_user = v_me and to_user = p_other)
      or (from_user = p_other and to_user = v_me));
end
$$;

create or replace function public.unblock_user(p_other uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  perform public.friends_take(v_me, 2);
  delete from public.blocks where blocker = v_me and blocked = p_other;
end
$$;

-- ── 1、3、6：送邀請 ──────────────────────────────────────────────────────

create or replace function public.send_friend_request(p_source text, p_ref text)
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
  v_day_start timestamptz := public.friends_today()::timestamp at time zone 'Asia/Taipei';
begin
  perform public.friends_take(v_me, 2);
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

  -- 先鎖兩個人（我、對方），下面所有上限都在鎖裡算。
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

  if public.friends_open_out(v_me, v_target) then
    return jsonb_build_object('result', 'sent');
  end if;
  if (
    select count(*) from public.friend_requests
    where from_user = v_me and status in ('pending', 'declined') and expires_at > now()
  ) >= 20 then
    return jsonb_build_object('error', 'pending_limit');
  end if;
  -- 3：今天送出的（含已取消、含暫扣）滿 30 封就停。取消不會把次數還回來。
  if (
    select count(*) from public.friend_requests
    where from_user = v_me and created_at >= v_day_start
  ) >= 30 then
    return jsonb_build_object('error', 'send_limit');
  end if;

  -- 1、3：被拒絕 30 天內、或自己取消 24 小時內：照常回 sent，存成暫扣、對方看不到。
  if public.friends_cooling(v_me, v_target) then
    select max(responded_at) into v_declined_at from public.friend_requests
    where from_user = v_me and to_user = v_target
      and status in ('declined', 'cancelled')
      and responded_at > now() - interval '30 days';
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

-- 拒絕時寫進冷卻表（封鎖洗不掉）。
create or replace function public.respond_friend_request(p_id uuid, p_action text)
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
    perform public.friends_cool(r.from_user, v_me, interval '30 days', 'declined');
    if p_action = 'decline_and_block' then
      perform public.block_user(r.from_user);
    end if;
  end if;
end
$$;

-- 3：取消一封真的送到對方那裡的邀請 → 24 小時內再送同一人一律暫扣。
create or replace function public.cancel_friend_request(p_id uuid)
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
  where id = p_id and from_user = v_me and status in ('pending', 'declined');
  if r.id is null then
    raise exception 'not_found';
  end if;
  perform public.friends_lock_pair(v_me, r.to_user);
  update public.friend_requests
  set status = 'cancelled'
  where id = p_id and status in ('pending', 'declined');
  if not found then
    raise exception 'not_found';
  end if;
  if r.status = 'pending' then
    perform public.friends_cool(v_me, r.to_user, interval '24 hours', 'cancelled');
  end if;
end
$$;

-- ── 8：其他會寫資料的 RPC 多扣一點 ────────────────────────────────────────

create or replace function public.rotate_friend_code()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  perform public.friends_take(v_me, 9);
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

-- ── 4：大頭貼 ───────────────────────────────────────────────────────────
-- 上傳政策（storage.objects 的 insert）先鎖這個人，再用計數列扣次數：同時 50 個上傳
-- 會一個一個排隊，第 6 個起被擋。另外整個資料夾最多 10 張（換照片時 App 會刪舊的），
-- 就算有人一直傳一直不登記，能佔的空間也有上限。被擋的上傳整筆回滾，次數也不會扣。

alter table public.friend_daily_limits
  add column if not exists storage_uploads integer not null default 0;

create or replace function public.avatar_upload_allowed()
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  r public.friend_daily_limits;
begin
  if v_me is null or not exists (select 1 from public.profiles where user_id = v_me) then
    return false;
  end if;
  perform public.friends_lock_user(v_me);
  if exists (
    select 1 from public.profiles
    where user_id = v_me and avatar_upload_banned_until > now()
  ) then
    return false;
  end if;
  if (
    select count(*) from storage.objects
    where bucket_id = 'avatars' and name like v_me::text || '/%'
  ) >= 10 then
    return false;
  end if;
  r := public.friends_limits(v_me);
  if r.storage_uploads >= 5 then
    return false;
  end if;
  update public.friend_daily_limits set storage_uploads = storage_uploads + 1
  where user_id = v_me and day = r.day;
  return true;
end
$$;

-- 自己資料夾裡「不是目前那一張」的舊照片可以刪（換照片後 App 刪掉舊的）。
create function public.can_delete_avatar(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and p_name like auth.uid()::text || '/%'
    and not exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.avatar_path = p_name
    )
$$;

create policy "avatars: delete own old photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and public.can_delete_avatar(name));

-- ── 5：檢舉 ─────────────────────────────────────────────────────────────
-- - 檢舉人要取好名字、帳號滿 3 天。
-- - 同一人對同一人、同一類，還沒處理的只留一筆（再按一次照樣回成功，但不多記）。
-- - 被檢舉人一天最多新增 30 筆；超過的照樣回成功、不記（中控台看「幾個不同的人」就夠判斷）。
-- 檢舉人自己的一天 10 次照舊。

create or replace function public.report_profile(p_target uuid, p_kind text, p_reason text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  me public.profiles;
  p public.profiles;
  r public.friend_daily_limits;
begin
  perform public.friends_take(v_me, 2);
  select * into p from public.profiles where user_id = p_target;
  if p.user_id is null or p_target = v_me
     or public.friends_blocked_either(v_me, p_target)
     or p_kind not in ('photo', 'nickname')
     or p_reason not in ('indecent', 'violent', 'impersonation', 'ads', 'other') then
    raise exception 'not_found';
  end if;
  -- 兩個人一起鎖（依 user_id 順序），互相檢舉也不會死結。
  perform public.friends_lock_pair(v_me, p_target);
  r := public.friends_limits(v_me);
  if r.reports >= 10 then
    raise exception 'limit_reached';
  end if;
  update public.friend_daily_limits set reports = reports + 1
  where user_id = v_me and day = r.day;

  select * into me from public.profiles where user_id = v_me;
  if me.nickname is null or me.created_at > now() - interval '3 days' then
    return;
  end if;
  if exists (
    select 1 from public.profile_reports
    where reporter = v_me and target_user = p_target and kind = p_kind and handled_at is null
  ) then
    return;
  end if;
  if (
    select count(*) from public.profile_reports
    where target_user = p_target and created_at > now() - interval '1 day'
  ) >= 30 then
    return;
  end if;
  insert into public.profile_reports (reporter, target_user, kind, snapshot, reason)
  values (
    v_me, p_target, p_kind,
    case when p_kind = 'photo' then p.avatar_path else p.nickname end,
    p_reason
  );
end
$$;

-- ── 執行權 ──────────────────────────────────────────────────────────────

revoke execute on function
  public.friends_take(uuid, real),
  public.friends_lock_user(uuid),
  public.friends_cool(uuid, uuid, interval, text),
  public.friends_cooling(uuid, uuid),
  public.can_delete_avatar(text)
from public, anon, authenticated;

-- create or replace 不會改執行權，原本 grant 給 authenticated 的照舊；
-- storage 政策以呼叫者身分執行，要有執行權。
grant execute on function public.can_delete_avatar(text) to authenticated;

commit;
