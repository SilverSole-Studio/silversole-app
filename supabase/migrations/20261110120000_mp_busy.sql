-- supabase/migrations/20261110120000_mp_busy.sql
--
-- *** 還沒套用到任何 Supabase 專案；套用前要先問 user。 ***
-- 要先套好 20261104180000_mp_presence.sql（mp_presence、mp_ping、mp_friends_online）與
-- 20261104140000_mp_seats.sql（mp_invite、mp_invite_to）。
--
-- user 2026-11-10：「要邀請的人在對局，我們應該要給邀請別人的人提示吧」。
-- 對方正在倒數／對局時，邀請照送（他打完才看得到邀請卡），但邀請的人要知道。
--
--   - mp_presence 多一欄 busy_until。
--   - mp_ping(p_busy boolean default false)：舊的無參數呼叫照舊可用（預設 false）。
--     busy=true 時 busy_until = 現在 + 90 秒（客戶端每 60 秒帶一次；結束時送 busy=false 清掉）。
--     15 秒內重複報到不重寫，但 busy 狀態變了就立刻寫（開打、打完要馬上反映）。
--   - mp_friends_online 多回 busy:[好友 id]（在線上且 busy_until 還沒到）。busy 一定是 online 的子集。
--   - mp_invite、mp_invite_to 的 ok 回傳多帶 busy:true|false（邀請照送）。
--     只在「已確認是好友、沒封鎖」之後才查，陌生人／被封鎖者拿不到任何狀態（都先回 not_friends）。
--   - mp_friend_busy(uuid)：內部小工具，不開給任何角色（只給上面 security definer 的函式呼叫）。
--
-- RPC 濫用自查規則照舊：先 mp_take 限流；jsonb {ok, reason} 不 raise；security definer、
-- set search_path = ''、只 grant authenticated。

begin;

alter table public.mp_presence add column busy_until timestamptz;

-- 舊的無參數版本換成帶預設值的新版（同名兩個版本會讓無參數呼叫有歧義）。
drop function public.mp_ping();

-- I am here (and maybe busy playing). {ok:true} | {ok:false, reason: signed_out | rate_limited}
create function public.mp_ping(p_busy boolean default false)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_busy boolean := coalesce(p_busy, false);
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  insert into public.mp_presence (user_id, last_seen, busy_until)
  values (v_me, now(), case when v_busy then now() + interval '90 seconds' end)
  on conflict (user_id) do update
    set last_seen = now(),
        busy_until = case when v_busy then now() + interval '90 seconds' end
  where public.mp_presence.last_seen < now() - interval '15 seconds'
     or v_busy <> (coalesce(public.mp_presence.busy_until, '-infinity'::timestamptz) > now());
  return jsonb_build_object('ok', true);
end
$$;

-- Is this user online and busy right now? Internal only: callers must have
-- checked that the asker and p_user are friends (not blocked) first.
create function public.mp_friend_busy(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.busy_until > now() and p.last_seen > now() - interval '90 seconds'
    from public.mp_presence p
    where p.user_id = p_user
  ), false)
$$;

-- Online friends and which of them are busy.
--   {ok:true, online:[id...], busy:[id...]} | {ok:false, reason: signed_out | rate_limited}
create or replace function public.mp_friends_online()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_online jsonb;
  v_busy jsonb;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 2) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select coalesce(jsonb_agg(x.other), '[]'::jsonb),
         coalesce(jsonb_agg(x.other) filter (where x.busy), '[]'::jsonb)
    into v_online, v_busy
  from (
    select case when f.user_low = v_me then f.user_high else f.user_low end as other,
           coalesce(p.busy_until > now(), false) as busy
    from public.friendships f
    join public.mp_presence p
      on p.user_id = case when f.user_low = v_me then f.user_high else f.user_low end
    where (f.user_low = v_me or f.user_high = v_me)
      and p.last_seen > now() - interval '90 seconds'
      and not public.friends_blocked_either(f.user_low, f.user_high)
    limit 200
  ) x;
  return jsonb_build_object('ok', true, 'online', v_online, 'busy', v_busy);
end
$$;

