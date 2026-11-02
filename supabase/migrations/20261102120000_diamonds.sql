-- supabase/migrations/20261102120000_diamonds.sql
--
-- *** 還沒套用到正式庫；套用前要先問 user。 ***
--
-- Diamonds (user 2026-11-02): a subscriber earns diamonds only by exercising
-- with the insole, and swaps them for real goods in the game's 兌換站.
-- Design + numbers: 動域科技/02_產品/鞋墊_SilverSole/_鑽石設計_2026-11-02.md
--
--   - 10 diamonds a day when the day's insole exercise reaches 15 minutes;
--     at most once a day, at most 300 a month (Taipei calendar month).
--   - 1 diamond is about NT$0.1; a prize costs (cost in NT$) x 10 diamonds.
--   - Only an account with a live subscription earns.
--   - Cancel the subscription and the balance is kept for 3 months, then it
--     is zeroed (an 'expire' row in the ledger).
--   - Diamonds are never bought with money; they only buy goods.
--   - Coins (the games' own currency) are a different thing and untouched.
--
-- Written against the RPC abuse checklist (2026-10-26 audit): callers can hit
-- the API directly, in parallel, from many accounts.
--   - No table grants on the ledger, buckets: every read and write goes
--     through the RPCs below. `subscriptions` is readable by its owner only
--     and written by nobody but service_role / SQL (no billing yet: a row is
--     opened by hand, see the PR text).
--   - The ledger only grows: an UPDATE is refused by a trigger; there is no
--     client DELETE (rows go only when the account itself is deleted).
--   - One earn row per user per day (unique index), one expire row per lapse
--     (unique index), so a double call can never pay twice, even without
--     the lock.
--   - Every RPC takes a per-user advisory lock first: two phones calling at
--     the same instant are served one after the other.
--   - Per-user token bucket (own table, so friends / saves calls do not drain
--     it).
--
-- Opening / closing a subscription by hand (no billing yet). Run as an admin
-- in the Supabase SQL editor; full examples in docs/diamonds-subscription-admin.md.
--   insert into public.subscriptions (user_id, active_until)
--   select id, date '2026-12-31' from auth.users where email = 'someone@example.com'
--   on conflict (user_id) do update set active_until = excluded.active_until,
--     updated_at = now();
-- Cancel = set active_until to yesterday (Taipei) or leave it to run out; the
-- diamonds stay for 3 months after it, then are zeroed.
--
-- Known limit: the minutes are reported by the phone (the server has no raw
-- insole data), so a player who fakes the report can take the month's cap
-- (300 diamonds, about NT$30). They have paid NT$149; the loss is bounded.
-- Move the judgement to the server (upload the insole record) before raising
-- the cap.

begin;

create table public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  -- Last day (Taipei date) the subscription covers, inclusive.
  active_until date not null,
  source text not null default 'manual'
    check (source in ('manual', 'google_play', 'app_store')),
  updated_at timestamptz not null default now()
);
alter table public.subscriptions enable row level security;
revoke all on public.subscriptions from anon, authenticated;
grant select on public.subscriptions to authenticated;
create policy subscriptions_select_own on public.subscriptions
  for select to authenticated
  using (user_id = (select auth.uid()));

create table public.diamond_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- Taipei calendar day the row belongs to.
  day date not null,
  delta integer not null,
  reason text not null check (reason in ('earn_exercise', 'redeem', 'expire')),
  ref text,
  created_at timestamptz not null default now(),
  check (
    (reason = 'earn_exercise' and delta > 0)
    or (reason in ('redeem', 'expire') and delta < 0)
  )
);
alter table public.diamond_ledger enable row level security;
revoke all on public.diamond_ledger from anon, authenticated;

create index diamond_ledger_user_day_idx on public.diamond_ledger (user_id, day);
-- At most one exercise payout per user per day.
create unique index diamond_ledger_one_earn_per_day
  on public.diamond_ledger (user_id, day) where reason = 'earn_exercise';
