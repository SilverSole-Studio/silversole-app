-- supabase/migrations/20261104200000_mp_quick_match.sql
--
-- *** 還沒套用到任何 Supabase 專案；套用前要先問 user。 ***
-- 要先套好 20261019120000_friends.sql、20261026120000_friends_rpc_abuse.sql、
-- 20261103120000_mp_rooms.sql、20261104140000_mp_seats.sql、20261104180000_mp_presence.sql
-- （這支用到 mp_rooms、mp_make_room、mp_take、mp_notify、friends_blocked_either，並改寫 mp_cleanup）。
--
-- user 2026-11-04：「我想要我們遊戲可以用戶直接互相配對」。
-- 照一般遊戲的配對：按「快速配對」開始排隊，同一款遊戲有人就配在一起；沒配到就不能開始，
-- 排隊中可以取消。2 人遊戲（象棋、西洋棋、撞球）配到 1 人就開；4 人桌（台灣麻將、德州撲克）
-- 要湊滿 4 個真人才開，不補電腦。
--
-- 做法：
--   - 排隊表 mp_queue（每人一列，RLS 開、App 不能直接讀寫）。排隊的「組」＝(game, seats)：
--     象棋排象棋、4 人麻將只跟 4 人麻將配。
--   - mp_queue_join(game, seats)：在同一個交易裡用 advisory lock 鎖住這一組，找排隊最久、
--     彼此沒封鎖、而且最近還在線上（40 秒內報到過）的人，湊滿 seats 個（含自己）就用
--     mp_make_room 開一間「playing」的房（依排隊順序放進 host、guest、guest2、guest3，
--     房號清成 null：這種房不給人用房號進來），回 {ok, matched:true, room}。沒湊滿回
--     {ok, matched:false, waiting:N}。
--   - 先到的人怎麼知道配到了：他們的排隊列不刪，改成「信箱」（room 填房間、matched_at 填時間），
--     並推 Realtime user:<id> 的 'matched'。推播漏掉也沒關係：mp_queue_status（頁面排隊時
--     每幾秒問一次）會把信箱裡的房間交給他並刪掉那一列。
--   - mp_queue_status()：我還在排嗎、排了幾個人（讓畫面寫「已配到 N／4」）、或信箱裡有房間；
--     同時當作「我還在線上」的報到（seen_at，10 秒內重複問不再寫）。人數有變時 join／leave
--     也會推 'queue' 給同組排隊的人（最多 10 位），所以畫面通常不用等輪詢。
--   - mp_queue_leave()：取消排隊。取消的瞬間剛好被配走，就回 {matched:true, room}，畫面照樣進對局。
--   - mp_room_peers(room)：房間成員（不含自己）的暱稱與預設頭像編號，給對局畫面顯示。
--     只有房裡的人問得到；只回 nickname／avatar_preset，沒有照片路徑、好友碼。
--   - 排隊超過 10 分鐘自動失效（join／status 順手清、mp_cleanup 也清）。
--
-- RPC 濫用自查（2026-10-26 清單）：
--   - 每支 RPC 先 mp_take 拿自己的 mp_limits 鎖（join 5、leave 3、status 1、peers 2），
--     回傳 jsonb {ok, reason}，不 raise；security definer、set search_path = ''、只 grant authenticated。
--   - 並發：join 在 (game, seats) 的 advisory lock 下配對，兩個人同時按只會有一個人看到對方
--     （後拿到鎖的那個配成功）；候選人的列 for update，所以對方同一瞬間按取消，不是被配走就是
--     取消成功，不會「取消了還被配」。一個人一列（user_id 主鍵）：重複按、換款都只更新那一列。
--   - 分身：沒有金幣、鑽石、經驗，配對只是開一局，分身自己配自己沒好處；一個人開很多帳號排隊
--     也只是佔住位子，每個帳號各有自己的限流與 3 間房上限。（已知限制：無法阻止一個人用分身
--     排滿一組，讓別人一直配到他。）
--   - 封鎖：候選人跟我（以及已選上的人）任何一對有封鎖就不配；不是好友也能配（陌生人配對）。
--   - 房間上限：我和每個候選人都要「同時活著的房間 < 3」（先 mp_expire 結束過期的房）；
--     房主的舊房間照 mp_gc 清。
--   - 通知放大：join／leave 最多通知同組 10 人，所以 leave 花 3、join 花 5。
--   - 伺服器不信頁面：seats 只收 2..4、game 只收 mp_game_ok；只有排的人本人能問自己的狀態。

