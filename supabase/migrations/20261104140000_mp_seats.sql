-- supabase/migrations/20261104140000_mp_seats.sql
--
-- *** 還沒套用到任何 Supabase 專案；套用前要先問 user。 ***
-- 要先套好 20261103120000_mp_rooms.sql（這支改它建的表與函式）。
--
-- 線上對戰房間從 2 個位子擴充到最多 4 個位子（麻將、德州撲克要 4 個真人）。
-- 位子編號：0 = host、1 = guest、2 = guest2、3 = guest3。
-- 2 人房（seats = 2）行為完全不變；象棋、撞球照舊用 mp_create_room(game)、
-- mp_invite(friend, game)、mp_join_room(code, game)，不帶新參數。
--
-- 套用前核對（舊 constraint 是自動命名的）：
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--   where conrelid = 'public.mp_rooms'::regclass;
-- 預期舊的有 mp_rooms_turn_check、mp_rooms_winner_check。這支不靠名字：
-- 下面用 DO 區塊依「單欄、check、欄位是 turn／winner」找出來砍，名字不同也砍得到。
--
-- 多人房（seats > 2）的規則：
--   - 房主之外、知道房號的人都能坐（不看 mp_rooms.invited）；邀請走新表
--     mp_room_invites（2 人房照舊用 mp_rooms.invited）。
--   - waiting 時客人依序坐最小號空位；坐滿自動開打（bots = 0）。人沒坐滿也可以
--     由房主 mp_start 開打，空著的位子 = 電腦，bots 位元遮罩 bit k = 第 k 位。
--   - 客人在 waiting 時離開，後面的客人往前補（位子永遠從 1 連續填起），所以
--     舊的 check（playing 一定有 guest）仍然成立。
--   - 電腦的回合由房主代送（mp_submit_move，v_side = 0 且 bots 有 turn 這一位）。
--     棋譜 by = 那一步是哪個位子走的（不是誰送的）。
--   - 多人局 playing 時有人走就整局作廢（abandoned／left，沒有勝負）。
--
-- 房號從 6 位數改成 4 位數（user 2026-11-04）：
--   - mp_rooms.code 的 check 改成 '^[1-9][0-9]{3}$'（舊的單欄 check 用 DO 區塊依欄位砍，不靠名字）。
--   - 套用時，正式庫現有的 6 位數房間先處理：status 為 waiting／playing 的設成
--     abandoned／'expired'（這些房間會被作廢，進行中的局也一樣，套用前要確認沒人在玩）；
--     所有 6 位數的舊房號（含已結束的房間）一律清成 null（code 欄本來就可為空），
--     新 check 才加得上去。
--   - mp_new_code() 改產 1000–9999，在「還活著的房間」裡不重複；試 20 次都撞到回 null，
--     mp_create_room／mp_invite 回 {ok:false, reason:'no_code'}。
--   - mp_join_room 的房號格式檢查跟著改；猜錯懲罰（join_fails／join_locked_until）照舊。
--     提醒：4 位數只有 9000 種，猜錯懲罰（10 分鐘內錯 5 次鎖 10 分鐘）是唯一的防線。
--
-- RPC 濫用自查規則照舊：每支 RPC 先 mp_take 拿自己的 mp_limits 鎖；回傳
-- jsonb {ok, reason}，不 raise（raise 會把懲罰計數 rollback）；security definer、
-- set search_path = ''、只 grant authenticated。

begin;

-- ── 表：mp_rooms 加欄與 constraint ─────────────────────────────────────

alter table public.mp_rooms
  add column seats smallint not null default 2 check (seats between 2 and 4),
  add column guest2 uuid references auth.users (id) on delete cascade,
  add column guest3 uuid references auth.users (id) on delete cascade,
  -- 開打時空著的位子 = 電腦；bit k = 第 k 位。
  add column bots smallint not null default 0 check (bots between 0 and 15);

-- turn、winner 原本只准 0／1：依欄位找出舊的單欄 check 砍掉，再放寬到 0..3。
do $$
declare
  v_name text;
