-- supabase/migrations/20261111100000_mp_queue_fill.sql
--
-- 2026-11-11 user 同意後已套用到正式庫（buvdyjzxeojpuiqeyteh），這個檔案讓 repo 跟正式庫一致。
-- 要先套好 20261104200000_mp_quick_match.sql（用到 mp_queue、mp_queue_count、mp_queue_tell、mp_make_room、
-- mp_expire、mp_live_count、mp_gc、mp_take、mp_game_ok、mp_room_json、mp_notify、friends_blocked_either）。
--
-- user 2026-11-11：4 人桌（麻將、德州、大老二、排七、21 點）快速配對，排隊 30 秒還沒湊滿，
-- 就用已經配到的真人（至少 2 人）開局、空位電腦補；30 秒內湊滿 4 人照舊直接開。
--
-- 為什麼一定要改伺服器：電腦補位要靠 mp_rooms.bots（位元遮罩）＋ seats＝4，伺服器才准房主替電腦送步；
-- 現有快速配對開的房 bots 一律 0，客戶端自己加遮罩的話 mp_submit_move 會擋（bots 的位元要在 seats 範圍內）。
-- 用「改排 2 人組」的做法也行不通：4 人組與 2 人組是不同排隊組，兩邊會互相錯過，而且 2 人房沒有座位給電腦。
--
-- 做法：新增一支 mp_queue_fill(p_game, p_seats)。客戶端排滿 30 秒、而且同組已有 2 人以上時叫它：
--   - 呼叫者必須自己在這一組排隊、排了至少 25 秒（伺服器自己算，不信客戶端的 30 秒；留 5 秒給網路延遲）。
--   - 同一把 advisory lock（跟 mp_queue_join 同一個 key），所以不會跟「剛好湊滿 4 人」同時開出兩間房。
--   - 照 mp_queue_join 的挑人規則（排最久的先、40 秒內報到過、沒封鎖、房間 < 3），最多挑 p_seats 位（含自己），
--     至少 2 位；不足就回 {ok:true, matched:false}，繼續排。
--   - 開 playing 的房，依排隊順序入座，空位 bots 位元遮罩（跟 mp_start 同規則）；code 清成 null。
--   - 其他被挑上的人：排隊列改成信箱、推 'matched'，跟 mp_queue_join 一樣由 mp_queue_status 領走。
--   - 沒被挑上（被封鎖、房間滿）的人留在隊伍裡。
--
-- RPC 濫用自查（2026-10-26 清單）：
--   - 限流：先 mp_take(自己, 5)；回 jsonb {ok, reason}，不 raise；security definer、set search_path = ''、只 grant authenticated。
--   - 並發：advisory lock ＋ 候選人列 for update；兩個人同時叫 fill，後拿到鎖的人看到的是信箱（自己已被配走），
--     回 {ok:true, matched:true, room}，不會開兩間。
--   - 分身：自己的分身排滿 25 秒才能叫；一個人叫 fill 最多把「已經在排的真人」拉進一間有電腦的局，沒有金幣／經驗收益。
--     （已知限制：分身可以排進同組、讓真人被配成「1 真人＋1 分身＋電腦」；跟現有 mp_queue_join 同一個限制。）
--   - 伺服器不信頁面：p_seats 只收 3..4、p_game 只收 mp_game_ok、「排滿多久」自己算。

begin;

create function public.mp_queue_fill(p_game text, p_seats integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_mine public.mp_queue;
  v_box public.mp_queue;
  v_room public.mp_rooms;
  v_c record;
  v_ids uuid[] := array[]::uuid[];
  v_all uuid[];
  v_id uuid;
  v_ok boolean;
  v_bots integer := 0;
  v_k integer;
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
  if p_seats is null or p_seats < 3 or p_seats > 4 then
    return jsonb_build_object('ok', false, 'reason', 'bad_seats');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('mp-queue:' || p_game || ':' || p_seats::text, 0));

  -- 已經被別人叫的 fill／join 配走了：信箱裡的房間交給他。
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
    return jsonb_build_object('ok', true, 'matched', false);
  end if;

  select * into v_mine from public.mp_queue
  where user_id = v_me and room is null and game = p_game and seats = p_seats
    and joined_at >= now() - interval '10 minutes';
  if not found then
    return jsonb_build_object('ok', true, 'matched', false);
  end if;
  if v_mine.joined_at > now() - interval '25 seconds' then
    return jsonb_build_object('ok', true, 'matched', false,
      'waiting', public.mp_queue_count(p_game, p_seats), 'seats', p_seats);
  end if;

  perform public.mp_expire(v_me);
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;

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

  -- 至少 2 位真人（含自己）才開
  if cardinality(v_ids) < 1 then
    return jsonb_build_object('ok', true, 'matched', false,
      'waiting', public.mp_queue_count(p_game, p_seats), 'seats', p_seats);
  end if;

  select array_agg(q.user_id order by q.joined_at, q.user_id) into v_all
  from public.mp_queue q
  where q.user_id = any (v_ids || v_me);
  perform public.mp_gc(v_all[1]);
  v_room := public.mp_make_room(v_all[1], p_game, null, p_seats);
  if v_room.id is null then
    return jsonb_build_object('ok', false, 'reason', 'no_code');
  end if;
  -- 空位是電腦：bits（第 k 位＝座位 k；0 號是房主不會是電腦），跟 mp_start 同規則
  for v_k in cardinality(v_all)..(p_seats - 1) loop
    v_bots := v_bots | (1 << v_k);
  end loop;
  update public.mp_rooms
  set guest = v_all[2],
      guest2 = case when cardinality(v_all) >= 3 then v_all[3] end,
      guest3 = case when cardinality(v_all) >= 4 then v_all[4] end,
      status = 'playing', turn = 0, bots = v_bots::smallint,
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

revoke execute on function public.mp_queue_fill(text, integer) from public, anon, authenticated;
grant execute on function public.mp_queue_fill(text, integer) to authenticated;

commit;
