-- supabase/migrations/20261105120000_friend_suggest.sql
--
-- *** 2026-11-05 已套用到正式庫（user 同意；先在交易裡試套、跑完整流程後還原，再正式套）。 ***
-- 要先套好 20261019120000_friends.sql、20261026120000_friends_rpc_abuse.sql、
-- 20261103120000_mp_rooms.sql（mp_take）、20261104180000_mp_presence.sql（mp_presence）。
--
-- user 2026-11-05：「我覺得要做交友建議」→ 推薦「現在在線上的人」、放在小鎮交誼廳、
-- 玩家可以關「讓別人推薦我」（預設開）。
--
-- 做了什麼：
--   - profiles 加 suggest_me（預設 true）。關掉的人不會被推薦，自己也看不到推薦名單（公平：
--     不想被看到的人也不能只看別人）。
--   - mp_suggest_online()：回最多 8 位「90 秒內在線、不是好友、雙方沒封鎖、對方開著 suggest_me、
--     有暱稱、彼此沒有還開著的邀請、我沒按過『不要』、不在被拒絕冷卻期」的人。
--     每筆只有 {ref, name, avatar}：ref 是發給我的 12 碼短代碼（存在 friend_suggest_shown，
--     30 分鐘內有效），不回對方 user id、好友碼、照片路徑。
--     排序：同一天同一個人看到的順序固定（不會每次刷新都跳），隔天換一批。
--   - send_friend_request 多一種來源 'online'：p_ref 用上面那個短代碼，只認發給自己、30 分鐘內、
--     對方還開著 suggest_me 的。其他上限（每天 30 封、未回覆 20 封、被拒 30 天暫扣、好友 100 人）
--     全部照舊，所以拿推薦名單狂發邀請一樣會被擋。
--   - friend_requests.source、friendships.source 的 check 多收 'online'。
--     App 讀到不認得的來源會當成 code（supabase_friends_repository.dart _source 的 orElse），不會壞。
--   - mp_suggest_hide(p_ref)：按「不要」，30 天內不再推薦這個人給我。
--   - mp_suggest_set(p_on)：開關「讓別人推薦我」。
--
-- RPC 濫用自查：每支先 mp_take（推薦名單花 3、其他花 1）；不 raise、回 jsonb {ok, reason}；
-- security definer、set search_path = ''、只 grant authenticated。新表 RLS 開、不給 App 直接讀寫。
-- 被推薦的人只透露「現在在線上」與暱稱、預設頭像，而且只有本人沒關推薦時才會。

begin;

alter table public.profiles add column suggest_me boolean not null default true;

alter table public.friend_requests drop constraint friend_requests_source_check;
alter table public.friend_requests add constraint friend_requests_source_check
  check (source in ('qr', 'code', 'org', 'online'));
alter table public.friendships drop constraint friendships_source_check;
alter table public.friendships add constraint friendships_source_check
  check (source in ('qr', 'code', 'org', 'online'));

-- 發出去的推薦（短代碼 → 對方）。同一對只留一列，重新推薦時換新代碼。
create table public.friend_suggest_shown (
  user_id uuid not null references auth.users (id) on delete cascade,
  other uuid not null references auth.users (id) on delete cascade,
  ref text not null,
  shown_at timestamptz not null default now(),
  primary key (user_id, other)
);
create unique index friend_suggest_shown_ref on public.friend_suggest_shown (user_id, ref);
alter table public.friend_suggest_shown enable row level security;
revoke all on public.friend_suggest_shown from anon, authenticated;

-- 按過「不要」的。
create table public.friend_suggest_hides (
  user_id uuid not null references auth.users (id) on delete cascade,
  other uuid not null references auth.users (id) on delete cascade,
  hidden_until timestamptz not null,
  primary key (user_id, other)
);
alter table public.friend_suggest_hides enable row level security;
revoke all on public.friend_suggest_hides from anon, authenticated;

