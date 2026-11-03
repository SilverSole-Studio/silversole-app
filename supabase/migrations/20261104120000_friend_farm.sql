-- supabase/migrations/20261104120000_friend_farm.sql
--
-- *** 還沒套用到任何 Supabase 專案；套用前要先問 user。 ***
-- 要先套好 20261019120000_friends.sql、20261026120000_friends_rpc_abuse.sql
-- 與 20261031120000_game_saves.sql（這支用到 profiles／friendships／blocks、
-- are_friends() 與 game_saves）。
--
-- Friend farm (user 2026-11-03: 「去好友農場看＋比等級」):
--   - friend_farm(friend)   read-only view of a friend's farm: plots, placed
--                           decor, xp, level, title. Nothing else of the save.
--   - friends_board()       friends (and me) ranked by farm level.
--   - friend_water(...)     help a friend water one dry plot. Each friend once
--                           a day, at most 5 friends a day. Recorded, not applied.
--   - friend_helps_claim()  the helped person's page (and the helper's) picks up
--                           the records, applies them to their OWN save, and the
--                           records are marked claimed.
--
-- The farm lives inside game_saves.data (a text blob made by the phone, see
-- cloud_save.js: {"v":1,"keys":{"silversole.farm":"<json text>", ...}}), so
-- these RPCs read that blob. THE BLOB IS WRITTEN BY THE OWNER: a friend can put
-- anything in it. Every field is type-checked and clamped before it is returned,
-- any parse failure becomes 'no_farm', and only the whitelisted fields leave the
-- server (never inventory, coins, orders, other save keys).
--
-- Written against the RPC abuse checklist (2026-10-26 audit): callers can hit
-- the API directly, in parallel, from many accounts.
--   - security definer, search_path = '', execute only for authenticated; the
--     helper functions are not callable by anyone.
--   - Both people must be friends and not blocked either way (are_friends,
--     taken FOR SHARE so an unfriend/block waits for the call).
--   - Daily counts are counted from the ledger table friend_helps, which no
--     other action deletes or rewrites (claiming only stamps a claimed_at
--     column; rows are removed only by friend_helps_cleanup(), service_role,
--     for days older than 14). So "claim, then help again" does not reset them,
--     and unfriending does not either (the table references users, not friendships).
--   - friend_water locks both people's rows in friend_help_limits (in uuid
--     order, so two people helping each other do not deadlock) before it counts
--     anything: of N parallel calls the counts are exact.
--   - Failures return {ok:false, reason} and do not raise, so the token bucket
--     that punishes spamming is kept.
--   - A person's own xp from this feature is fixed by the server per record
--     (helper +3, helped +5); the page cannot ask for more.
--
-- Known limits (also in the PR text):
--   - xp/level in the farm view and the board are read from the owner's own
--     save, so they can be edited by the owner. Same limit as game_saves; no
--     coins or real prizes hang on the board.
--   - The helped person's xp and the helper's xp are applied by the pages to
--     their own saves (the server has no farm of its own). If a page dies
--     between claim and save, that record's bonus is lost; the plot just stays dry.
--   - Weekly insole minutes are NOT part of the board: the server only has the
--     diamond ledger (paying subscribers, days of 15+ minutes), which is not a
--     weekly total for everyone. Add a minutes table before showing it.
--   - friends_board() parses each friend's save (<= 256 KB); it is capped at 60
--     friends and costs 5 tokens of the bucket.

begin;

-- ── 表 ──────────────────────────────────────────────────────────────────

-- Per person: the token bucket, and the row that is locked while counting.
create table public.friend_help_limits (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tokens real not null,
  updated_at timestamptz not null default now()
);
alter table public.friend_help_limits enable row level security;
revoke all on public.friend_help_limits from anon, authenticated;

