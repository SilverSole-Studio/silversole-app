-- supabase/migrations/20261104180000_mp_presence.sql
--
-- *** 還沒套用到任何 Supabase 專案；套用前要先問 user。 ***
-- 要先套好 20261019120000_friends.sql、20261026120000_friends_rpc_abuse.sql、
-- 20261103120000_mp_rooms.sql、20261104140000_mp_seats.sql（這支改它們建的 mp_leave、mp_cleanup）。
--
-- user 2026-11-04：「要可以看到別人上線狀態，這樣才可以不需要約好才邀請別人」
-- 「等一下要通知房主」。兩件事：
--
-- 1. 好友在線上
--    - 新表 mp_presence(user_id, last_seen)：RLS 開、不給 App 直接讀寫，只能走下面兩支 RPC。
--    - mp_ping()：把自己的 last_seen 設成現在（頁面開著每 60 秒一次）。先 mp_take 限流（花 1）；
--      15 秒內重複打不會再寫一次（同一列只在過了 15 秒才更新，亂打也寫不爆）。
--    - mp_friends_online()：回 {ok:true, online:[好友 user id]}。只回「是好友、雙方都沒封鎖、
--      90 秒內 ping 過」的人（判斷跟 get_friends 一樣：friendships 加 friends_blocked_either）。
--      陌生人、已解除好友、被封鎖的人都不會出現，也沒有任何方式問「某個 id 在不在線」。
--      先 mp_take（花 2）。
--    - mp_cleanup() 多刪一天沒動的 mp_presence 列。
--
-- 2. 拒絕邀請要通知房主
--    - 被邀的人呼叫 mp_leave(room) 本來就是拒絕（5 分鐘內房主不能再邀他）。
--      2 人房：房間作廢、房主收到 'left'，現在再多收一個 'declined'。
--      多人房（seats > 2）：以前拒絕分支沒通知；現在往房間頻道推 'declined'
--      （房間繼續開著，其他位子不受影響）。
--    - 'declined' 的 payload：{by: 拒絕的人的 user id, seq, status}。同一個邀請只會通知一次
--      （第二次打 mp_leave：多人房找不到邀請列、2 人房房間已作廢，都直接回，不再推）。
--
-- RPC 濫用自查規則照舊：每支 RPC 先 mp_take 拿自己的 mp_limits 鎖；回傳 jsonb {ok, reason}，
-- 不 raise；security definer、set search_path = ''、只 grant authenticated。

begin;

create table public.mp_presence (
  user_id uuid primary key references auth.users (id) on delete cascade,
  last_seen timestamptz not null default now()
);
alter table public.mp_presence enable row level security;
revoke all on public.mp_presence from anon, authenticated;

-- I am here. {ok:true} | {ok:false, reason: signed_out | rate_limited}
create function public.mp_ping()
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
  insert into public.mp_presence (user_id, last_seen)
  values (v_me, now())
  on conflict (user_id) do update set last_seen = now()
  where public.mp_presence.last_seen < now() - interval '15 seconds';
  return jsonb_build_object('ok', true);
end
$$;

-- Which of my friends are online (pinged in the last 90 seconds).
--   {ok:true, online:[user id, ...]} | {ok:false, reason: signed_out | rate_limited}
-- Only friends, and not when either side blocked the other.
create function public.mp_friends_online()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_online jsonb;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 2) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select coalesce(jsonb_agg(x.other), '[]'::jsonb) into v_online
  from (
    select case when f.user_low = v_me then f.user_high else f.user_low end as other
    from public.friendships f
    join public.mp_presence p
      on p.user_id = case when f.user_low = v_me then f.user_high else f.user_low end
    where (f.user_low = v_me or f.user_high = v_me)
      and p.last_seen > now() - interval '90 seconds'
      and not public.friends_blocked_either(f.user_low, f.user_high)
    limit 200
  ) x;
  return jsonb_build_object('ok', true, 'online', v_online);
end
$$;