-- Invite a friend (same as 20261104140000_mp_seats.sql) + 'busy' in the answer.
create or replace function public.mp_invite(p_friend uuid, p_game text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
  v_until timestamptz;
  v_busy boolean;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 10) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if not public.mp_game_ok(p_game) then
    return jsonb_build_object('ok', false, 'reason', 'bad_game');
  end if;
  -- Friends only, and not blocked either way. One answer for every "no".
  if p_friend is null or p_friend = v_me or not public.are_friends(v_me, p_friend) then
    return jsonb_build_object('ok', false, 'reason', 'not_friends');
  end if;
  v_busy := public.mp_friend_busy(p_friend);
  perform public.mp_expire(v_me);
  perform public.mp_expire(p_friend);
  perform public.mp_gc(v_me);
  -- Count the friend's pending invites under a lock on the friend, so
  -- several inviters at once cannot all see "4" and push it past 5.
  perform pg_advisory_xact_lock(hashtextextended('mp-invitee:' || p_friend::text, 0));
  select until_at into v_until from public.mp_declines
  where host = v_me and invited = p_friend;
  if v_until is not null and v_until > now() then
    return jsonb_build_object('ok', false, 'reason', 'invitee_busy');
  end if;
  -- Already invited for this game: hand back the same room.
  select * into v_room from public.mp_rooms
  where host = v_me and invited = p_friend and game = p_game and status = 'waiting'
  order by created_at desc limit 1;
  if found then
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me), 'busy', v_busy);
  end if;
  if public.mp_pending_invites(p_friend) >= 5 then
    return jsonb_build_object('ok', false, 'reason', 'invitee_busy');
  end if;
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;
  v_room := public.mp_make_room(v_me, p_game, p_friend);
  if v_room.id is null then
    return jsonb_build_object('ok', false, 'reason', 'no_code');
  end if;
  perform public.mp_notify('user:' || p_friend::text, 'invite',
    jsonb_build_object('room', v_room.id, 'game', v_room.game, 'from', v_me));
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me), 'busy', v_busy);
end
$$;

-- Invite into a multi-seat room (same as 20261104140000_mp_seats.sql) + 'busy' in the answer.
create or replace function public.mp_invite_to(p_room uuid, p_friend uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
  v_until timestamptz;
  v_busy boolean;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 10) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if p_friend is null or p_friend = v_me or not public.are_friends(v_me, p_friend) then
    return jsonb_build_object('ok', false, 'reason', 'not_friends');
  end if;
  v_busy := public.mp_friend_busy(p_friend);
  perform public.mp_expire(v_me);
  perform public.mp_expire(p_friend);
  -- Same lock key as mp_invite, taken before the room row.
  perform pg_advisory_xact_lock(hashtextextended('mp-invitee:' || p_friend::text, 0));
  select * into v_room from public.mp_rooms
  where id = p_room and host = v_me
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_room.seats = 2 then
    return jsonb_build_object('ok', false, 'reason', 'bad_seats');
  end if;
  if v_room.status <> 'waiting' then
    return jsonb_build_object('ok', false, 'reason', 'not_waiting');
  end if;
  if public.mp_free_seat(v_room) is null then
    return jsonb_build_object('ok', false, 'reason', 'room_full');
  end if;
  if public.mp_seat_of(v_room, p_friend) is not null then
    return jsonb_build_object('ok', false, 'reason', 'already_in');
  end if;
  -- Already invited to this room: nothing changes.
  if exists (select 1 from public.mp_room_invites
             where room = v_room.id and invited = p_friend) then
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me), 'busy', v_busy);
  end if;
  select until_at into v_until from public.mp_declines
  where host = v_me and invited = p_friend;
  if v_until is not null and v_until > now() then
    return jsonb_build_object('ok', false, 'reason', 'invitee_busy');
  end if;
  if public.mp_pending_invites(p_friend) >= 5 then
    return jsonb_build_object('ok', false, 'reason', 'invitee_busy');
  end if;
  insert into public.mp_room_invites (room, invited) values (v_room.id, p_friend);
  perform public.mp_notify('user:' || p_friend::text, 'invite',
    jsonb_build_object('room', v_room.id, 'game', v_room.game, 'from', v_me));
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me), 'busy', v_busy);
end
$$;

-- ── 執行權 ─────────────────────────────────────────────────────────────
-- mp_ping 是新簽名（boolean）要重開；mp_friend_busy 不開給任何人；
-- mp_friends_online、mp_invite、mp_invite_to 是 create or replace，原本的執行權不變。

revoke execute on function public.mp_ping(boolean) from public, anon, authenticated;
grant execute on function public.mp_ping(boolean) to authenticated;
revoke execute on function public.mp_friend_busy(uuid) from public, anon, authenticated;

commit;