-- One row = one "helper watered one plot of helped's farm" on one Taipei day.
-- At most one row per (helper, helped, day): each friend once a day.
create table public.friend_helps (
  id uuid primary key default gen_random_uuid(),
  helper uuid not null references auth.users (id) on delete cascade,
  helped uuid not null references auth.users (id) on delete cascade,
  day date not null,
  plot smallint not null check (plot between 0 and 11),
  helper_xp smallint not null check (helper_xp between 0 and 20),
  helped_xp smallint not null check (helped_xp between 0 and 20),
  created_at timestamptz not null default now(),
  helped_claimed_at timestamptz,
  helper_claimed_at timestamptz,
  check (helper <> helped),
  unique (helper, helped, day)
);
create index friend_helps_helper_day_idx on public.friend_helps (helper, day);
create index friend_helps_helped_day_idx on public.friend_helps (helped, day);
create index friend_helps_helped_open_idx on public.friend_helps (helped) where helped_claimed_at is null;
create index friend_helps_helper_open_idx on public.friend_helps (helper) where helper_claimed_at is null;
-- A plot with a record waiting for its owner cannot be watered again.
create unique index friend_helps_open_plot_idx on public.friend_helps (helped, plot)
  where helped_claimed_at is null;
alter table public.friend_helps enable row level security;
revoke all on public.friend_helps from anon, authenticated;

-- ── 內部小工具（不開放給 App）────────────────────────────────────────────

-- Token bucket: capacity 30, one back per 2 s. Never raises. Locks the caller's row.
create function public.friend_farm_take(p_me uuid, p_cost real)
returns boolean
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
  insert into public.friend_help_limits (user_id, tokens, updated_at)
  values (p_me, c_cap, now())
  on conflict (user_id) do nothing;
  update public.friend_help_limits
  set tokens = least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) - p_cost,
      updated_at = now()
  where user_id = p_me
    and least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) >= p_cost
  returning tokens into v_left;
  return v_left is not null;
end
$$;