-- Leave (decline). Same as 20261104140000_mp_seats.sql, plus the host is told
-- about a decline: seats > 2 pushes 'declined'; seats = 2 pushes 'declined' after
-- the usual 'left'.
create or replace function public.mp_leave(p_room uuid, p_how text default 'resign')
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
  v_side smallint;
  v_resp smallint;
  v_g1 uuid;
  v_g2 uuid;
  v_g3 uuid;
  v_declined boolean := false;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if p_how is null or p_how not in ('resign', 'abort') then
    return jsonb_build_object('ok', false, 'reason', 'bad_move');
  end if;
  select * into v_room from public.mp_rooms r
  where r.id = p_room
    and (
      r.host = v_me or r.guest = v_me or r.guest2 = v_me or r.guest3 = v_me
      or r.invited = v_me
      or exists (
        select 1 from public.mp_room_invites i
        where i.room = r.id and i.invited = v_me
      )
    )
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_room.status in ('done', 'abandoned') then
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;

  if v_room.seats > 2 then
    v_side := public.mp_seat_of(v_room, v_me);
    if v_room.status = 'waiting' then
      if v_side is null then
        -- only invited: decline
        delete from public.mp_room_invites where room = v_room.id and invited = v_me;
        insert into public.mp_declines (host, invited, until_at)
        values (v_room.host, v_me, now() + interval '5 minutes')
        on conflict (host, invited) do update set until_at = excluded.until_at;
        -- the host hears about it (the room stays open for the other seats)
        perform public.mp_notify('room:' || v_room.id::text, 'declined',
          jsonb_build_object('by', v_me, 'seq', v_room.seq, 'status', v_room.status));
        return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
      elsif v_side = 0 then
        update public.mp_rooms
        set status = 'abandoned', end_reason = 'left', updated_at = now()
        where id = v_room.id
        returning * into v_room;
        delete from public.mp_room_invites where room = v_room.id;
      else
        v_g1 := v_room.guest;
        v_g2 := v_room.guest2;
        v_g3 := v_room.guest3;
        if v_side = 1 then
          v_g1 := v_g2; v_g2 := v_g3; v_g3 := null;
        elsif v_side = 2 then
          v_g2 := v_g3; v_g3 := null;
        else
          v_g3 := null;
        end if;
        update public.mp_rooms
        set guest = v_g1, guest2 = v_g2, guest3 = v_g3, updated_at = now()
        where id = v_room.id
        returning * into v_room;
      end if;
    else
      -- playing
      if v_side is null then
        return jsonb_build_object('ok', false, 'reason', 'not_found');
      end if;
      if p_how = 'abort' then
        -- whose move is it really: a bot's turn is the host's to play
        v_resp := case
          when ((v_room.bots::integer >> v_room.turn) & 1) = 1 then 0
          else v_room.turn
        end;
        if v_resp = v_side
           or coalesce(v_room.last_move_at, v_room.updated_at) > now() - interval '60 seconds' then
          return jsonb_build_object('ok', false, 'reason', 'too_early');
        end if;
        update public.mp_rooms
        set status = 'abandoned', end_reason = 'opponent_gone', winner = null, updated_at = now()
        where id = v_room.id
        returning * into v_room;
      else
        update public.mp_rooms
        set status = 'abandoned', end_reason = 'left', winner = null, updated_at = now()
        where id = v_room.id
        returning * into v_room;
      end if;
    end if;
    perform public.mp_notify('room:' || v_room.id::text, 'left',
      jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;

  -- seats = 2: unchanged, except that a decline also says who declined
  if v_room.status = 'waiting' then
    if v_room.invited = v_me and v_room.host <> v_me then
      insert into public.mp_declines (host, invited, until_at)
      values (v_room.host, v_me, now() + interval '5 minutes')
      on conflict (host, invited) do update set until_at = excluded.until_at;
      v_declined := true;
    end if;
    update public.mp_rooms
    set status = 'abandoned', end_reason = 'left', updated_at = now()
    where id = v_room.id
    returning * into v_room;
  else
    v_side := case when v_room.host = v_me then 0 else 1 end;
    if p_how = 'abort' then
      if v_room.turn = v_side or v_room.updated_at > now() - interval '60 seconds' then
        return jsonb_build_object('ok', false, 'reason', 'too_early');
      end if;
      update public.mp_rooms
      set status = 'abandoned', end_reason = 'opponent_gone', winner = null, updated_at = now()
      where id = v_room.id
      returning * into v_room;
    else
      update public.mp_rooms
      set status = 'done', end_reason = 'resign', winner = 1 - v_side, updated_at = now()
      where id = v_room.id
      returning * into v_room;
    end if;
  end if;
  perform public.mp_notify('room:' || v_room.id::text, 'left',
    jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
  if v_declined then
    perform public.mp_notify('room:' || v_room.id::text, 'declined',
      jsonb_build_object('by', v_me, 'seq', v_room.seq, 'status', v_room.status));
  end if;
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Housekeeping (service_role only): same as before, plus old mp_presence rows.
create or replace function public.mp_cleanup()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_expired integer;
  v_deleted integer;
  v_invites integer;
begin
  update public.mp_rooms
  set status = 'abandoned', end_reason = 'expired', updated_at = now()
  where status in ('waiting', 'playing') and updated_at < now() - interval '2 hours';
  get diagnostics v_expired = row_count;
  delete from public.mp_rooms
  where status in ('done', 'abandoned') and updated_at < now() - interval '14 days';
  get diagnostics v_deleted = row_count;
  delete from public.mp_room_invites i
  using public.mp_rooms r
  where r.id = i.room and r.status <> 'waiting';
  get diagnostics v_invites = row_count;
  delete from public.mp_declines where until_at < now() - interval '1 day';
  delete from public.mp_presence where last_seen < now() - interval '1 day';
  return jsonb_build_object('expired', v_expired, 'deleted', v_deleted, 'invites', v_invites);
end
$$;

-- ── 執行權 ─────────────────────────────────────────────────────────────
-- 新函式預設開給 public／anon／authenticated；全部收回再逐支開。
-- （mp_leave、mp_cleanup 是 create or replace，原本的執行權不變。）

revoke execute on function
  public.mp_ping(),
  public.mp_friends_online()
from public, anon, authenticated;

grant execute on function
  public.mp_ping(),
  public.mp_friends_online()
to authenticated;

commit;
