-- supabase/migrations/20261103120000_mp_rooms.sql
--
-- *** 還沒套用到任何 Supabase 專案；套用前要先問 user。 ***
-- 要先套好 20261019120000_friends.sql 與 20261026120000_friends_rpc_abuse.sql
-- （這支用到 profiles／friendships／blocks 與 are_friends()）。
--
-- Online play base (user 2026-11-03): every H5 game should be playable against a
-- friend. This is the shared layer; xiangqi is the first game on it.
-- Design: 動域科技/02_產品/鞋墊_SilverSole/_聯機設計_2026-11-03.md
--
--   - One table `mp_rooms` (a room = two players + the full move list). The
--     two players can read it (RLS); nobody can write it directly.
--   - Everything that changes a room is an RPC: mp_create_room, mp_join_room,
--     mp_invite, mp_my_invites, mp_accept_invite, mp_submit_move, mp_leave.
--     They all return jsonb {ok, reason?, ...} and only raise for a bug,
--     because a raised error rolls back the counters that punish abuse.
--   - Realtime: the RPCs push a small "something changed" message on the
--     private channel `room:<id>` (and `user:<id>` for an invite) with
--     realtime.send(); the pages answer it by reading the room again. A page
--     never trusts a message as a move, only the stored move list. RLS on
--     realtime.messages lets only the room's two players in. If realtime.send
--     is missing or fails, the move is still stored and the page falls back to
--     polling (the push is wrapped so it can never undo a move).
--
-- Written against the RPC abuse checklist (2026-10-26 audit): callers can hit
-- the API directly, in parallel, from many accounts.
--   - The server decides whose turn it is and the next seq; the page is not
--     trusted. A resend of the same move is a no-op (idempotent); a different
--     move for a taken seq is refused.
--   - Every RPC takes the caller's row in mp_limits `for update` first (a
--     per-user token bucket, its own table), so one person's calls are served
--     one after the other and quotas are counted inside that lock.
--   - Room codes: 6 digits, unique among live rooms. Guessing is limited by
--     join_fails / join_locked_until in mp_limits, which belong to the person
--     and are kept apart from rooms: leaving, finishing or deleting rooms
--     cannot wipe them, and a successful join does not reset them (only time
--     does), so "guess, join one of my own rooms, guess again" does not work.
--   - A failed join returns {ok:false} instead of raising, so its counter
--     survives.
--   - Row caps: at most 3 live rooms per person, at most 20 finished rooms
--     kept per host (older ones are deleted when the host makes a new room),
--     a move is at most 256 bytes, a room at most 1000 moves.
--   - Invites go only to friends who have not blocked/been blocked, one pending
--     invite per (host, friend), at most 5 pending per friend (counted under a
--     lock on the friend), cancelling does not give the cost back, and a decline
--     starts a cool-down kept in its own table.
--   - A room that has not moved for 2 hours is void.
--   - No coins, diamonds or xp come from this. Wins are only a record on the
--     phones, so the server does not have to know the rules of each game.
--
-- Known limits (also in the PR text):
--   - The server does not check that a move is legal in the game. Both pages
--     check every move of the other side and stop on an illegal one.
--   - Finished rooms older than 14 days and stale live rooms are removed by
--     mp_cleanup() (service_role only). Nothing schedules it yet; add pg_cron
--     when this goes live (the caps above already bound the rows per person).

begin;

-- ── 表 ──────────────────────────────────────────────────────────────────