begin
  for v_name in
    select c.conname
    from pg_constraint c
    join pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
    where c.conrelid = 'public.mp_rooms'::regclass
      and c.contype = 'c'
      and array_length(c.conkey, 1) = 1
      and a.attname in ('turn', 'winner')
  loop
    execute format('alter table public.mp_rooms drop constraint %I', v_name);
  end loop;
end
$$;

-- 房號改 4 位數：先作廢活著的 6 位數房間、清掉所有 6 位數房號，再換 check。
update public.mp_rooms
set status = 'abandoned', end_reason = 'expired', updated_at = now()
where status in ('waiting', 'playing') and code ~ '^[1-9][0-9]{5}$';
update public.mp_rooms set code = null where code is not null and code !~ '^[1-9][0-9]{3}$';

do $$
declare
  v_name text;
begin
  for v_name in
    select c.conname
    from pg_constraint c
    join pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
    where c.conrelid = 'public.mp_rooms'::regclass
      and c.contype = 'c'
      and array_length(c.conkey, 1) = 1
      and a.attname = 'code'
  loop
    execute format('alter table public.mp_rooms drop constraint %I', v_name);
  end loop;
end
$$;

alter table public.mp_rooms
  add constraint mp_rooms_code_4digits check (code ~ '^[1-9][0-9]{3}$');

alter table public.mp_rooms
  add constraint mp_rooms_turn_range check (turn between 0 and 3),
  add constraint mp_rooms_winner_range check (winner between 0 and 3),
  add constraint mp_rooms_turn_in_seats check (turn < seats),
  add constraint mp_rooms_winner_in_seats check (winner is null or winner < seats),
  -- seats = 2 時 guest2／guest3 為空；seats = 3 時 guest3 為空。
  add constraint mp_rooms_seats_fit check (
    (seats >= 3 or guest2 is null) and (seats >= 4 or guest3 is null)
  ),
  -- 房主不能是電腦、電腦只能在房間的位子範圍內。
  add constraint mp_rooms_bots_fit check (
    (bots::integer & 1) = 0 and (bots::integer >> seats) = 0
  ),
  -- 四個成員兩兩不同（非空時）。
  add constraint mp_rooms_members_distinct check (
    (guest2 is null or (guest2 <> host and guest2 is distinct from guest))
    and (
      guest3 is null
      or (guest3 <> host and guest3 is distinct from guest and guest3 is distinct from guest2)
    )
  );

create index mp_rooms_guest2_idx on public.mp_rooms (guest2) where guest2 is not null;
create index mp_rooms_guest3_idx on public.mp_rooms (guest3) where guest3 is not null;

-- 四個位子都看得到自己的房間。
drop policy mp_rooms_select_players on public.mp_rooms;
create policy mp_rooms_select_players on public.mp_rooms
  for select to authenticated
  using (
    host = (select auth.uid()) or guest = (select auth.uid())
    or guest2 = (select auth.uid()) or guest3 = (select auth.uid())
  );

-- ── 表：多人房的邀請 ───────────────────────────────────────────────────
-- 只給 seats > 2 的房用（2 人房照舊用 mp_rooms.invited）。

create table public.mp_room_invites (
  room uuid not null references public.mp_rooms (id) on delete cascade,
  invited uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (room, invited)
);
create index mp_room_invites_invited_idx on public.mp_room_invites (invited);
alter table public.mp_room_invites enable row level security;
revoke all on public.mp_room_invites from anon, authenticated;

-- ── 內部小工具 ─────────────────────────────────────────────────────────

-- p_me 在這間房的位子：0..3，不是成員回 null。
create function public.mp_seat_of(r public.mp_rooms, p_me uuid)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case
    when p_me is null then null
    when r.host = p_me then 0
    when r.guest = p_me then 1
    when r.guest2 = p_me then 2
    when r.guest3 = p_me then 3
  end::smallint
$$;

