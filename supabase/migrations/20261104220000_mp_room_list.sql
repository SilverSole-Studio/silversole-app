-- supabase/migrations/20261104220000_mp_room_list.sql
--
-- *** 還沒套用到任何 Supabase 專案；套用前要先問 user。 ***
-- 要先套好 20261019120000_friends.sql、20261026120000_friends_rpc_abuse.sql、
-- 20261103120000_mp_rooms.sql、20261104140000_mp_seats.sql、20261104180000_mp_presence.sql、
-- 20261104200000_mp_quick_match.sql（這支用到 mp_rooms、mp_take、mp_sit、mp_seat_of、
-- mp_free_seat、mp_notify、are_friends、friends_blocked_either，並改寫 mp_create_room、mp_join_room）。
--
-- user 2026-11-04：「交誼廳才要做房間機制：各個遊戲都可以建立房間，然後交誼廳就可以自己選」。
-- 小鎮的「交誼廳」變成房間大廳：列出現在等人的房間，按「加入」就入座。
--
-- 做了什麼：
--   - mp_rooms 加 visibility：'public'（所有人看得到，預設）或 'friends'（只給房主的好友）。
--     舊房間照預設 public；有 invited 的 2 人房（mp_invite 開的）是點名邀請，不上列表；
--     快速配對開的房一開始就是 playing，所以也不會出現。
--   - mp_create_room(p_game, p_seats = 2, p_visibility = 'public')：多一個可選參數。舊的
--     兩參數呼叫照舊（走預設值）。
--   - mp_list_rooms(p_game = null)：列出「等人、還有空位、10 分鐘內有動靜」的房，最多 50 筆。
--     排除自己開的／自己已坐的、跟房裡任何一位有封鎖關係的；friends 房只給房主的好友看。
--     好友的房排在前面，同類裡新的在前（所以陌生人開一堆房也擠不掉好友的房）。
--     每個房主最多列一間（最新的那間），一個人開 3 間也只佔一格。
--     每筆：{id, game, seats, seated, hostName, hostAvatar, friend, visibility, createdAt}。
--     不回房主的 user id、房號，也沒有照片路徑；只有暱稱和預設頭像編號（1..12）。
--   - mp_join_listed(p_room)：從列表加入，不用房號。入座規則跟 mp_join_room 一樣
--     （2 人房 guest 入座並開打；多人房坐最小號空位，坐滿自動開打），並且再檢查一次
--     visibility、封鎖、10 分鐘內有動靜。
--   - mp_join_room（用房號加入）也補上同樣的限制：friends 房只有房主的好友進得來、
--     跟房裡任何人有封鎖的進不來（都回 bad_code，算一次猜錯）。否則「只給好友」只擋得了列表，
--     擋不了猜房號。已經坐在裡面的人不受影響（掉了回應重按仍然 ok）。
--
-- RPC 濫用自查（2026-10-26 清單）：
--   - 限流：三支都先 mp_take 拿自己的 mp_limits 鎖（list 花 3、join_listed 花 3、create 照舊 10）；
--     一個人的呼叫排隊執行，額度在鎖裡扣。回傳 jsonb {ok, reason}，不 raise。
--   - 並發搶最後一個位子：mp_join_listed 對房間列 for update，第二個人進來時位子已被坐走，
--     回 'full'；多人房最後一個位子也一樣（mp_sit 在同一把鎖裡）。一人最多同時活 3 間房，
--     入座前先數。
--   - 伺服器不信頁面：p_game 只收 mp_game_ok；visibility 只收 'public'／'friends'；
--     p_room 是 uuid，亂打不存在的、別人的 friends 房、被封鎖的房、點名邀請的房，
--     一律回同一個 'gone'，問不出房間存不存在。
--   - 封鎖：列表與入座都檢查房主和已入座的人；被封鎖的人看不到這間房，也加不進去。
--   - 分身：開很多帳號各開房只會各佔一格列表（每人 1 格、50 筆上限、好友優先），
--     沒有金幣／鑽石／經驗，入座不領任何東西。（已知限制：陌生人分身仍可把「公開房間」
--     一頁塞滿，擠掉別的公開房；好友的房不會被擠掉。）
--   - 資料外洩：列表只回暱稱與預設頭像編號；不回 user id、房號；friends 房只有好友問得到。
--   - 列表只看得到 waiting；超過 10 分鐘沒動的房間不出現（房主久等的房，用房號仍可加入）。
--
-- 套用前核對：
--   select column_name from information_schema.columns
--   where table_name = 'mp_rooms' and column_name = 'visibility';   -- 預期 0 列