-- At most one expiry per lapse (ref = the active_until that lapsed).
create unique index diamond_ledger_one_expire_per_lapse
  on public.diamond_ledger (user_id, ref) where reason = 'expire';

create function public.diamond_ledger_no_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'diamond_ledger is append-only';
end
$$;
create trigger diamond_ledger_no_update
  before update on public.diamond_ledger
  for each row execute function public.diamond_ledger_no_update();

create table public.diamond_buckets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tokens real not null,
  updated_at timestamptz not null default now()
);
alter table public.diamond_buckets enable row level security;
revoke all on public.diamond_buckets from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Internal helpers (not callable by clients)
-- ---------------------------------------------------------------------------

-- Today in Taipei. One place, so tests can replace it.
create function public.diamond_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Taipei')::date
$$;

-- Capacity 10, one back every 10 s. The app asks for the balance when the
-- screen opens and earns at most once a day.
create function public.diamond_take(p_me uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_cap constant real := 10;
  c_rate constant real := 0.1;
  v_left real;
begin
  insert into public.diamond_buckets (user_id, tokens, updated_at)
  values (p_me, c_cap, now())
  on conflict (user_id) do nothing;
  update public.diamond_buckets
  set tokens = least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) - 1,
      updated_at = now()
  where user_id = p_me
    and least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) >= 1
  returning tokens into v_left;
  return v_left is not null;
end
$$;

-- Zeroes the balance when the subscription lapsed more than 3 months ago.
-- Call it holding the user's advisory lock. Returns the balance afterwards.
create function public.diamond_settle(p_me uuid, p_today date)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_until date;
  v_balance integer;
begin
  select coalesce(sum(delta), 0)::integer into v_balance
  from public.diamond_ledger where user_id = p_me;
  select active_until into v_until from public.subscriptions where user_id = p_me;
  if v_balance > 0 and v_until is not null
     and p_today > (v_until + interval '3 months')::date then
    insert into public.diamond_ledger (user_id, day, delta, reason, ref)
    values (p_me, p_today, -v_balance, 'expire', v_until::text)
    on conflict do nothing;
    select coalesce(sum(delta), 0)::integer into v_balance
    from public.diamond_ledger where user_id = p_me;
  end if;
  return v_balance;
end
$$;

-- A lapse is only noticed when somebody asks. If the subscription already
-- lapsed more than 3 months ago and the admin now moves active_until forward
-- (the person subscribed again), zero the old balance first, so the new
-- period does not revive diamonds that should have expired.
create function public.subscriptions_settle_before_renew()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.active_until is distinct from old.active_until then
    perform pg_advisory_xact_lock(hashtextextended('diamonds-user:' || old.user_id::text, 0));
    perform public.diamond_settle(old.user_id, public.diamond_today());
  end if;
  return new;
end
$$;
create trigger subscriptions_settle_before_renew
  before update on public.subscriptions
  for each row execute function public.subscriptions_settle_before_renew();

-- {balance, month, cap, subscribed, activeUntil} for [p_me] as of [p_today].
-- Call it holding the lock, after diamond_settle.
create function public.diamond_snapshot(p_me uuid, p_today date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_cap constant integer := 300;
  v_start date := make_date(extract(year from p_today)::int, extract(month from p_today)::int, 1);
  v_until date;
  v_balance integer;
  v_month integer;
begin
  select coalesce(sum(delta), 0)::integer into v_balance
  from public.diamond_ledger where user_id = p_me;
  select coalesce(sum(delta), 0)::integer into v_month
  from public.diamond_ledger
  where user_id = p_me and reason = 'earn_exercise'
    and day >= v_start and day < (v_start + interval '1 month')::date;
  select active_until into v_until from public.subscriptions where user_id = p_me;
  return jsonb_build_object(
    'balance', v_balance,
    'month', v_month,
    'cap', c_cap,
    'subscribed', coalesce(v_until >= p_today, false),
    'activeUntil', v_until
  );
end
$$;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- {ok:true, balance, month, cap, subscribed, activeUntil}
create function public.diamond_balance()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_today date := public.diamond_today();
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.diamond_take(v_me) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('diamonds-user:' || v_me::text, 0));
  perform public.diamond_settle(v_me, v_today);
  return jsonb_build_object('ok', true) || public.diamond_snapshot(v_me, v_today);
