-- supabase/migrations/20261109120000_friend_share_link.sql
--
-- *** 狀態：未套用到任何 Supabase 專案。套用前先問 user（同意後才能套）。 ***
-- 要先套好 20261019120000_friends.sql、20261026120000_friends_rpc_abuse.sql、
-- 20261105120000_friend_suggest.sql（這支會重寫它的 send_friend_request，保留 'online' 那段）。
--
-- 社群連結加好友（GitHub issue #40）：好友頁按「傳連結給朋友」→ 手機分享選單 → LINE／FB／簡訊。
-- 朋友點 https://dongyu.company/f/?t=<token>：有裝 App 就開銀足，看到暱稱與頭像，按了才送邀請，
-- 對方同意才成為好友。這支只管資料庫那一半。
--
-- 規則（全部在伺服器擋，不信 App）：
--   - 連結 7 天有效。
--   - 一人同時只有一條有效連結：friend_share_links 以 user_id 為主鍵，一人一列；
--     還有效就回同一條，過期或被停用才換新的 token（舊 token 當場作廢）。
--   - 可以停用（disable_share_link）；停用後舊連結失效，可以重新產生。
--   - 每人每天最多收到 10 封「透過連結」送來的邀請。計數存在 friend_link_inbox（算在收件人身上），
--     停用、換連結、取消邀請、刪邀請都洗不掉。
--   - 陌生人點到連結只拿到 {user_id, nickname, avatar_preset}，沒有照片路徑、好友碼、好友數。
--   - 封鎖的人（任一方向）、自己的連結：一律 not_found。
--
-- RPC 濫用自查（feedback_rpc_abuse_checklist）：
--   1 對方拿自己的 token 直接打 API：全部規則都在 RPC 裡，App 不算數。token 是 32 位十六進位
--     （兩個 gen_random_uuid 的 sha256），猜不到；預覽與送出都先扣每人限流。
--   2 並發：create_share_link 先鎖「人」再判斷有沒有有效連結；送邀請沿用 friends_lock_pair
--     （鎖「我」和「收件人」兩個人），收件匣計數在鎖裡用 upsert + where received < 10 原子增加。
--   3 開分身：10 封算在「收件人」身上，一百個分身一起轟炸同一個人也只進 10 封；收件人隨時可以停用連結。
--     寄件端沿用原本每天 30 封、未回覆 20 封、被拒絕 30 天暫扣。
--   4 懲罰紀錄不被洗掉：計數與冷卻都獨立存（friend_link_inbox、friend_cooldowns），
--     停用、重新產生、取消、封鎖都不會動它們。被冷卻的邀請照舊「回 sent、暫扣」，也不占收件人的 10 封。
--   5 列數天花板：friend_share_links 一人一列；friend_link_inbox 每人每天一列，寫入時順手刪掉 2 天前的。
--   6 資料表 RLS 開、不給 anon／authenticated 任何權限；RPC 都是 security definer、set search_path = ''、
--     只 grant authenticated。
--
-- 另外：friend_requests.source、friendships.source 的 check 多收 'link'。

begin;

alter table public.friend_requests drop constraint friend_requests_source_check;
alter table public.friend_requests add constraint friend_requests_source_check
  check (source in ('qr', 'code', 'org', 'online', 'link'));
alter table public.friendships drop constraint friendships_source_check;
alter table public.friendships add constraint friendships_source_check
  check (source in ('qr', 'code', 'org', 'online', 'link'));

-- ── 資料表 ────────────────────────────────────────────────────────────

-- 一人一列。token 換新就是整列覆蓋，所以舊連結自然作廢。
create table public.friend_share_links (
  user_id uuid primary key references public.profiles (user_id) on delete cascade,
  token text not null unique check (token ~ '^[0-9a-f]{32}$'),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  disabled_at timestamptz
);
alter table public.friend_share_links enable row level security;
revoke all on public.friend_share_links from anon, authenticated;

-- 收件人每天「透過連結」收到幾封（含之後被取消的）。獨立存，沒有任何動作會把它減回去。
create table public.friend_link_inbox (
  user_id uuid not null references public.profiles (user_id) on delete cascade,
  day date not null,
  received integer not null default 0 check (received >= 0),
  primary key (user_id, day)
);
alter table public.friend_link_inbox enable row level security;
revoke all on public.friend_link_inbox from anon, authenticated;

-- ── 內部小工具（不開放給 App）────────────────────────────────────────