begin;

-- ── 表 ──────────────────────────────────────────────────────────────────

create table public.mp_queue (
  user_id uuid primary key references auth.users (id) on delete cascade,
  game text not null check (game ~ '^[a-z0-9_-]{1,32}$'),
  seats smallint not null check (seats between 2 and 4),
  joined_at timestamptz not null default now(),
  -- 最後一次在線上（join／status 更新）；40 秒沒報到的人不會被配。
  seen_at timestamptz not null default now(),
  -- 信箱：配到了就填房間（這一列不再算排隊中），本人下次 status／join 領走後刪除。
  room uuid references public.mp_rooms (id) on delete cascade,
  matched_at timestamptz,
  check ((room is null) = (matched_at is null))
);
create index mp_queue_group_idx on public.mp_queue (game, seats, joined_at)
  where room is null;

alter table public.mp_queue enable row level security;
revoke all on public.mp_queue from anon, authenticated;

-- ── 內部小工具（不開放給 App）────────────────────────────────────────────

-- 這一組現在排隊中的人數（10 分鐘內加入、40 秒內報到過、還沒被配走）。
create function public.mp_queue_count(p_game text, p_seats integer)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.mp_queue
  where game = p_game and seats = p_seats and room is null
    and joined_at >= now() - interval '10 minutes'
    and seen_at >= now() - interval '40 seconds'
$$;

