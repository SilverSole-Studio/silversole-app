-- supabase/migrations/20261031120000_game_saves.sql
--
-- Game cloud save: the H5 games (粗哥小鎮 and every game it opens) keep their
-- progress in the WebView's localStorage. This stores one JSON blob per
-- account so a new phone, a reinstall or cleared app data gets it back.
-- Interface: 動域科技/02_產品/鞋墊_SilverSole/_遊戲雲端存檔_介面_2026-10-31.md
--
-- Written against the RPC abuse checklist (2026-10-26 audit): callers can hit
-- the API directly, in parallel, from many accounts.
--   - No table grants: reads and writes only through the two RPCs below.
--   - Size cap 256 KB, and the blob must parse as JSON.
--   - Per-user token bucket (own table, so friends calls do not drain it).
--   - Writes compare-and-swap on rev under a row lock: of two phones saving at
--     once exactly one wins; the other gets 'conflict' and reloads.
--
-- Known limit: the blob is written by the phone, so a player can edit their
-- own coins. Coins buy nothing real and there is no leaderboard; move coins to
-- the server before adding either.

begin;

create table public.game_saves (
  user_id uuid primary key references auth.users (id) on delete cascade,
  rev integer not null default 0,
  data text,
  updated_at timestamptz not null default now()
);
alter table public.game_saves enable row level security;
revoke all on public.game_saves from anon, authenticated;

create table public.game_save_buckets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tokens real not null,
  updated_at timestamptz not null default now()
);
alter table public.game_save_buckets enable row level security;
revoke all on public.game_save_buckets from anon, authenticated;

-- Capacity 10, one back every 10 s. The game saves at most once a minute and
-- loads once per plaza open, so a real player never runs dry.
create function public.game_save_take(p_me uuid)
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
  insert into public.game_save_buckets (user_id, tokens, updated_at)
  values (p_me, c_cap, now())
  on conflict (user_id) do nothing;
  update public.game_save_buckets
  set tokens = least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) - 1,
      updated_at = now()
  where user_id = p_me
    and least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) >= 1
  returning tokens into v_left;
  return v_left is not null;
end
$$;

-- {ok:true, rev, savedAt, data}; rev 0 and data null when nothing is saved yet.
create function public.game_save_load()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_row public.game_saves;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.game_save_take(v_me) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  select * into v_row from public.game_saves where user_id = v_me;
  if not found then
    return jsonb_build_object('ok', true, 'rev', 0, 'savedAt', null, 'data', null);
  end if;
  return jsonb_build_object('ok', true, 'rev', v_row.rev, 'savedAt', v_row.updated_at, 'data', v_row.data);
end
$$;

-- Writes [p_data] when [p_rev] is the stored rev, and returns the new rev.
-- Otherwise {ok:false, reason:'conflict', rev:<stored>}.
create function public.game_save_store(p_rev integer, p_data text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_max_bytes constant integer := 262144;
  v_me uuid := auth.uid();
  v_rev integer;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if p_data is null or octet_length(p_data) > c_max_bytes then
    return jsonb_build_object('ok', false, 'reason', 'too_big');
  end if;
  begin
    perform p_data::jsonb;
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'bad_data');
  end;
  if not public.game_save_take(v_me) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  insert into public.game_saves (user_id) values (v_me) on conflict (user_id) do nothing;
  select rev into v_rev from public.game_saves where user_id = v_me for update;
  if p_rev is distinct from v_rev then
    return jsonb_build_object('ok', false, 'reason', 'conflict', 'rev', v_rev);
  end if;
  update public.game_saves
  set rev = v_rev + 1, data = p_data, updated_at = now()
  where user_id = v_me;
  return jsonb_build_object('ok', true, 'rev', v_rev + 1);
end
$$;

revoke all on function public.game_save_take(uuid) from public, anon, authenticated;
revoke all on function public.game_save_load() from public, anon;
revoke all on function public.game_save_store(integer, text) from public, anon;
grant execute on function public.game_save_load() to authenticated;
grant execute on function public.game_save_store(integer, text) to authenticated;

commit;