-- token → 連結主人的 user id（文字）。不認得、自己的、有封鎖關係：'not_found'；
-- 停用或過期：'link_expired'。
create function public.friends_share_link_target(p_me uuid, p_token text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_token text := lower(btrim(coalesce(p_token, '')));
  l public.friend_share_links;
begin
  if v_token !~ '^[0-9a-f]{32}$' then
    return 'not_found';
  end if;
  select * into l from public.friend_share_links where token = v_token;
  if l.token is null or l.user_id = p_me
     or public.friends_blocked_either(p_me, l.user_id) then
    return 'not_found';
  end if;
  if l.disabled_at is not null or l.expires_at <= now() then
    return 'link_expired';
  end if;
  return l.user_id::text;
end
$$;
revoke all on function public.friends_share_link_target(uuid, text) from public, anon, authenticated;

-- ── App 呼叫的 RPC ───────────────────────────────────────────────────

-- 我的連結。還有效就回同一條；過期、被停用或還沒有才產生新的（7 天）。
create function public.create_share_link()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  l public.friend_share_links;
  v_token text;
  v_expires timestamptz := now() + interval '7 days';
begin
  perform public.friends_lock_user(v_me);
  if not exists (
    select 1 from public.profiles where user_id = v_me and nickname is not null
  ) then
    return jsonb_build_object('error', 'nickname_invalid');
  end if;
  select * into l from public.friend_share_links where user_id = v_me;
  if l.token is not null and l.disabled_at is null and l.expires_at > now() then
    return jsonb_build_object('token', l.token, 'expires_at', l.expires_at);
  end if;
  perform public.friends_take(v_me, 4);
  v_token := left(encode(sha256(convert_to(
    gen_random_uuid()::text || gen_random_uuid()::text, 'UTF8')), 'hex'), 32);
  insert into public.friend_share_links (user_id, token, created_at, expires_at, disabled_at)
  values (v_me, v_token, now(), v_expires, null)
  on conflict (user_id) do update
  set token = excluded.token,
      created_at = excluded.created_at,
      expires_at = excluded.expires_at,
      disabled_at = null;
  return jsonb_build_object('token', v_token, 'expires_at', v_expires);
end
$$;

-- 目前有沒有有效的連結（好友頁決定要不要顯示「停用」）。
create function public.get_share_link()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_uid();
  l public.friend_share_links;
begin
  select * into l from public.friend_share_links where user_id = v_me;
  if l.token is null or l.disabled_at is not null or l.expires_at <= now() then
    return jsonb_build_object('active', false);
  end if;
  return jsonb_build_object('active', true, 'token', l.token, 'expires_at', l.expires_at);
end
$$;

-- 停用。沒有連結或已停用也回 ok（重複按不報錯）。已經送出去的邀請不受影響。
create function public.disable_share_link()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
begin
  perform public.friends_lock_user(v_me);
  update public.friend_share_links
  set disabled_at = now()
  where user_id = v_me and disabled_at is null;
  return jsonb_build_object('ok', true);
end
$$;

-- 點連結的人先看到誰。陌生人只拿到暱稱與預設頭像（跟 QR、好友碼預覽一樣，不給照片路徑）。
-- 已經是好友的多帶 already_friends，App 就不用再問「要不要加」。
create function public.preview_by_share_link(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  v_ref text;
begin
  perform public.friends_take(v_me, 1);
  v_ref := public.friends_share_link_target(v_me, p_token);
  if v_ref in ('not_found', 'link_expired') then
    return jsonb_build_object('error', v_ref);
  end if;
  if exists (
    select 1 from public.friendships
    where user_low = least(v_me, v_ref::uuid) and user_high = greatest(v_me, v_ref::uuid)
  ) then
    return public.friends_profile_json(v_ref::uuid, false)
      || jsonb_build_object('already_friends', true);
  end if;
  return public.friends_profile_json(v_ref::uuid, false);
end
$$;

-- ── send_friend_request：跟 20261105120000_friend_suggest.sql 一樣，只多 'link' 這一段與收件匣計數 ──
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
  v_link_got integer;
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
  elsif p_source = 'online' then
    -- 交友建議：p_ref 是 mp_suggest_online 發給「我」的短代碼（30 分鐘內有效），不是對方的 user id。
    -- 對方要還開著「讓別人推薦我」。所以只能加「真的被推薦給我」的人，拿別人的 id 來亂加不行。
    select s.other into v_target
    from public.friend_suggest_shown s
    join public.profiles p on p.user_id = s.other and p.suggest_me
    where s.user_id = v_me and s.ref = p_ref and s.shown_at > now() - interval '30 minutes';
    if v_target is null then
      return jsonb_build_object('error', 'not_found');
    end if;
  elsif p_source = 'link' then
    -- 分享連結：p_ref 是對方的連結 token（32 位十六進位）。連結過期、被停用回 link_expired，
    -- 不認得的 token、自己的連結、有封鎖關係的回 not_found。
    v_ref := public.friends_share_link_target(v_me, p_ref);
    if v_ref in ('not_found', 'link_expired') then
      return jsonb_build_object('error', v_ref);
    end if;
    v_target := v_ref::uuid;
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

  -- 透過連結送來的邀請，每個收件人每天最多 10 封（算在收件人身上、獨立存，
  -- 取消、換連結、刪邀請都洗不掉）。計數和下面的 insert 在同一個交易、同一把「收件人」的鎖裡。
  if p_source = 'link' then
    insert into public.friend_link_inbox as i (user_id, day, received)
    values (v_target, public.friends_today(), 1)
    on conflict (user_id, day) do update set received = i.received + 1
    where i.received < 10
    returning i.received into v_link_got;
    if v_link_got is null then
      return jsonb_build_object('error', 'link_limit');
    end if;
    delete from public.friend_link_inbox
    where user_id = v_target and day < public.friends_today() - 2;
  end if;

  insert into public.friend_requests (from_user, to_user, source, org_id, expires_at)
  values (v_me, v_target, p_source, v_org, now() + interval '7 days');
  return jsonb_build_object('result', 'sent');
end
$$;
revoke all on function public.create_share_link() from public, anon;
revoke all on function public.get_share_link() from public, anon;
revoke all on function public.disable_share_link() from public, anon;
revoke all on function public.preview_by_share_link(text) from public, anon;
grant execute on function public.create_share_link() to authenticated;
grant execute on function public.get_share_link() to authenticated;
grant execute on function public.disable_share_link() to authenticated;
grant execute on function public.preview_by_share_link(text) to authenticated;

commit;