begin;

-- ── 表 ──────────────────────────────────────────────────────────────────

alter table public.mp_rooms
  add column visibility text not null default 'public'
    check (visibility in ('public', 'friends'));

-- 列表只看 waiting、沒點名邀請、最近有動靜的房。
create index mp_rooms_listed_idx on public.mp_rooms (updated_at desc)
  where status = 'waiting' and invited is null;

-- ── 內部小工具（不開放給 App）────────────────────────────────────────────

-- p_me 跟這間房的房主或任何一位已入座的人有封鎖關係（任一方向）。
create function public.mp_room_blocked(r public.mp_rooms, p_me uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.friends_blocked_either(p_me, r.host)
    or (r.guest is not null and public.friends_blocked_either(p_me, r.guest))
    or (r.guest2 is not null and public.friends_blocked_either(p_me, r.guest2))
    or (r.guest3 is not null and public.friends_blocked_either(p_me, r.guest3))
$$;

-- ── 給 App／網頁呼叫 ───────────────────────────────────────────────────

-- New room. p_seats 2..4 (default 2), p_visibility 'public' (default) | 'friends'.
--   {ok:true, room} | {ok:false, reason: signed_out | rate_limited | bad_game |
--                      bad_seats | bad_visibility | too_many_rooms | no_code}
-- Same as 20261104140000_mp_seats.sql, plus the visibility. Calls with two
-- arguments still work (public).
drop function public.mp_create_room(text, integer);
create function public.mp_create_room(
  p_game text, p_seats integer default 2, p_visibility text default 'public'
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_vis text := coalesce(p_visibility, 'public');
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
  if v_vis not in ('public', 'friends') then
    return jsonb_build_object('ok', false, 'reason', 'bad_visibility');
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
  if v_vis <> v_room.visibility then
    update public.mp_rooms set visibility = v_vis where id = v_room.id
    returning * into v_room;
  end if;
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Rooms waiting for people (the 交誼廳 list).
--   {ok:true, rooms:[{id, game, seats, seated, hostName, hostAvatar, friend,
--                     visibility, createdAt}, ...]}
--   {ok:false, reason: signed_out | rate_limited | bad_game}
-- Friends' rooms first, then newest first; at most 50; one room per host.
create function public.mp_list_rooms(p_game text default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_rooms jsonb;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if p_game is not null and not public.mp_game_ok(p_game) then
    return jsonb_build_object('ok', false, 'reason', 'bad_game');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', x.id,
      'game', x.game,
      'seats', x.seats,
      'seated', x.seated,
      'hostName', coalesce(x.nickname, '銀足朋友'),
      'hostAvatar', coalesce(x.avatar_preset, 1),
      'friend', x.is_friend,
      'visibility', x.visibility,
      'createdAt', x.created_at
    ) order by x.is_friend desc, x.created_at desc, x.id), '[]'::jsonb)
  into v_rooms
  from (
    select d.*
    from (
      select distinct on (r.host)
        r.id, r.game, r.seats, r.visibility, r.created_at,
        (1 + (r.guest is not null)::integer + (r.guest2 is not null)::integer
           + (r.guest3 is not null)::integer) as seated,
        p.nickname, p.avatar_preset, f.is_friend
      from public.mp_rooms r
      left join public.profiles p on p.user_id = r.host
      cross join lateral (select public.are_friends(v_me, r.host) as is_friend) f
      where r.status = 'waiting'
        and r.invited is null
        and r.updated_at >= now() - interval '10 minutes'
        and r.host <> v_me
        and public.mp_seat_of(r, v_me) is null
        and public.mp_free_seat(r) is not null
        and (p_game is null or r.game = p_game)
        and not public.mp_room_blocked(r, v_me)
        and (r.visibility = 'public' or f.is_friend)
      order by r.host, r.created_at desc, r.id
    ) d
    order by d.is_friend desc, d.created_at desc, d.id
    limit 50
  ) x;
  return jsonb_build_object('ok', true, 'rooms', v_rooms);