-- {ok:true, on:bool, list:[{ref,name,avatar}]} | {ok:false, reason: signed_out | rate_limited | no_profile}
create function public.mp_suggest_online()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_on boolean;
  v_list jsonb := '[]'::jsonb;
  r record;
  v_ref text;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select suggest_me into v_on from public.profiles where user_id = v_me;
  if v_on is null then
    return jsonb_build_object('ok', false, 'reason', 'no_profile');
  end if;
  if not v_on then
    return jsonb_build_object('ok', true, 'on', false, 'list', v_list);
  end if;
  for r in
    select p.user_id, p.nickname, p.avatar_preset
    from public.mp_presence m
    join public.profiles p on p.user_id = m.user_id
    where m.last_seen > now() - interval '90 seconds'
      and m.user_id <> v_me
      and p.suggest_me
      and p.nickname is not null and not p.nickname_removed
      and not exists (
        select 1 from public.friendships f
        where f.user_low = least(v_me, p.user_id) and f.user_high = greatest(v_me, p.user_id))
      and not public.friends_blocked_either(v_me, p.user_id)
      and not exists (
        select 1 from public.friend_requests q
        where q.status in ('pending', 'declined') and q.expires_at > now()
          and ((q.from_user = v_me and q.to_user = p.user_id)
            or (q.from_user = p.user_id and q.to_user = v_me)))
      and not public.friends_cooling(v_me, p.user_id)
      and not exists (
        select 1 from public.friend_suggest_hides h
        where h.user_id = v_me and h.other = p.user_id and h.hidden_until > now())
    order by md5(v_me::text || p.user_id::text || (now() at time zone 'Asia/Taipei')::date::text)
    limit 8
  loop
    v_ref := left(md5(gen_random_uuid()::text), 12);
    insert into public.friend_suggest_shown (user_id, other, ref, shown_at)
    values (v_me, r.user_id, v_ref, now())
    on conflict (user_id, other) do update set ref = excluded.ref, shown_at = excluded.shown_at;
    v_list := v_list || jsonb_build_object('ref', v_ref, 'name', r.nickname, 'avatar', r.avatar_preset);
  end loop;
  return jsonb_build_object('ok', true, 'on', true, 'list', v_list);
end
$$;

-- 「不要」：30 天內不再推薦這個人。{ok:true} | {ok:false, reason: signed_out | rate_limited | not_found}
create function public.mp_suggest_hide(p_ref text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_other uuid;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select other into v_other from public.friend_suggest_shown
  where user_id = v_me and ref = p_ref;
  if v_other is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  insert into public.friend_suggest_hides (user_id, other, hidden_until)
  values (v_me, v_other, now() + interval '30 days')
  on conflict (user_id, other) do update set hidden_until = excluded.hidden_until;
  delete from public.friend_suggest_shown where user_id = v_me and other = v_other;
  return jsonb_build_object('ok', true);
end
$$;

-- 開關「讓別人推薦我」。{ok:true, on:bool} | {ok:false, reason: signed_out | rate_limited | no_profile}
create function public.mp_suggest_set(p_on boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  update public.profiles set suggest_me = coalesce(p_on, true), updated_at = now()
  where user_id = v_me;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'no_profile');
  end if;
  if not coalesce(p_on, true) then
    -- 關掉時，別人手上發給他們的推薦代碼一起作廢
    delete from public.friend_suggest_shown where other = v_me;
  end if;
  return jsonb_build_object('ok', true, 'on', coalesce(p_on, true));
end
$$;

-- send_friend_request：跟 20261026120000_friends_rpc_abuse.sql 一樣，只多 'online' 這一段。
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

-- 每天清一次過期的推薦代碼與「不要」（pg_cron，台灣時間 04:10，跟 20261104130000_cleanup_cron.sql 同一套）。
create or replace function public.friend_suggest_cleanup()
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  delete from public.friend_suggest_shown where shown_at < now() - interval '1 day';
  delete from public.friend_suggest_hides where hidden_until < now();
$$;
revoke all on function public.friend_suggest_cleanup() from public, anon, authenticated;
grant execute on function public.friend_suggest_cleanup() to service_role;
select cron.schedule(
  'silversole-friend-suggest-cleanup',
  '10 20 * * *',
  $cron$select public.friend_suggest_cleanup()$cron$
);

revoke all on function public.mp_suggest_online() from public, anon;
revoke all on function public.mp_suggest_hide(text) from public, anon;
revoke all on function public.mp_suggest_set(boolean) from public, anon;
grant execute on function public.mp_suggest_online() to authenticated;
grant execute on function public.mp_suggest_hide(text) to authenticated;
grant execute on function public.mp_suggest_set(boolean) to authenticated;

commit;