create table public.mp_rooms (
  id uuid primary key default gen_random_uuid(),
  game text not null check (game ~ '^[a-z0-9_-]{1,32}$'),
  -- 6 digits, no leading zero; unique among live rooms (index below).
  code text check (code ~ '^[1-9][0-9]{5}$'),
  host uuid not null references auth.users (id) on delete cascade,
  guest uuid references auth.users (id) on delete cascade,
  -- Set by mp_invite: only this friend may join (by invite or by the code).
  invited uuid references auth.users (id) on delete set null,
  status text not null default 'waiting'
    check (status in ('waiting', 'playing', 'done', 'abandoned')),
  -- Number of accepted moves; moves[seq - 1] is the last one.
  seq integer not null default 0 check (seq between 0 and 1000),
  -- [{"by": 0|1, "m": <the game's own move>}, ...]; by 0 = host, 1 = guest.
  moves jsonb not null default '[]'::jsonb,
  -- Side to move: 0 = host, 1 = guest.
  turn smallint not null default 0 check (turn in (0, 1)),
  winner smallint check (winner in (0, 1)),
  end_reason text
    check (end_reason in ('finish', 'resign', 'left', 'expired', 'opponent_gone')),
  last_move_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (guest is null or guest <> host),
  check (invited is null or invited <> host),
  check (status <> 'playing' or guest is not null),
  check (jsonb_typeof(moves) = 'array')
);
create unique index mp_rooms_live_code on public.mp_rooms (code)
  where code is not null and status in ('waiting', 'playing');
create index mp_rooms_host_idx on public.mp_rooms (host, status);
create index mp_rooms_guest_idx on public.mp_rooms (guest) where guest is not null;
create index mp_rooms_invited_idx on public.mp_rooms (invited, status)
  where invited is not null;

alter table public.mp_rooms enable row level security;
revoke all on public.mp_rooms from anon, authenticated;
grant select on public.mp_rooms to authenticated;
-- Only the two players read a room. Nothing else: no insert/update/delete.
create policy mp_rooms_select_players on public.mp_rooms
  for select to authenticated
  using (host = (select auth.uid()) or guest = (select auth.uid()));

-- Per person: the token bucket and the join-guess punishment. Not tied to any
-- room, so no room action can reset it.
create table public.mp_limits (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tokens real not null,
  updated_at timestamptz not null default now(),
  join_fails smallint not null default 0,
  join_fail_since timestamptz,
  join_locked_until timestamptz
);
alter table public.mp_limits enable row level security;
revoke all on public.mp_limits from anon, authenticated;

-- "host invited invited_user and they said no" -> no new invite until `until_at`.
-- Its own table: cancelling, leaving and deleting rooms cannot clear it.
create table public.mp_declines (
  host uuid not null references auth.users (id) on delete cascade,
  invited uuid not null references auth.users (id) on delete cascade,
  until_at timestamptz not null,
  primary key (host, invited)
);
alter table public.mp_declines enable row level security;
revoke all on public.mp_declines from anon, authenticated;

-- ── 內部小工具（不開放給 App）────────────────────────────────────────────

-- Token bucket. Capacity 30, one back per second. Always locks the caller's
-- row until the end of the transaction, so one person's calls queue up.
create function public.mp_take(p_me uuid, p_cost real)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_cap constant real := 30;
  c_rate constant real := 1;
  v_tokens real;
  v_at timestamptz;
  v_now real;
begin
  insert into public.mp_limits (user_id, tokens, updated_at)
  values (p_me, c_cap, now())
  on conflict (user_id) do nothing;
  select tokens, updated_at into v_tokens, v_at
  from public.mp_limits where user_id = p_me for update;
  v_now := least(c_cap, v_tokens + extract(epoch from (now() - v_at))::real * c_rate);
  if v_now < p_cost then
    return false;
  end if;
  update public.mp_limits
  set tokens = v_now - p_cost, updated_at = now()
  where user_id = p_me;
  return true;
end
$$;

-- Counts a wrong guess (5 inside 10 minutes -> locked for 10 minutes). A right
-- join does not call this and does not reset it.
create function public.mp_join_failed(p_me uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_fails smallint;
  v_since timestamptz;
begin
  select join_fails, join_fail_since into v_fails, v_since
  from public.mp_limits where user_id = p_me for update;
  if v_since is null or v_since < now() - interval '10 minutes' then
    v_fails := 1;
    v_since := now();
  else
    v_fails := least(v_fails + 1, 100);
  end if;
  update public.mp_limits
  set join_fails = v_fails,
      join_fail_since = v_since,
      join_locked_until = case
        when v_fails >= 5 then now() + interval '10 minutes'
        else join_locked_until
      end
  where user_id = p_me;
end
$$;

-- Ends rooms of [p_me] that have not moved for 2 hours.
create function public.mp_expire(p_me uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.mp_rooms
  set status = 'abandoned', end_reason = 'expired', updated_at = now()
  where (host = p_me or guest = p_me or invited = p_me)
    and status in ('waiting', 'playing')
    and updated_at < now() - interval '2 hours'
$$;

-- Keeps the rows a host leaves behind bounded: rooms nobody played in, and
-- all but the newest 20 finished rooms. (Never touches mp_limits/mp_declines.)
create function public.mp_gc(p_me uuid)
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
    and (guest is null or updated_at < now() - interval '10 minutes');
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

create function public.mp_live_count(p_me uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.mp_rooms
  where (host = p_me or guest = p_me) and status in ('waiting', 'playing')
$$;

create function public.mp_game_ok(p_game text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_game is not null and p_game ~ '^[a-z0-9_-]{1,32}$'
$$;

create function public.mp_room_json(r public.mp_rooms, p_me uuid)
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
    'status', r.status,
    'seq', r.seq,
    'turn', r.turn,
    'winner', r.winner,
    'endReason', r.end_reason,
    'side', case when r.host = p_me then 0 when r.guest = p_me then 1 end,
    'updatedAt', r.updated_at
  )
$$;

-- Pushes a small message on a private channel. Best effort: a Realtime that is
-- off or missing must never undo the write that called this.
create function public.mp_notify(p_topic text, p_event text, p_payload jsonb)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  begin
    perform realtime.send(p_payload, p_event, p_topic, true);
  exception when others then
    null;
  end;
end
$$;

-- A random 6-digit code (not predictable like random()).
create function public.mp_new_code()
returns text
language sql
volatile
set search_path = ''
as $$
  select (
    ('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint
      % 900000 + 100000
  )::text
$$;

-- Inserts a waiting room for [p_me] with a free code (retries on a clash; a
-- clash with a room that went stale ends that room first).
create function public.mp_make_room(p_me uuid, p_game text, p_invited uuid)
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
  loop
    v_try := v_try + 1;
    if v_try > 40 then
      raise exception 'mp_no_free_code';
    end if;
    v_code := public.mp_new_code();
    update public.mp_rooms
    set status = 'abandoned', end_reason = 'expired', updated_at = now()
    where code = v_code
      and status in ('waiting', 'playing')
      and updated_at < now() - interval '2 hours';
    begin
      insert into public.mp_rooms (game, code, host, invited)
      values (p_game, v_code, p_me, p_invited)
      returning * into v_room;
      return v_room;
    exception when unique_violation then
      -- someone else holds this code right now; draw another
    end;
  end loop;
end
$$;

-- ── 給 App／網頁呼叫 ─────────────────────────────────────────────────────

-- New room with a 6-digit code. {ok:true, room}
create function public.mp_create_room(p_game text)
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
  perform public.mp_expire(v_me);
  perform public.mp_gc(v_me);
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;
  v_room := public.mp_make_room(v_me, p_game, null);
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Join by 6-digit code. {ok:true, room}; {ok:false, reason:'bad_code'|'locked'|...}
-- A wrong code, a full room, someone else's invite room and a wrong game all
-- answer 'bad_code', so the answer does not tell which codes exist.
create function public.mp_join_room(p_code text, p_game text default null)
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
  if p_code is null or p_code !~ '^[1-9][0-9]{5}$' then
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

-- Invite a friend: a waiting room only that friend may join, and a push to
-- the friend's own channel. {ok:true, room}
create function public.mp_invite(p_friend uuid, p_game text)
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
  if (select count(*) from public.mp_rooms
      where invited = p_friend and status = 'waiting') >= 5 then
    return jsonb_build_object('ok', false, 'reason', 'invitee_busy');
  end if;
  if public.mp_live_count(v_me) >= 3 then
    return jsonb_build_object('ok', false, 'reason', 'too_many_rooms');
  end if;
  v_room := public.mp_make_room(v_me, p_game, p_friend);
  perform public.mp_notify('user:' || p_friend::text, 'invite',
    jsonb_build_object('room', v_room.id, 'game', v_room.game, 'from', v_me));
  return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
end
$$;

-- Invites waiting for me (still friends, not older than 2 hours), newest first.
create function public.mp_my_invites(p_game text default null)
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
      select r.id, r.game, r.host, r.created_at
      from public.mp_rooms r
      where r.invited = v_me
        and r.status = 'waiting'
        and r.guest is null
        and (p_game is null or r.game = p_game)
        and public.are_friends(r.host, v_me)
      order by r.created_at desc
      limit 5
    ) x
  ), '[]'::jsonb));
end
$$;

-- Take an invite. {ok:true, room}
create function public.mp_accept_invite(p_room uuid)
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
  if not found or (v_room.invited is distinct from v_me and v_room.guest is distinct from v_me) then
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
-- (0 host, 1 guest; leave null to just alternate). [p_end] 'win' = "this move
-- wins it for me", 'draw' = "this move draws it".
--   {ok:true, seq}                        accepted
--   {ok:true, seq, dup:true}              the same move was already accepted
--   {ok:false, reason, seq?}              not_found | not_playing | not_your_turn |
--                                         seq_mismatch | move_too_big | bad_move |
--                                         too_fast | too_long | expired | rate_limited
create function public.mp_submit_move(
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
  v_next smallint;
  v_entry jsonb;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.mp_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if p_move is null or jsonb_typeof(p_move) = 'null' or p_seq is null or p_seq < 1
     or (p_next is not null and p_next not in (0, 1))
     or (p_end is not null and p_end not in ('win', 'draw')) then
    return jsonb_build_object('ok', false, 'reason', 'bad_move');
  end if;
  if octet_length(p_move::text) > c_max_bytes then
    return jsonb_build_object('ok', false, 'reason', 'move_too_big');
  end if;
  select * into v_room from public.mp_rooms
  where id = p_room and (host = v_me or guest = v_me)
  for update;
  if not found then
    -- not there, or not yours: the same answer
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  v_side := case when v_room.host = v_me then 0 else 1 end;
  v_entry := jsonb_build_object('by', v_side, 'm', p_move);
  -- Already taken: the same move from the same side is a resend, anything
  -- else is a different move for a taken seq.
  if p_seq <= v_room.seq then
    if v_room.moves -> (p_seq - 1) = v_entry then
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
  if v_room.turn <> v_side then
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
  v_next := coalesce(p_next, 1 - v_side);
  update public.mp_rooms
  set moves = moves || jsonb_build_array(v_entry),
      seq = seq + 1,
      turn = v_next,
      last_move_at = now(),
      updated_at = now(),
      status = case when p_end is not null then 'done' else status end,
      winner = case when p_end = 'win' then v_side else null end,
      end_reason = case when p_end is not null then 'finish' else null end
  where id = v_room.id
  returning * into v_room;
  perform public.mp_notify('room:' || v_room.id::text, 'move',
    jsonb_build_object('seq', v_room.seq, 'status', v_room.status));
  return jsonb_build_object('ok', true, 'seq', v_room.seq);
end
$$;

-- Leave. Waiting room: the host cancels it, the invited friend declines it
-- (and the host cannot invite them again for 5 minutes). Playing room:
-- p_how 'resign' (default) loses it; 'abort' ends it with no winner, but only
-- when it is the other side's turn and they have been silent for 60 seconds.
-- Leaving something already over just answers with the room.
create function public.mp_leave(p_room uuid, p_how text default 'resign')
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
  select * into v_room from public.mp_rooms
  where id = p_room and (host = v_me or guest = v_me or invited = v_me)
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_room.status in ('done', 'abandoned') then
    return jsonb_build_object('ok', true, 'room', public.mp_room_json(v_room, v_me));
  end if;
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

-- Housekeeping for a cron job (service_role only; nothing calls it yet).
create function public.mp_cleanup()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_expired integer;
  v_deleted integer;
begin
  update public.mp_rooms
  set status = 'abandoned', end_reason = 'expired', updated_at = now()
  where status in ('waiting', 'playing') and updated_at < now() - interval '2 hours';
  get diagnostics v_expired = row_count;
  delete from public.mp_rooms
  where status in ('done', 'abandoned') and updated_at < now() - interval '14 days';
  get diagnostics v_deleted = row_count;
  delete from public.mp_declines where until_at < now() - interval '1 day';
  return jsonb_build_object('expired', v_expired, 'deleted', v_deleted);
end
$$;

-- ── Realtime：只有房間裡的兩個人進得了 room:<id>，只有自己進得了 user:<自己的 id> ──
-- Supabase's realtime.messages already has RLS on (we do not own it, so no
-- `alter table` here). Topic names are matched as text, no uuid cast that
-- could throw.
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
            and (r.host = (select auth.uid()) or r.guest = (select auth.uid()))
        )
      )
      or realtime.topic() = 'user:' || (select auth.uid())::text
    )
  );