-- 告訴同組排隊的人現在有幾個人（最多 10 位；p_except 不通知，通常是剛動作的那位）。
create function public.mp_queue_tell(p_game text, p_seats integer, p_except uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_n integer := public.mp_queue_count(p_game, p_seats);
  v_id uuid;
begin
  for v_id in
    select user_id from public.mp_queue
    where game = p_game and seats = p_seats and room is null
      and joined_at >= now() - interval '10 minutes'
      and seen_at >= now() - interval '40 seconds'
      and user_id is distinct from p_except
    order by joined_at
    limit 10
  loop
    perform public.mp_notify('user:' || v_id::text, 'queue',
      jsonb_build_object('game', p_game, 'seats', p_seats, 'waiting', v_n));
  end loop;
end
$$;

-- ── 給 App／網頁呼叫 ───────────────────────────────────────────────────

-- 開始排隊（或換組、或重按）。
--   {ok:true, matched:true, room}                       配到了（room.side＝我的位子）
--   {ok:true, matched:false, waiting:N, seats}          還在等（N＝同組排隊人數，含我）
--   {ok:false, reason: signed_out | rate_limited | bad_game | bad_seats |
--                      too_many_rooms | no_code}
create function public.mp_queue_join(p_game text, p_seats integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_box public.mp_queue;
  v_old public.mp_queue;
  v_room public.mp_rooms;
  v_c record;
  v_ids uuid[] := array[]::uuid[];
  v_all uuid[];
  v_id uuid;
  v_ok boolean;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 5) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if not public.mp_game_ok(p_game) then
    return jsonb_build_object('ok', false, 'reason', 'bad_game');
  end if;
  if p_seats is null or p_seats < 2 or p_seats > 4 then
    return jsonb_build_object('ok', false, 'reason', 'bad_seats');
  end if;

  -- 信箱裡還有沒領的房間：這一款、還在打 → 直接交給他（連按兩次不會排到第二局）；
  -- 其他一律丟掉，重新排。
  select * into v_box from public.mp_queue where user_id = v_me and room is not null;
  if found then
    delete from public.mp_queue where user_id = v_me;
    select * into v_room from public.mp_rooms r
    where r.id = v_box.room and r.game = p_game and r.status = 'playing'
      and public.mp_seat_of(r, v_me) is not null
      and v_box.matched_at > now() - interval '10 minutes';
    if found then
      return jsonb_build_object('ok', true, 'matched', true,
        'room', public.mp_room_json(v_room, v_me));
    end if;
  end if;

  perform public.mp_expire(v_me);
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;

  -- 換組：先離開舊的那組（舊組的人看到人數少一個）。
  delete from public.mp_queue
  where user_id = v_me and room is null and (game <> p_game or seats <> p_seats)
  returning * into v_old;
  if found then
    perform public.mp_queue_tell(v_old.game, v_old.seats::integer, v_me);
  end if;

  -- 這一組一次只讓一個人配對。
  perform pg_advisory_xact_lock(hashtextextended('mp-queue:' || p_game || ':' || p_seats::text, 0));

  -- 順手清這一組過期的（排太久的、沒領的信箱）。
  delete from public.mp_queue
  where game = p_game and seats = p_seats
    and ((room is null and joined_at < now() - interval '10 minutes')
      or (room is not null and matched_at < now() - interval '10 minutes'));

  -- 我進隊伍（已經在這一組就保留原本的排隊時間，重按不會插隊也不會掉到最後）。
  insert into public.mp_queue (user_id, game, seats, joined_at, seen_at)
  values (v_me, p_game, p_seats::smallint, now(), now())
  on conflict (user_id) do update set seen_at = now();

  -- 找人：排最久的先看，要沒封鎖（跟我、跟已選上的）、房間沒滿 3 間、最近還在線上。
  for v_c in
    select q.user_id from public.mp_queue q
    where q.game = p_game and q.seats = p_seats and q.room is null
      and q.user_id <> v_me
      and q.joined_at >= now() - interval '10 minutes'
      and q.seen_at >= now() - interval '40 seconds'
    order by q.joined_at, q.user_id
    limit 30
    for update
  loop
    exit when cardinality(v_ids) >= p_seats - 1;
    if public.friends_blocked_either(v_me, v_c.user_id) then
      continue;
    end if;
    v_ok := true;
    foreach v_id in array v_ids loop
      if public.friends_blocked_either(v_id, v_c.user_id) then
        v_ok := false;
        exit;
      end if;
    end loop;
    if not v_ok then
      continue;
    end if;
    perform public.mp_expire(v_c.user_id);
    if public.mp_live_count(v_c.user_id) >= 3 then
      continue;
    end if;
    v_ids := v_ids || v_c.user_id;
  end loop;

  if cardinality(v_ids) < p_seats - 1 then
    perform public.mp_queue_tell(p_game, p_seats, v_me);
    return jsonb_build_object('ok', true, 'matched', false,
      'waiting', public.mp_queue_count(p_game, p_seats), 'seats', p_seats);
  end if;

  -- 湊滿了：依排隊順序入座（排最久的當房主）。
  select array_agg(q.user_id order by q.joined_at, q.user_id) into v_all
  from public.mp_queue q
  where q.user_id = any (v_ids || v_me);
  perform public.mp_gc(v_all[1]);
  v_room := public.mp_make_room(v_all[1], p_game, null, p_seats);
  if v_room.id is null then
    return jsonb_build_object('ok', false, 'reason', 'no_code');
  end if;
  update public.mp_rooms
  set guest = v_all[2],
      guest2 = case when p_seats >= 3 then v_all[3] end,
      guest3 = case when p_seats >= 4 then v_all[4] end,
      status = 'playing', turn = 0, bots = 0,
      code = null,
      updated_at = now()
  where id = v_room.id
  returning * into v_room;

  update public.mp_queue
  set room = v_room.id, matched_at = now()
  where user_id = any (v_ids);
  delete from public.mp_queue where user_id = v_me;
  foreach v_id in array v_ids loop
    perform public.mp_notify('user:' || v_id::text, 'matched',
      jsonb_build_object('room', v_room.id, 'game', p_game));
  end loop;
  return jsonb_build_object('ok', true, 'matched', true,
    'room', public.mp_room_json(v_room, v_me));
end
$$;

-- 取消排隊。
--   {ok:true, matched:false}                    取消了（本來就沒在排也是 ok）
--   {ok:true, matched:true, room}               取消的瞬間剛好被配走了：房間交給你
--   {ok:false, reason: signed_out | rate_limited}
create function public.mp_queue_leave()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_row public.mp_queue;
  v_room public.mp_rooms;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  -- 只刪「還在排」的那一列；配對那邊對候選人列 for update，所以兩邊只會有一個贏。
  delete from public.mp_queue
  where user_id = v_me and room is null
  returning * into v_row;
  if found then
    perform public.mp_queue_tell(v_row.game, v_row.seats::integer, v_me);
    return jsonb_build_object('ok', true, 'matched', false);
  end if;
  -- 沒有排隊列，或已經被配走（信箱）：把房間交出來。
  select * into v_row from public.mp_queue where user_id = v_me and room is not null;
  if found then
    delete from public.mp_queue where user_id = v_me;
    select * into v_room from public.mp_rooms r
    where r.id = v_row.room and r.status = 'playing'
      and public.mp_seat_of(r, v_me) is not null
      and v_row.matched_at > now() - interval '10 minutes';
    if found then
      return jsonb_build_object('ok', true, 'matched', true,
        'room', public.mp_room_json(v_room, v_me));
    end if;
  end if;
  return jsonb_build_object('ok', true, 'matched', false);
end
$$;

-- 我排得怎麼樣（頁面排隊時每幾秒問一次，也當「我還在線上」）。
--   {ok:true, queued:true, matched:false, game, seats, waiting:N}   還在排
--   {ok:true, queued:false, matched:true, room}                     配到了（領走，信箱刪掉）
--   {ok:true, queued:false, matched:false[, expired:true]}          沒在排（或排太久失效了）
--   {ok:false, reason: signed_out | rate_limited}
create function public.mp_queue_status()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_row public.mp_queue;
  v_room public.mp_rooms;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select * into v_row from public.mp_queue where user_id = v_me;
  if not found then
    return jsonb_build_object('ok', true, 'queued', false, 'matched', false);
  end if;
  if v_row.room is not null then
    delete from public.mp_queue where user_id = v_me and room is not null;
    select * into v_room from public.mp_rooms r
    where r.id = v_row.room
      and public.mp_seat_of(r, v_me) is not null
      and v_row.matched_at > now() - interval '10 minutes';
    if found then
      return jsonb_build_object('ok', true, 'queued', false, 'matched', true,
        'room', public.mp_room_json(v_room, v_me));
    end if;
    return jsonb_build_object('ok', true, 'queued', false, 'matched', false);
  end if;
  if v_row.joined_at < now() - interval '10 minutes' then
    delete from public.mp_queue where user_id = v_me and room is null;
    return jsonb_build_object('ok', true, 'queued', false, 'matched', false, 'expired', true);
  end if;
  -- 10 秒內重複問不再寫（亂打也寫不爆）
  update public.mp_queue set seen_at = now()
  where user_id = v_me and room is null and seen_at < now() - interval '10 seconds';
  return jsonb_build_object('ok', true, 'queued', true, 'matched', false,
    'game', v_row.game, 'seats', v_row.seats,
    'waiting', greatest(public.mp_queue_count(v_row.game, v_row.seats::integer), 1));
end
$$;

-- 同房的人叫什麼名字、什麼頭像（不含自己）：[{seat, id, name, avatar}]。
--   avatar＝預設頭像編號 1..12（不給照片路徑）。
--   {ok:true, peers} | {ok:false, reason: signed_out | rate_limited | not_found}
create function public.mp_room_peers(p_room uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_room public.mp_rooms;
  v_peers jsonb;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 2) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select * into v_room from public.mp_rooms r
  where r.id = p_room and public.mp_seat_of(r, v_me) is not null;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'seat', m.seat,
      'id', m.uid,
      'name', coalesce(p.nickname, '銀足朋友'),
      'avatar', coalesce(p.avatar_preset, 1)
    ) order by m.seat), '[]'::jsonb)
  into v_peers
  from (values
    (0, v_room.host), (1, v_room.guest), (2, v_room.guest2), (3, v_room.guest3)
  ) as m (seat, uid)
  left join public.profiles p on p.user_id = m.uid
  where m.uid is not null and m.uid <> v_me;
  return jsonb_build_object('ok', true, 'peers', v_peers);
end
$$;

-- Housekeeping (service_role only): same as 20261104180000_mp_presence.sql, plus
-- queue rows that waited more than 10 minutes and mailboxes nobody collected.
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
  delete from public.mp_queue
  where (room is null and joined_at < now() - interval '10 minutes')
     or (room is not null and matched_at < now() - interval '10 minutes');
  return jsonb_build_object('expired', v_expired, 'deleted', v_deleted, 'invites', v_invites);
end
$$;

-- ── 執行權 ─────────────────────────────────────────────────────────────
-- 新函式預設開給 public／anon／authenticated；全部收回再逐支開。
-- （mp_queue_count、mp_queue_tell 只在 security definer 函式裡用；
--   mp_cleanup 是 create or replace，原本只開給 service_role 不變。）

revoke execute on function
  public.mp_queue_count(text, integer),
  public.mp_queue_tell(text, integer, uuid),
  public.mp_queue_join(text, integer),
  public.mp_queue_leave(),
  public.mp_queue_status(),
  public.mp_room_peers(uuid)
from public, anon, authenticated;

grant execute on function
  public.mp_queue_join(text, integer),
  public.mp_queue_leave(),
  public.mp_queue_status(),
  public.mp_room_peers(uuid)
to authenticated;

commit;