end
$$;

-- Join a room from the list (no code).
--   {ok:true, room} | {ok:false, reason: signed_out | rate_limited | gone | full |
--                      own_room | too_many_rooms}
-- 'gone' = no such room, or not for me (friends-only and not a friend, blocked,
-- a personal invite, not waiting any more, quiet for 10 minutes): one answer for
-- all of them. 'full' = a room I could see but the last seat just went.
-- Already seated (an answer got lost) = ok, no cost.
create function public.mp_join_listed(p_room uuid)
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
  if p_room is null then
    return jsonb_build_object('ok', false, 'reason', 'gone');
  end if;
  perform public.mp_expire(v_me);
  select * into v_room from public.mp_rooms where id = p_room for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'gone');
  end if;
  if v_room.host = v_me then
    return jsonb_build_object('ok', false, 'reason', 'own_room');
  end if;
  -- already sitting here: nothing changes
  if public.mp_seat_of(v_room, v_me) is not null
     and v_room.status in ('waiting', 'playing') then
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;
  if v_room.invited is not null
     or v_room.updated_at < now() - interval '10 minutes'
     or public.mp_room_blocked(v_room, v_me)
     or (v_room.visibility = 'friends' and not public.are_friends(v_me, v_room.host)) then
    return jsonb_build_object('ok', false, 'reason', 'gone');
  end if;
  if v_room.status in ('done', 'abandoned') then
    return jsonb_build_object('ok', false, 'reason', 'gone');
  end if;
  -- playing = the last seat went while I was looking at the list
  if v_room.status <> 'waiting' or public.mp_free_seat(v_room) is null then
    return jsonb_build_object('ok', false, 'reason', 'full');
  end if;
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;
  if v_room.seats > 2 then
    v_room := public.mp_sit(v_room.id, v_me);
  else
    update public.mp_rooms
    set guest = v_me, status = 'playing', turn = 0, updated_at = now()
    where id = v_room.id
    returning * into v_room;
  end if;
  perform public.mp_notify('room:' || v_room.id::text, 'joined',
    jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Join by 4-digit code. Same as 20261104140000_mp_seats.sql, plus: a friends-only
-- room only lets the host's friends in, and nobody who is blocked either way
-- with the host or a seated player (both answer 'bad_code' and count as a wrong
-- guess). People already seated are not affected.
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
  -- friends-only / blocked: not for me (people already seated keep their seat)
  if public.mp_seat_of(v_room, v_me) is null
     and (public.mp_room_blocked(v_room, v_me)
          or (v_room.visibility = 'friends'
              and not public.are_friends(v_me, v_room.host))) then
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

-- ── 執行權 ─────────────────────────────────────────────────────────────
-- 新函式預設開給 public／anon／authenticated；全部收回再逐支開。
-- （mp_room_blocked 只在 security definer 函式裡用；mp_join_room 是 create or replace，
--   原本的執行權不變。）

revoke execute on function
  public.mp_room_blocked(public.mp_rooms, uuid),
  public.mp_create_room(text, integer, text),
  public.mp_list_rooms(text),
  public.mp_join_listed(uuid)
from public, anon, authenticated;

grant execute on function
  public.mp_create_room(text, integer, text),
  public.mp_list_rooms(text),
  public.mp_join_listed(uuid)
to authenticated;

commit;