end
$$;

-- Today's insole exercise reached [p_minutes]. Pays 10 diamonds when all of:
--   - signed in, and the subscription covers today (Taipei);
--   - p_minutes >= 15;
--   - nothing was paid today yet;
--   - this month's payouts are below 300.
-- Answers {ok:true, earned:10, balance, month, cap, ...} or
-- {ok:false, reason, balance, month, cap, ...}, reason one of: signed_out,
-- rate_limited, bad_minutes, not_subscribed, too_short, already_today,
-- month_cap.
create function public.diamond_earn_exercise(p_minutes integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_min_minutes constant integer := 15;
  c_per_day constant integer := 10;
  c_cap constant integer := 300;
  v_me uuid := auth.uid();
  v_today date := public.diamond_today();
  v_snap jsonb;
  v_earned integer;
  v_reason text;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if p_minutes is null or p_minutes < 0 or p_minutes > 1440 then
    return jsonb_build_object('ok', false, 'reason', 'bad_minutes');
  end if;
  if not public.diamond_take(v_me) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('diamonds-user:' || v_me::text, 0));
  perform public.diamond_settle(v_me, v_today);
  v_snap := public.diamond_snapshot(v_me, v_today);

  if not (v_snap ->> 'subscribed')::boolean then
    v_reason := 'not_subscribed';
  elsif p_minutes < c_min_minutes then
    v_reason := 'too_short';
  elsif exists (
    select 1 from public.diamond_ledger
    where user_id = v_me and day = v_today and reason = 'earn_exercise'
  ) then
    v_reason := 'already_today';
  elsif (v_snap ->> 'month')::integer >= c_cap then
    v_reason := 'month_cap';
  end if;
  if v_reason is not null then
    return jsonb_build_object('ok', false, 'reason', v_reason) || v_snap;
  end if;

  v_earned := least(c_per_day, c_cap - (v_snap ->> 'month')::integer);
  begin
    insert into public.diamond_ledger (user_id, day, delta, reason, ref)
    values (v_me, v_today, v_earned, 'earn_exercise', 'min:' || p_minutes);
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'reason', 'already_today')
      || public.diamond_snapshot(v_me, v_today);
  end;
  return jsonb_build_object('ok', true, 'earned', v_earned)
    || public.diamond_snapshot(v_me, v_today);
end
$$;

-- Swapping diamonds for goods is not open yet: the prize list and the
-- delivery details (personal data) still have to be designed. The signature
-- is here so the app and the games can be written against it. When it opens,
-- it must take the lock, check the balance and the subscription, write a
-- 'redeem' row and an order in one transaction.
create function public.diamond_redeem(p_item text, p_cost integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  return jsonb_build_object('ok', false, 'reason', 'not_open');
end
$$;

revoke all on function public.diamond_ledger_no_update() from public, anon, authenticated;
revoke all on function public.subscriptions_settle_before_renew() from public, anon, authenticated;
revoke all on function public.diamond_today() from public, anon, authenticated;
revoke all on function public.diamond_take(uuid) from public, anon, authenticated;
revoke all on function public.diamond_settle(uuid, date) from public, anon, authenticated;
revoke all on function public.diamond_snapshot(uuid, date) from public, anon, authenticated;
revoke all on function public.diamond_balance() from public, anon;
revoke all on function public.diamond_earn_exercise(integer) from public, anon;
revoke all on function public.diamond_redeem(text, integer) from public, anon;
grant execute on function public.diamond_balance() to authenticated;
grant execute on function public.diamond_earn_exercise(integer) to authenticated;
grant execute on function public.diamond_redeem(text, integer) to authenticated;

commit;