-- 最小號的空位（1..seats-1）；坐滿回 null。
create function public.mp_free_seat(r public.mp_rooms)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case
    when r.guest is null then 1
    when r.seats >= 3 and r.guest2 is null then 2
    when r.seats >= 4 and r.guest3 is null then 3
  end::smallint
$$;

-- 一個好友待回覆的邀請數：2 人房（mp_rooms.invited）加多人房（mp_room_invites）。
create function public.mp_pending_invites(p_friend uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select (
    (select count(*) from public.mp_rooms
      where invited = p_friend and status = 'waiting')
    + (select count(*) from public.mp_room_invites i
        join public.mp_rooms r on r.id = i.room
        where i.invited = p_friend and r.status = 'waiting')
  )::integer
$$;

-- 坐進最小號空位（呼叫者已經 for update 鎖了這間房並檢查過資格）：
-- 刪掉我的邀請；坐滿就自動開打（turn 0、bots 0）並清掉這間房所有邀請。
create function public.mp_sit(p_room uuid, p_me uuid)
returns public.mp_rooms
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_room public.mp_rooms;
  v_seat smallint;
begin
  select * into v_room from public.mp_rooms where id = p_room for update;
  v_seat := public.mp_free_seat(v_room);
  if v_seat is null then
    return v_room;
  end if;
  update public.mp_rooms
  set guest = case when v_seat = 1 then p_me else guest end,
      guest2 = case when v_seat = 2 then p_me else guest2 end,
      guest3 = case when v_seat = 3 then p_me else guest3 end,
      updated_at = now()
  where id = p_room
  returning * into v_room;
  delete from public.mp_room_invites where room = p_room and invited = p_me;
  if public.mp_free_seat(v_room) is null then
    update public.mp_rooms
    set status = 'playing', turn = 0, bots = 0, updated_at = now()
    where id = p_room
    returning * into v_room;
    delete from public.mp_room_invites where room = p_room;
  end if;
  return v_room;
end
$$;

-- 2 小時沒動的房間作廢（我是成員、2 人房被邀請的、或多人房被邀請的）。
create or replace function public.mp_expire(p_me uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.mp_rooms r
  set status = 'abandoned', end_reason = 'expired', updated_at = now()
  where (
      r.host = p_me or r.guest = p_me or r.guest2 = p_me or r.guest3 = p_me
      or r.invited = p_me
      or exists (
        select 1 from public.mp_room_invites i
        where i.room = r.id and i.invited = p_me
      )
    )
    and r.status in ('waiting', 'playing')
    and r.updated_at < now() - interval '2 hours'
$$;

create or replace function public.mp_gc(p_me uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  delete from public.mp_rooms
  where host = p_me
    and status = 'abandoned'
    and seq = 0
    and ((guest is null and guest2 is null and guest3 is null)
         or updated_at < now() - interval '10 minutes');
  delete from public.mp_rooms
  where id in (
    select id from public.mp_rooms
    where host = p_me
      and status in ('done', 'abandoned')
      and updated_at < now() - interval '10 minutes'
    order by updated_at desc
    offset 20
  );
end
$$;

create or replace function public.mp_live_count(p_me uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.mp_rooms
  where (host = p_me or guest = p_me or guest2 = p_me or guest3 = p_me)
    and status in ('waiting', 'playing')
$$;

create or replace function public.mp_room_json(r public.mp_rooms, p_me uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id,
    'game', r.game,
    'code', r.code,
    'host', r.host,
    'guest', r.guest,
    'guest2', r.guest2,
    'guest3', r.guest3,
    'seats', r.seats,
    'bots', r.bots,
    'status', r.status,
    'seq', r.seq,
    'turn', r.turn,
    'winner', r.winner,
    'endReason', r.end_reason,
    'side', public.mp_seat_of(r, p_me),
    'updatedAt', r.updated_at
  )
$$;

-- 4 位數房號（1000–9999），在還活著（2 小時內有動）的房間裡不重複；
-- 試 20 次都撞到回 null。（用 uuid 取亂數，不像 random() 可預測。）
create or replace function public.mp_new_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_try integer := 0;
begin
  while v_try < 20 loop
    v_try := v_try + 1;
    v_code := (
      ('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint
        % 9000 + 1000
    )::text;
    if not exists (
      select 1 from public.mp_rooms
      where code = v_code
        and status in ('waiting', 'playing')
        and updated_at >= now() - interval '2 hours'
    ) then
      return v_code;
    end if;
  end loop;
  return null;
end
$$;

-- mp_make_room 多一個 p_seats；舊的三參數版本砍掉（只有 mp_create_room 與
-- mp_invite 呼叫它，三參數呼叫會走到新版的預設值 2）。
-- 抽不到空房號時回「全空欄位」的列（v_room.id is null），呼叫端回 'no_code'。
drop function public.mp_make_room(uuid, text, uuid);
create function public.mp_make_room(
  p_me uuid, p_game text, p_invited uuid, p_seats integer default 2
)
returns public.mp_rooms
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_room public.mp_rooms;
  v_code text;
  v_try integer := 0;
begin
  while v_try < 5 loop
    v_try := v_try + 1;
    v_code := public.mp_new_code();
    if v_code is null then
      exit;
    end if;
    -- a stale room still holding this code is ended first
    update public.mp_rooms
    set status = 'abandoned', end_reason = 'expired', updated_at = now()
    where code = v_code
      and status in ('waiting', 'playing')
      and updated_at < now() - interval '2 hours';
    begin
      insert into public.mp_rooms (game, code, host, invited, seats)
      values (p_game, v_code, p_me, p_invited, p_seats::smallint)
      returning * into v_room;
      return v_room;
    exception when unique_violation then
      -- someone else took this code a moment ago; draw another
    end;
  end loop;
  v_room := null;
  return v_room;
end
$$;

-- ── 給 App／網頁呼叫 ───────────────────────────────────────────────────

-- New room. p_seats 2..4 (default 2 = the old behaviour).
--   {ok:true, room} | {ok:false, reason: signed_out | rate_limited | bad_game |
--                      bad_seats | too_many_rooms | no_code}
drop function public.mp_create_room(text);
create function public.mp_create_room(p_game text, p_seats integer default 2)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
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
  if p_seats is null or p_seats < 2 or p_seats > 4 then
    return jsonb_build_object('ok', false, 'reason', 'bad_seats');
  end if;
  perform public.mp_expire(v_me);
  perform public.mp_gc(v_me);
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;
  v_room := public.mp_make_room(v_me, p_game, null, p_seats);
  if v_room.id is null then
    return jsonb_build_object('ok', false, 'reason', 'no_code');
  end if;
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Join by 4-digit code.
--   {ok:true, room} | {ok:false, reason: signed_out | rate_limited | locked |
--                      bad_code | own_room | too_many_rooms}
-- seats = 2: unchanged. seats > 2: anyone but the host may take the lowest free
-- seat (mp_rooms.invited is not looked at); already seated = ok, no cost; the
-- room auto-starts when full. Wrong code / full / started / wrong game all
-- answer 'bad_code' and count as a wrong guess, as before.
create or replace function public.mp_join_room(p_code text, p_game text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_lock timestamptz;
  v_room public.mp_rooms;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select join_locked_until into v_lock from public.mp_limits where user_id = v_me;
  if v_lock is not null and v_lock > now() then
    return jsonb_build_object('ok', false, 'reason', 'locked', 'until', v_lock);
  end if;
  perform public.mp_expire(v_me);
  if p_code is null or p_code !~ '^[1-9][0-9]{3}$' then
    perform public.mp_join_failed(v_me);
    return jsonb_build_object('ok', false, 'reason', 'bad_code');
  end if;
  select * into v_room from public.mp_rooms
  where code = p_code and status in ('waiting', 'playing')
  for update;
  if not found then
    perform public.mp_join_failed(v_me);
    return jsonb_build_object('ok', false, 'reason', 'bad_code');
  end if;
  if v_room.updated_at < now() - interval '2 hours' then
    update public.mp_rooms
    set status = 'abandoned', end_reason = 'expired', updated_at = now()
    where id = v_room.id;
    perform public.mp_join_failed(v_me);
    return jsonb_build_object('ok', false, 'reason', 'bad_code');
  end if;

  if v_room.seats > 2 then
    -- already seated (an answer got lost): nothing changes
    if public.mp_seat_of(v_room, v_me) is not null and v_room.host <> v_me then
      if p_game is not null and v_room.game <> p_game then
        return jsonb_build_object('ok', false, 'reason', 'bad_code');
      end if;
      return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
    end if;
    if v_room.host = v_me then
      return jsonb_build_object('ok', false, 'reason', 'own_room');
    end if;
    if v_room.status <> 'waiting'
       or public.mp_free_seat(v_room) is null
       or (p_game is not null and v_room.game <> p_game) then
      perform public.mp_join_failed(v_me);
      return jsonb_build_object('ok', false, 'reason', 'bad_code');
    end if;
    if public.mp_live_count(v_me) >= 3 then
      return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
    end if;
    v_room := public.mp_sit(v_room.id, v_me);
    perform public.mp_notify('room:' || v_room.id::text, 'joined',
      jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;

  -- seats = 2: unchanged
  if v_room.guest = v_me then
    -- the same person again (an answer got lost): nothing changes
    if p_game is not null and v_room.game <> p_game then
      return jsonb_build_object('ok', false, 'reason', 'bad_code');
    end if;
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;
  if v_room.host = v_me then
    return jsonb_build_object('ok', false, 'reason', 'own_room');
  end if;
  if v_room.guest is not null
     or (v_room.invited is not null and v_room.invited <> v_me)
     or (p_game is not null and v_room.game <> p_game) then
    perform public.mp_join_failed(v_me);
    return jsonb_build_object('ok', false, 'reason', 'bad_code');
  end if;
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;
  update public.mp_rooms
  set guest = v_me, status = 'playing', turn = 0, updated_at = now()
  where id = v_room.id
  returning * into v_room;
  perform public.mp_notify('room:' || v_room.id::text, 'joined',
    jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Host starts a waiting multi-seat room before it is full; empty seats = bots.
--   {ok:true, room} | {ok:false, reason: signed_out | rate_limited | not_found |
--                      not_waiting | need_players}
create function public.mp_start(p_room uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
  v_bots integer := 0;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  perform public.mp_expire(v_me);
  select * into v_room from public.mp_rooms
  where id = p_room and host = v_me and seats > 2
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_room.status <> 'waiting' then
    return jsonb_build_object('ok', false, 'reason', 'not_waiting');
  end if;
  if v_room.guest is null and v_room.guest2 is null and v_room.guest3 is null then
    return jsonb_build_object('ok', false, 'reason', 'need_players');
  end if;
  if v_room.guest is null then v_bots := v_bots | 2; end if;
  if v_room.seats >= 3 and v_room.guest2 is null then v_bots := v_bots | 4; end if;
  if v_room.seats >= 4 and v_room.guest3 is null then v_bots := v_bots | 8; end if;
  update public.mp_rooms
  set status = 'playing', turn = 0, bots = v_bots::smallint, updated_at = now()
  where id = v_room.id
  returning * into v_room;
  delete from public.mp_room_invites where room = v_room.id;
  perform public.mp_notify('room:' || v_room.id::text, 'joined',
    jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Invite a friend: a 2-seat room only that friend may join; a push to the
-- friend's own channel. {ok:true, room}
-- (Unchanged except that the "at most 5 pending" count now also includes the
-- invites kept in mp_room_invites, so 5 + 5 cannot get around it.)
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
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
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
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Invite a friend into my waiting multi-seat room (seats > 2, a seat still free).
--   {ok:true, room} | {ok:false, reason: signed_out | rate_limited | not_friends |
--                      not_found | bad_seats | not_waiting | room_full |
--                      already_in | invitee_busy}
create function public.mp_invite_to(p_room uuid, p_friend uuid)
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
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
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
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Invites waiting for me (still friends, room still waiting with a free seat),
-- newest first, at most 5. Same output shape as before.
create or replace function public.mp_my_invites(p_game text default null)
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
  perform public.mp_expire(v_me);
  return jsonb_build_object('ok', true, 'invites', coalesce((
    select jsonb_agg(jsonb_build_object(
      'room', x.id, 'game', x.game, 'from', x.host, 'at', x.created_at
    ) order by x.created_at desc)
    from (
      select u.id, u.game, u.host, u.created_at
      from (
        select r.id, r.game, r.host, r.created_at
        from public.mp_rooms r
        where r.invited = v_me
          and r.status = 'waiting'
          and r.guest is null
          and (p_game is null or r.game = p_game)
          and public.are_friends(r.host, v_me)
        union all
        select r.id, r.game, r.host, i.created_at
        from public.mp_room_invites i
        join public.mp_rooms r on r.id = i.room
        where i.invited = v_me
          and r.status = 'waiting'
          and r.seats > 2
          and public.mp_free_seat(r) is not null
          and public.mp_seat_of(r, v_me) is null
          and (p_game is null or r.game = p_game)
          and public.are_friends(r.host, v_me)
      ) u
      order by u.created_at desc
      limit 5
    ) x
  ), '[]'::jsonb));
end
$$;

-- Take an invite. seats = 2: unchanged. seats > 2: needs my row in
-- mp_room_invites; sits in the lowest free seat; full = auto start.
--   {ok:true, room} | {ok:false, reason: signed_out | rate_limited | not_found |
--                      too_many_rooms}
create or replace function public.mp_accept_invite(p_room uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  perform public.mp_expire(v_me);
  select * into v_room from public.mp_rooms where id = p_room for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v_room.seats > 2 then
    if public.mp_seat_of(v_room, v_me) is not null and v_room.host <> v_me then
      return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
    end if;
    if not exists (select 1 from public.mp_room_invites
                   where room = v_room.id and invited = v_me) then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
    if v_room.status <> 'waiting'
       or public.mp_free_seat(v_room) is null
       or not public.are_friends(v_room.host, v_me) then
      return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;
    if public.mp_live_count(v_me) >= 3 then
      return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
    end if;
    v_room := public.mp_sit(v_room.id, v_me);
    perform public.mp_notify('room:' || v_room.id::text, 'joined',
      jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;

  -- seats = 2: unchanged
  if v_room.invited is distinct from v_me and v_room.guest is distinct from v_me then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_room.guest = v_me then
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;
  if v_room.status <> 'waiting' or v_room.guest is not null
     or not public.are_friends(v_room.host, v_me) then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;
  update public.mp_rooms
  set guest = v_me, status = 'playing', turn = 0, updated_at = now()
  where id = v_room.id
  returning * into v_room;
  perform public.mp_notify('room:' || v_room.id::text, 'joined',
    jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Send move number [p_seq] (= the room's seq + 1). [p_next] is who moves next
-- (a seat < seats; null = the next seat round the table). [p_end] 'win' = "this
-- move wins it for the seat that just moved", 'draw' = "this move draws it".
-- Allowed when turn = my seat, or when I am the host and the seat whose turn it
-- is is a bot (the host moves for bots). The record's `by` is the seat that
-- moved (turn), not who sent it; winner = that seat for 'win'.
--   {ok:true, seq}                        accepted
--   {ok:true, seq, dup:true}              the same move was already accepted
--   {ok:false, reason, seq?}              not_found | not_playing | not_your_turn |
--                                         seq_mismatch | move_too_big | bad_move |
--                                         too_fast | too_long | expired | rate_limited
create or replace function public.mp_submit_move(
  p_room uuid,
  p_seq integer,
  p_move jsonb,
  p_next smallint default null,
  p_end text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_max_bytes constant integer := 256;
  c_max_moves constant integer := 1000;
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
  v_side smallint;
  v_by smallint;
  v_next smallint;
  v_entry jsonb;
  v_old jsonb;
  v_old_by integer;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if p_move is null or jsonb_typeof(p_move) = 'null' or p_seq is null or p_seq < 1
     or (p_next is not null and p_next not between 0 and 3)
     or (p_end is not null and p_end not in ('win', 'draw')) then
    return jsonb_build_object('ok', false, 'reason', 'bad_move');
  end if;
  if octet_length(p_move::text) > c_max_bytes then
    return jsonb_build_object('ok', false, 'reason', 'move_too_big');
  end if;
  select * into v_room from public.mp_rooms
  where id = p_room
    and (host = v_me or guest = v_me or guest2 = v_me or guest3 = v_me)
  for update;
  if not found then
    -- not there, or not yours: the same answer
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if p_next is not null and p_next >= v_room.seats then
    return jsonb_build_object('ok', false, 'reason', 'bad_move');
  end if;
  v_side := public.mp_seat_of(v_room, v_me);
  -- Already taken: the same move from a seat I may move for is a resend,
  -- anything else is a different move for a taken seq.
  if p_seq <= v_room.seq then
    v_old := v_room.moves -> (p_seq - 1);
    v_old_by := (v_old ->> 'by')::integer;
    if v_old -> 'm' = p_move
       and (
         v_old_by = v_side
         or (v_side = 0 and ((v_room.bots::integer >> v_old_by) & 1) = 1)
       ) then
      return jsonb_build_object('ok', true, 'seq', v_room.seq, 'dup', true);
    end if;
    return jsonb_build_object('ok', false, 'reason', 'seq_mismatch', 'seq', v_room.seq);
  end if;
  if v_room.status in ('waiting', 'playing')
     and v_room.updated_at < now() - interval '2 hours' then
    update public.mp_rooms
    set status = 'abandoned', end_reason = 'expired', updated_at = now()
    where id = v_room.id;
    return jsonb_build_object('ok', false, 'reason', 'expired', 'seq', v_room.seq);
  end if;
  if v_room.status <> 'playing' then
    return jsonb_build_object('ok', false, 'reason', 'not_playing', 'seq', v_room.seq);
  end if;
  if p_seq <> v_room.seq + 1 then
    return jsonb_build_object('ok', false, 'reason', 'seq_mismatch', 'seq', v_room.seq);
  end if;
  if not (
       v_room.turn = v_side
       or (v_side = 0 and ((v_room.bots::integer >> v_room.turn) & 1) = 1)
     ) then
    return jsonb_build_object('ok', false, 'reason', 'not_your_turn', 'seq', v_room.seq);
  end if;
  if v_room.seq >= c_max_moves then
    return jsonb_build_object('ok', false, 'reason', 'too_long', 'seq', v_room.seq);
  end if;
  -- At most about 3 accepted moves a second per room.
  if v_room.last_move_at is not null
     and now() - v_room.last_move_at < interval '0.3 seconds' then
    return jsonb_build_object('ok', false, 'reason', 'too_fast', 'seq', v_room.seq);
  end if;
  v_by := v_room.turn;
  v_entry := jsonb_build_object('by', v_by, 'm', p_move);
  v_next := coalesce(p_next, ((v_by + 1) % v_room.seats)::smallint);
  update public.mp_rooms
  set moves = moves || jsonb_build_array(v_entry),
      seq = seq + 1,
      turn = v_next,
      last_move_at = now(),
      updated_at = now(),
      status = case when p_end is not null then 'done' else status end,
      winner = case when p_end = 'win' then v_by else null end,
      end_reason = case when p_end is not null then 'finish' else null end
  where id = v_room.id
  returning * into v_room;
  perform public.mp_notify('room:' || v_room.id::text, 'move',
    jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
  return jsonb_build_object('ok', true, 'seq', v_room.seq);
end
$$;

-- Leave.
-- seats = 2: unchanged (see 20261103120000_mp_rooms.sql).
-- seats > 2, waiting: the host leaving cancels the room ('abandoned'/'left');
--   a seated guest leaves his seat (later guests move up one seat, so seats stay
--   filled from 1 on); someone only invited declines (their invite is deleted,
--   the host cannot invite them again for 5 minutes).
-- seats > 2, playing: 'resign' ends the whole game with no winner ('abandoned'/
--   'left'); 'abort' = the seat whose turn it is belongs to another human (a
--   bot's turn belongs to the host), who has been silent for 1 minute
--   (last_move_at, else updated_at) -> 'abandoned'/'opponent_gone', else
--   'too_early'.
-- Leaving something already over just answers with the room.
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

  -- seats = 2: unchanged
  if v_room.status = 'waiting' then
    if v_room.invited = v_me and v_room.host <> v_me then
      insert into public.mp_declines (host, invited, until_at)
      values (v_room.host, v_me, now() + interval '5 minutes')
      on conflict (host, invited) do update set until_at = excluded.until_at;
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
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Housekeeping for the cron job (service_role only). Same as before, plus:
-- invites that belong to rooms that are no longer waiting are removed (rooms
-- deleted above take their invites with them through the cascade).
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
  return jsonb_build_object('expired', v_expired, 'deleted', v_deleted, 'invites', v_invites);
end
$$;

-- ── Realtime：四個位子都進得了 room:<id> ───────────────────────────────

drop policy "mp: players receive their room and their own channel" on realtime.messages;
create policy "mp: players receive their room and their own channel"
  on realtime.messages for select to authenticated
  using (
    realtime.messages.extension in ('broadcast', 'presence')
    and (
      (
        realtime.topic() like 'room:%'
        and exists (
          select 1 from public.mp_rooms r
          where r.id::text = substr(realtime.topic(), 6)
            and (
              r.host = (select auth.uid()) or r.guest = (select auth.uid())
              or r.guest2 = (select auth.uid()) or r.guest3 = (select auth.uid())
            )
        )
      )
      or realtime.topic() = 'user:' || (select auth.uid())::text
    )
  );

drop policy "mp: players send on their room" on realtime.messages;
create policy "mp: players send on their room"
  on realtime.messages for insert to authenticated
  with check (
    realtime.messages.extension in ('broadcast', 'presence')
    and realtime.topic() like 'room:%'
    and exists (
      select 1 from public.mp_rooms r
      where r.id::text = substr(realtime.topic(), 6)
        and (
          r.host = (select auth.uid()) or r.guest = (select auth.uid())
          or r.guest2 = (select auth.uid()) or r.guest3 = (select auth.uid())
        )
    )
  );

-- ── 執行權 ─────────────────────────────────────────────────────────────
-- 新函式預設開給 public／anon／authenticated；全部收回再逐支開。
-- （mp_seat_of、mp_free_seat 只在 security definer 函式裡用，policy 裡不用它們。）

revoke execute on function
  public.mp_seat_of(public.mp_rooms, uuid),
  public.mp_free_seat(public.mp_rooms),
  public.mp_pending_invites(uuid),
  public.mp_new_code(),
  public.mp_sit(uuid, uuid),
  public.mp_make_room(uuid, text, uuid, integer),
  public.mp_create_room(text, integer),
  public.mp_start(uuid),
  public.mp_invite_to(uuid, uuid),
  public.mp_expire(uuid),
  public.mp_gc(uuid),
  public.mp_live_count(uuid),
  public.mp_room_json(public.mp_rooms, uuid),
  public.mp_join_room(text, text),
  public.mp_invite(uuid, text),
  public.mp_my_invites(text),
  public.mp_accept_invite(uuid),
  public.mp_submit_move(uuid, integer, jsonb, smallint, text),
  public.mp_leave(uuid, text),
  public.mp_cleanup()
from public, anon, authenticated;

grant execute on function
  public.mp_create_room(text, integer),
  public.mp_join_room(text, text),
  public.mp_start(uuid),
  public.mp_invite(uuid, text),
  public.mp_invite_to(uuid, uuid),
  public.mp_my_invites(text),
  public.mp_accept_invite(uuid),
  public.mp_submit_move(uuid, integer, jsonb, smallint, text),
  public.mp_leave(uuid, text)
to authenticated;
grant execute on function public.mp_cleanup() to service_role;

commit;