-- Players may also send on their room (presence "I'm here", and later the
-- racing games' positions). Nobody sends on a user: channel; only the RPCs do
-- (through realtime.send, as the function owner).
create policy "mp: players send on their room"
  on realtime.messages for insert to authenticated
  with check (
    realtime.messages.extension in ('broadcast', 'presence')
    and realtime.topic() like 'room:%'
    and exists (
      select 1 from public.mp_rooms r
      where r.id::text = substr(realtime.topic(), 6)
        and (r.host = (select auth.uid()) or r.guest = (select auth.uid()))
    )
  );

-- ── 執行權 ──────────────────────────────────────────────────────────────
-- Supabase 預設把 public 的新函式開給 anon、authenticated；全部收回再逐支開。

revoke execute on function
  public.mp_take(uuid, real),
  public.mp_join_failed(uuid),
  public.mp_expire(uuid),
  public.mp_gc(uuid),
  public.mp_live_count(uuid),
  public.mp_game_ok(text),
  public.mp_room_json(public.mp_rooms, uuid),
  public.mp_notify(text, text, jsonb),
  public.mp_new_code(),
  public.mp_make_room(uuid, text, uuid),
  public.mp_create_room(text),
  public.mp_join_room(text, text),
  public.mp_invite(uuid, text),
  public.mp_my_invites(text),
  public.mp_accept_invite(uuid),
  public.mp_submit_move(uuid, integer, jsonb, smallint, text),
  public.mp_leave(uuid, text),
  public.mp_cleanup()
from public, anon, authenticated;

grant execute on function
  public.mp_create_room(text),
  public.mp_join_room(text, text),
  public.mp_invite(uuid, text),
  public.mp_my_invites(text),
  public.mp_accept_invite(uuid),
  public.mp_submit_move(uuid, integer, jsonb, smallint, text),
  public.mp_leave(uuid, text)
to authenticated;
grant execute on function public.mp_cleanup() to service_role;

commit;