-- Level thresholds and titles: same as games/farmyard/rules.js (LEVELS, TITLES).
-- If those change, change this and the test together.
create function public.friend_farm_level(p_xp integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when p_xp >= 14000 then 10 when p_xp >= 10000 then 9 when p_xp >= 7000 then 8
    when p_xp >= 4000 then 7 when p_xp >= 2500 then 6 when p_xp >= 1500 then 5
    when p_xp >= 800 then 4 when p_xp >= 400 then 3 when p_xp >= 150 then 2
    else 1 end
$$;

create function public.friend_farm_title(p_level integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_level >= 10 then '小鎮名人' when p_level >= 9 then '農莊主人'
    when p_level >= 7 then '老農' when p_level >= 5 then '勤勞農夫'
    when p_level >= 3 then '小農夫' else '菜鳥農夫' end
$$;

-- The farm object (parsed) inside a save blob, or null when there is none / it is garbage.
create function public.friend_farm_parse(p_data text)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_root jsonb;
  v_text text;
  v_farm jsonb;
begin
  if p_data is null then
    return null;
  end if;
  v_root := p_data::jsonb;
  if jsonb_typeof(v_root) is distinct from 'object'
     or jsonb_typeof(v_root -> 'keys') is distinct from 'object'
     or jsonb_typeof(v_root -> 'keys' -> 'silversole.farm') is distinct from 'string' then
    return null;
  end if;
  v_text := v_root -> 'keys' ->> 'silversole.farm';
  v_farm := v_text::jsonb;
  if jsonb_typeof(v_farm) is distinct from 'object' then
    return null;
  end if;
  return v_farm;
exception when others then
  return null;
end
$$;

-- xp of a parsed farm, clamped to 0 .. 100,000,000.
create function public.friend_farm_xp(p_farm jsonb)
returns integer
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_farm is null or jsonb_typeof(p_farm -> 'xp') is distinct from 'number' then
    return 0;
  end if;
  return least(greatest(floor((p_farm ->> 'xp')::numeric), 0), 100000000)::integer;
exception when others then
  return 0;
end
$$;

-- Only the fields the farm screen draws, each one checked.
--   plots: [{i, owned, crop, stage, endsAt, dry, harvests}]  (at most 12)
--   decor: [{uid, decorId, x, y}]                             (placed ones, at most 200)
create function public.friend_farm_view(p_farm jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_plots jsonb := '[]'::jsonb;
  v_decor jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_farm -> 'plots') = 'array' then
    select coalesce(jsonb_agg(jsonb_build_object(
        'i', t.ord - 1,
        'owned', coalesce(case when jsonb_typeof(t.p -> 'owned') = 'boolean' then (t.p ->> 'owned')::boolean end, false),
        'crop', case when jsonb_typeof(t.p -> 'crop') = 'string' and (t.p ->> 'crop') ~ '^[A-Za-z][A-Za-z0-9_]{0,23}$'
                     then t.p ->> 'crop' end,
        'stage', case when jsonb_typeof(t.p -> 'stage') = 'number'
                      then least(greatest(floor((t.p ->> 'stage')::numeric), 0), 4)::integer else 0 end,
        'endsAt', case when jsonb_typeof(t.p -> 'stageEndsAt') = 'number'
                        and (t.p ->> 'stageEndsAt')::numeric between 0 and 4000000000000
                       then floor((t.p ->> 'stageEndsAt')::numeric)::bigint end,
        'dry', coalesce(case when jsonb_typeof(t.p -> 'dry') = 'boolean' then (t.p ->> 'dry')::boolean end, false),
        'harvests', case when jsonb_typeof(t.p -> 'harvests') = 'number'
                         then least(greatest(floor((t.p ->> 'harvests')::numeric), 0), 1000)::integer else 0 end
      ) order by t.ord), '[]'::jsonb)
    into v_plots
    from jsonb_array_elements(p_farm -> 'plots') with ordinality as t(p, ord)
    where t.ord <= 12 and jsonb_typeof(t.p) = 'object';
  end if;
  if jsonb_typeof(p_farm -> 'decor') = 'array' then
    select coalesce(jsonb_agg(jsonb_build_object(
        'uid', case when jsonb_typeof(t.d -> 'uid') = 'number'
                    then least(greatest(floor((t.d ->> 'uid')::numeric), 0), 1000000000)::integer end,
        'decorId', t.d ->> 'decorId',
        'x', least(greatest(floor((t.d ->> 'x')::numeric), 0), 100)::integer,
        'y', least(greatest(floor((t.d ->> 'y')::numeric), 0), 100)::integer
      ) order by t.ord), '[]'::jsonb)
    into v_decor
    from jsonb_array_elements(p_farm -> 'decor') with ordinality as t(d, ord)
    where t.ord <= 200
      and jsonb_typeof(t.d) = 'object'
      and jsonb_typeof(t.d -> 'decorId') = 'string'
      and (t.d ->> 'decorId') ~ '^[A-Za-z0-9_:.-]{1,40}$'
      and jsonb_typeof(t.d -> 'x') = 'number'
      and jsonb_typeof(t.d -> 'y') = 'number';
  end if;
  return jsonb_build_object('plots', v_plots, 'decor', v_decor);
exception when others then
  return jsonb_build_object('plots', '[]'::jsonb, 'decor', '[]'::jsonb);
end
$$;

-- ── App 呼叫的 RPC ──────────────────────────────────────────────────────

-- {ok:true, friend:{user_id, nickname, avatar_preset}, xp, level, title, plots, decor,
--  savedAt, help:{doneToday, leftToday, pendingPlots:[...]}}
-- reasons: signed_out, rate_limited, not_friend, no_farm
create function public.friend_farm(p_friend uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_daily_max constant integer := 5;
  v_me uuid := auth.uid();
  v_save public.game_saves;
  v_farm jsonb;
  v_xp integer;
  v_level integer;
  v_view jsonb;
  v_today date := public.friends_today();
  v_done boolean;
  v_used integer;
  v_pending jsonb;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.friend_farm_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  if p_friend is null or not public.are_friends(v_me, p_friend) then
    return jsonb_build_object('ok', false, 'reason', 'not_friend');
  end if;
  select * into v_save from public.game_saves where user_id = p_friend;
  v_farm := public.friend_farm_parse(v_save.data);
  if v_farm is null then
    return jsonb_build_object('ok', false, 'reason', 'no_farm');
  end if;
  v_xp := public.friend_farm_xp(v_farm);
  v_level := public.friend_farm_level(v_xp);
  v_view := public.friend_farm_view(v_farm);
  select exists (select 1 from public.friend_helps
                 where helper = v_me and helped = p_friend and day = v_today)
    into v_done;
  select count(*) into v_used from public.friend_helps where helper = v_me and day = v_today;
  select coalesce(jsonb_agg(plot order by plot), '[]'::jsonb) into v_pending
  from public.friend_helps where helped = p_friend and helped_claimed_at is null;
  return jsonb_build_object(
    'ok', true,
    'friend', public.friends_profile_json(p_friend, false),
    'xp', v_xp,
    'level', v_level,
    'title', public.friend_farm_title(v_level),
    'plots', v_view -> 'plots',
    'decor', v_view -> 'decor',
    'savedAt', v_save.updated_at,
    'help', jsonb_build_object(
      'doneToday', v_done,
      'leftToday', greatest(c_daily_max - v_used, 0),
      'pendingPlots', v_pending
    )
  );
end
$$;

-- {ok:true, me:<user_id>, rows:[{user_id, nickname, avatar_preset, xp, level, title, me}]}
-- sorted by xp, highest first. Friends who have no farm yet show up as level 1.
-- reasons: signed_out, rate_limited
create function public.friends_board()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_max_friends constant integer := 60;
  v_me uuid := auth.uid();
  v_rows jsonb;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.friend_farm_take(v_me, 5) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select coalesce(jsonb_agg(
      jsonb_build_object(
        'user_id', y.uid,
        'nickname', y.nickname,
        'avatar_preset', y.avatar_preset,
        'xp', y.xp,
        'level', public.friend_farm_level(y.xp),
        'title', public.friend_farm_title(public.friend_farm_level(y.xp)),
        'me', y.uid = v_me
      ) order by y.xp desc, y.nickname, y.uid), '[]'::jsonb)
  into v_rows
  from (
    select x.uid,
           coalesce(p.nickname, '銀足朋友') as nickname,
           p.avatar_preset,
           public.friend_farm_xp(public.friend_farm_parse(g.data)) as xp
    from (
      select v_me as uid
      union all
      select z.uid from (
        select case when f.user_low = v_me then f.user_high else f.user_low end as uid
        from public.friendships f
        where (f.user_low = v_me or f.user_high = v_me)
          and not public.friends_blocked_either(f.user_low, f.user_high)
        order by f.last_interaction_at desc nulls last, f.created_at desc
        limit c_max_friends
      ) z
    ) x
    join public.profiles p on p.user_id = x.uid
    left join public.game_saves g on g.user_id = x.uid
  ) y;
  return jsonb_build_object('ok', true, 'me', v_me, 'rows', v_rows);
end
$$;

-- Help [p_friend] water plot [p_plot] (0..11) today.
-- {ok:true, helperXp, helpedXp, leftToday}
-- reasons: signed_out, bad_plot, not_friend, rate_limited, no_farm, nothing_to_water,
--          already_today (this friend, today), daily_limit (5 friends today),
--          friend_full (this friend got 5 helps today or has 10 waiting), plot_waiting
create function public.friend_water(p_friend uuid, p_plot integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_daily_max constant integer := 5;       -- friends a person may help per day
  c_received_max constant integer := 5;    -- helps one person may receive per day
  c_waiting_max constant integer := 10;    -- records waiting for one person
  c_helper_xp constant integer := 3;       -- about a third of one bok choy harvest (10 xp)
  c_helped_xp constant integer := 5;       -- half of one bok choy harvest
  v_me uuid := auth.uid();
  v_today date := public.friends_today();
  v_save public.game_saves;
  v_farm jsonb;
  v_plot jsonb;
  v_used integer;
  v_count integer;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if p_friend is null or p_plot is null or p_plot < 0 or p_plot > 11 then
    return jsonb_build_object('ok', false, 'reason', 'bad_plot');
  end if;
  -- FOR SHARE on the friendship: an unfriend or a block waits for this call.
  if not public.are_friends(v_me, p_friend, true) then
    return jsonb_build_object('ok', false, 'reason', 'not_friend');
  end if;
  -- Lock both people's rows in uuid order, then count. Parallel calls queue here.
  insert into public.friend_help_limits (user_id, tokens, updated_at)
  values (v_me, 30, now()), (p_friend, 30, now())
  on conflict (user_id) do nothing;
  perform 1 from public.friend_help_limits
  where user_id in (v_me, p_friend)
  order by user_id
  for update;
  if not public.friend_farm_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  if exists (select 1 from public.friend_helps
             where helper = v_me and helped = p_friend and day = v_today) then
    return jsonb_build_object('ok', false, 'reason', 'already_today');
  end if;
  select count(*) into v_used from public.friend_helps where helper = v_me and day = v_today;
  if v_used >= c_daily_max then
    return jsonb_build_object('ok', false, 'reason', 'daily_limit');
  end if;
  select count(*) into v_count from public.friend_helps where helped = p_friend and day = v_today;
  if v_count >= c_received_max then
    return jsonb_build_object('ok', false, 'reason', 'friend_full');
  end if;
  select count(*) into v_count
  from public.friend_helps where helped = p_friend and helped_claimed_at is null;
  if v_count >= c_waiting_max then
    return jsonb_build_object('ok', false, 'reason', 'friend_full');
  end if;
  if exists (select 1 from public.friend_helps
             where helped = p_friend and plot = p_plot and helped_claimed_at is null) then
    return jsonb_build_object('ok', false, 'reason', 'plot_waiting');
  end if;

  select * into v_save from public.game_saves where user_id = p_friend;
  v_farm := public.friend_farm_parse(v_save.data);
  if v_farm is null then
    return jsonb_build_object('ok', false, 'reason', 'no_farm');
  end if;
  select e into v_plot
  from jsonb_array_elements(public.friend_farm_view(v_farm) -> 'plots') e
  where (e ->> 'i')::integer = p_plot;
  if v_plot is null
     or not (v_plot ->> 'owned')::boolean
     or v_plot ->> 'crop' is null
     or (v_plot ->> 'stage')::integer >= 4
     or not (v_plot ->> 'dry')::boolean then
    return jsonb_build_object('ok', false, 'reason', 'nothing_to_water');
  end if;

  insert into public.friend_helps (helper, helped, day, plot, helper_xp, helped_xp)
  values (v_me, p_friend, v_today, p_plot, c_helper_xp, c_helped_xp);
  return jsonb_build_object(
    'ok', true,
    'helperXp', c_helper_xp,
    'helpedXp', c_helped_xp,
    'leftToday', c_daily_max - v_used - 1
  );
end
$$;

-- The caller's page takes what is waiting and applies it to its own save.
-- {ok:true, received:[{plot, xp, from}], givenXp}
--   received: friends watered these plots of mine (+xp each);
--   givenXp:  xp for the help I gave since the last claim.
-- Each record is returned once. reasons: signed_out, rate_limited
create function public.friend_helps_claim()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_received jsonb;
  v_given integer;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  -- friend_farm_take locks my limits row: two phones claiming at once are served one by one.
  if not public.friend_farm_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  with got as (
    update public.friend_helps h
    set helped_claimed_at = now()
    where h.helped = v_me and h.helped_claimed_at is null
    returning h.plot, h.helped_xp, h.helper, h.created_at
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'plot', got.plot,
      'xp', got.helped_xp,
      'from', coalesce(p.nickname, '銀足朋友')
    ) order by got.created_at), '[]'::jsonb)
  into v_received
  from got left join public.profiles p on p.user_id = got.helper;
  with got as (
    update public.friend_helps h
    set helper_claimed_at = now()
    where h.helper = v_me and h.helper_claimed_at is null
    returning h.helper_xp
  )
  select coalesce(sum(got.helper_xp), 0)::integer into v_given from got;
  return jsonb_build_object('ok', true, 'received', v_received, 'givenXp', v_given);
end
$$;

-- Old records go away after 14 days (counts only look at today). Nothing schedules
-- it yet; add pg_cron when this goes live. service_role only.
create function public.friend_helps_cleanup()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  delete from public.friend_helps where day < public.friends_today() - 14;
  get diagnostics v_n = row_count;
  return v_n;
end
$$;

-- ── 權限 ────────────────────────────────────────────────────────────────

revoke all on function
  public.friend_farm_take(uuid, real),
  public.friend_farm_level(integer),
  public.friend_farm_title(integer),
  public.friend_farm_parse(text),
  public.friend_farm_xp(jsonb),
  public.friend_farm_view(jsonb),
  public.friend_helps_cleanup()
  from public, anon, authenticated;
revoke all on function
  public.friend_farm(uuid),
  public.friends_board(),
  public.friend_water(uuid, integer),
  public.friend_helps_claim()
  from public, anon;
grant execute on function
  public.friend_farm(uuid),
  public.friends_board(),
  public.friend_water(uuid, integer),
  public.friend_helps_claim()
  to authenticated;
grant execute on function public.friend_helps_cleanup() to service_role;

commit;
