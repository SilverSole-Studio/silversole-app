-- supabase/migrations/20261112120000_rename_card_friend_helps.sql
--
-- 2026-11-13 已套用到正式庫（user 核准；apply_migration 名稱 rename_card_friend_helps）。
-- 要先套好 20261019120000_friends.sql、20261026120000_friends_rpc_abuse.sql、
-- 20261031120000_game_saves.sql、20261104120000_friend_farm.sql（這支用到 profiles、
-- friends_clean_nickname、friends_me、are_friends、friend_help_limits／friend_farm_take、
-- friend_helps、game_saves）。
--
-- 兩個功能（user 2026-11-12）：
--
-- 一、改名卡（「名字要改要買改名卡」）
--   - 第一次取暱稱免費（profiles.nickname 還是空的，或被檢舉抽掉 nickname_removed）。
--   - 之後改暱稱要一張「改名卡」，每改一次用掉一張，改完 24 小時內不能再改。
--   - 改名卡由伺服器記帳（nickname_cards）：每人預設 1 張（＝建立暱稱後可以免費改一次），
--     用完就鎖住、不再自動發卡（2026-11-12 user 定）。App 的改暱稱（update_profile）與網頁的 rename_with_card 同一套規則。金幣在手機上、不可信，所以不用金幣扣；
--     鑽石（diamond_ledger）是「運動換實物」的帳、1 鑽石約 NT$0.1，diamond_redeem 還沒開，
--     不拿來買虛擬道具（會跟 2026-11-02 鑽石設計「只換實物」打架）。
--     日後要「真的買」（商店內購、鑽石）時，由伺服器端呼叫 grant_rename_card()（只開給
--     service_role）加卡，不必動這支。
--   - 原本的 update_profile() 一天可免費改 3 次暱稱，會繞過改名卡。這支把它改成：
--     已有暱稱再改 → 有卡就扣一張照改（跟 rename_with_card 同規則：24 小時冷卻），沒卡丟 'nickname_needs_card'；頭像、列入機構名單照舊。
--     App（Flutter）改暱稱走 update_profile，所以 App 使用者也能用那一次免費改名；第二次起收到 nickname_needs_card，
--     錯誤對照（lib/core/friends/supabase_friends_repository.dart）還沒補，目前顯示一般失敗。
--   - 暱稱規則沿用 friends_clean_nickname（2–8 字、逐字白名單、保留字不能用），沒有另外加。
--     重複名不擋：好友用好友碼、user_id 區分，排行榜同名也不衝突。
--   - nickname_log 只增不改：誰、何時、從什麼改成什麼，給日後檢舉、客服對帳。
--
-- 二、串門子幫忙（「幫忙為主：澆水、除草、摸狗，雙方都拿一點獎勵，不能偷」）
--   - friend_water 已有（好友澆水）。新增 friend_weed（幫好友的小鎮除一叢雜草）與
--     friend_pet（摸好友的狗，對方要有養狗）。三種都「只記一筆」，被幫的人上線用
--     friend_helps_claim() 領，由頁面套到自己的存檔；伺服器不碰別人的存檔，所以偷不了東西。
--   - 每位好友每天每種各 1 次（friend_help_acts 的 unique）。
--   - 每人每天最多幫 8 次（澆水＋除草＋摸狗合計；澆水本身仍最多 5 位）。
--   - 每人每天最多被 除草＋摸狗 幫 6 次；等著領的紀錄最多 10 筆。
--   - 經驗由伺服器寫死：除草 幫的人 +2／被幫 +3、摸狗 幫的人 +2／被幫 +2。
--     一天最多幫 8 次 ≤ +24，量級跟澆水（+3）一樣小。
--   - 除草要對方存檔裡真的有雜草（state.weeds.list），且等著領的除草紀錄少於雜草數；
--     摸狗要對方存檔 state.hasDog = true。存檔是對方自己寫的（可偽造），所以只當
--     「合理性檢查」、獎勵再小也有上限；同 friend_farm 的已知限制。
--   - friend_water、friend_farm、friend_helps_claim、friend_helps_cleanup 這支各重寫一次
--     （同名 create or replace，簽章不變），差別只有：合計上限、回傳多了 town／acts。
--
-- 照 RPC 濫用自查清單（2026-10-26）寫：玩家會直接打 API、並發、開分身。
--   - security definer、search_path = ''、只開 authenticated；內部函式不開放。
--   - 身分一律 auth.uid()，沒有任何「呼叫者說他是誰」的參數。
--   - 好友＋沒封鎖（are_friends，FOR SHARE：解除好友／封鎖要等這次呼叫做完）。
--   - 次數都從帳本表算（friend_helps、friend_help_acts），沒有別的動作會刪或改它們
--     （領取只蓋 claimed_at；只有 service_role 的 cleanup 刪 14 天前的），
--     所以「先領再幫一次」或「解除好友再加回來」都不會重置次數。
--   - 先把雙方在 friend_help_limits 的列依 uuid 順序鎖住再數，並發的 N 次呼叫，次數精準。
--   - 失敗回 {ok:false, reason}、不 raise，限流的 token 才不會被回滾還回去。
--   - 改名：先鎖 profiles 列（跟 update_profile 同一把）、再鎖 nickname_cards 列，
--     兩份分身同時改名只有一個過得去；懲罰紀錄（nickname_log、卡的時鐘）不會被別的動作洗掉。

begin;

-- ════════════════════════════════════════════════════════════════════════
-- 一、改名卡
-- ════════════════════════════════════════════════════════════════════════

-- 每人一列：卡片餘額與「下一張卡」的計時起點、最近一次改名。
create table public.nickname_cards (
  user_id uuid primary key references auth.users (id) on delete cascade,
  cards smallint not null default 1 check (cards between 0 and 2),
  -- 下一張卡從這個時間起算 30 天（卡滿 2 張時沒有意義，用掉一張時重設成 now()）。
  granted_at timestamptz not null default now(),
  changed_count integer not null default 0,
  last_changed_at timestamptz
);
alter table public.nickname_cards enable row level security;
revoke all on public.nickname_cards from anon, authenticated;

-- 改名紀錄：只增不改（trigger 擋 UPDATE，沒有給 App 的刪除；帳號刪除時一起走）。
create table public.nickname_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  old_name text,
  new_name text not null,
  via text not null check (via in ('first', 'repick', 'card')),
  created_at timestamptz not null default now()
);
create index nickname_log_user_idx on public.nickname_log (user_id, created_at desc);
alter table public.nickname_log enable row level security;
revoke all on public.nickname_log from anon, authenticated;

create function public.nickname_log_no_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'nickname_log is append-only';
end
$$;
create trigger nickname_log_no_update
  before update on public.nickname_log
  for each row execute function public.nickname_log_no_update();

-- 2026-11-12 user 定：建立暱稱後可以免費改一次（預設 1 張），之後就鎖住，不再隨時間發卡。
--   之後要開放買卡，由伺服器端 grant_rename_card（只開給 service_role）發。
-- 把這個人的卡結算到現在：只確保有這一列（不再每 30 天自動 +1）。
-- 呼叫前已鎖住這個人的 profiles 列；這裡再鎖 nickname_cards 列。回傳結算後的那一列。
create function public.rename_cards_settle(p_me uuid)
returns public.nickname_cards
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c public.nickname_cards;
begin
  insert into public.nickname_cards (user_id) values (p_me) on conflict (user_id) do nothing;
  select * into c from public.nickname_cards where user_id = p_me for update;
  return c;
end
$$;

-- 改暱稱要卡之後，update_profile 不能再讓人免費換名。
-- 跟 20261019120000_friends.sql 的版本只差暱稱那一段（其餘逐字相同）。
create or replace function public.update_profile(
  p_nickname text default null,
  p_avatar_preset integer default null,
  p_show_in_org_list boolean default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := public.friends_me();
  p public.profiles;
  c public.nickname_cards;
  v_name text;
begin
  select * into p from public.profiles where user_id = v_me for update;

  if p_nickname is not null then
    v_name := public.friends_clean_nickname(p_nickname);
    if v_name is null then
      raise exception 'nickname_invalid';
    end if;
    if p.nickname is distinct from v_name then
      -- 已經有名字（沒被抽掉）的人要改名：要有改名卡（預設 1 張＝免費改一次），扣一張照改；沒卡就擋。
      -- 2026-11-12：App 的改暱稱也走這裡，不另外接 rename_with_card，所以這裡跟 rename_with_card 同一套規則（24 小時冷卻、扣卡、記 card）。
      if p.nickname is not null and not p.nickname_removed then
        c := public.rename_cards_settle(v_me);
        if c.last_changed_at is not null and c.last_changed_at + interval '24 hours' > now() then
          raise exception 'nickname_needs_card';
        end if;
        if c.cards < 1 then
          raise exception 'nickname_needs_card';
        end if;
        update public.nickname_cards
        set cards = cards - 1, changed_count = changed_count + 1, last_changed_at = now()
        where user_id = v_me;
      end if;
      update public.profiles
      set nickname = v_name, nickname_removed = false, updated_at = now()
      where user_id = v_me;
      insert into public.nickname_log (user_id, old_name, new_name, via)
      values (v_me, p.nickname, v_name, case when p.nickname is null then 'first' when p.nickname_removed then 'repick' else 'card' end);
    end if;
  end if;

  if p_avatar_preset is not null then
    if p_avatar_preset not between 1 and 12 then
      raise exception 'not_found';
    end if;
    update public.profiles
    set avatar_preset = p_avatar_preset, updated_at = now()
    where user_id = v_me;
  end if;

  if p_show_in_org_list is not null then
    update public.profiles
    set show_in_org_list = p_show_in_org_list, updated_at = now()
    where user_id = v_me;
  end if;

  return public.friends_my_profile_json(v_me);
end
$$;

-- {ok:true, nickname, free, cards, nextCardAt, canChangeAt}
--   free:       true＝現在改名不用卡（還沒取過名、或名字被抽掉要重取）
--   cards:      手上幾張卡（已結算）
--   nextCardAt: 下一張卡什麼時候發（卡滿 2 張是 null）
--   canChangeAt:24 小時冷卻到什麼時候（沒有冷卻是 null）
-- reasons: signed_out, rate_limited
create function public.rename_status()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  p public.profiles;
  c public.nickname_cards;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.friend_farm_take(v_me, 1) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  v_me := public.friends_me();
  select * into p from public.profiles where user_id = v_me for update;
  c := public.rename_cards_settle(v_me);
  return jsonb_build_object(
    'ok', true,
    'nickname', p.nickname,
    'free', (p.nickname is null or p.nickname_removed),
    'cards', c.cards,
    'nextCardAt', null,
    'canChangeAt', case when c.last_changed_at is not null and c.last_changed_at + interval '24 hours' > now()
                        then c.last_changed_at + interval '24 hours' end
  );
end
$$;

-- 用一張改名卡改暱稱。
-- {ok:true, nickname, cards, nextCardAt}
-- reasons: signed_out, rate_limited, nickname_invalid, same_name, no_name_yet（還沒取過名，
--          請走 update_profile 免費取名）, cooldown（+canChangeAt）, no_card（+nextCardAt）
create function public.rename_with_card(p_nickname text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_cooldown constant interval := interval '24 hours';
  v_me uuid := auth.uid();
  p public.profiles;
  c public.nickname_cards;
  v_name text;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if not public.friend_farm_take(v_me, 3) then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  v_me := public.friends_me();
  -- 先鎖 profiles（跟 update_profile 同一把），再鎖卡：兩份分身同時改名，排隊一個一個過。
  select * into p from public.profiles where user_id = v_me for update;
  v_name := public.friends_clean_nickname(p_nickname);
  if v_name is null then
    return jsonb_build_object('ok', false, 'reason', 'nickname_invalid');
  end if;
  if p.nickname is null or p.nickname_removed then
    return jsonb_build_object('ok', false, 'reason', 'no_name_yet');
  end if;
  if p.nickname = v_name then
    return jsonb_build_object('ok', false, 'reason', 'same_name');
  end if;
  c := public.rename_cards_settle(v_me);
  if c.last_changed_at is not null and c.last_changed_at + c_cooldown > now() then
    return jsonb_build_object('ok', false, 'reason', 'cooldown',
      'canChangeAt', c.last_changed_at + c_cooldown);
  end if;
  if c.cards < 1 then
    return jsonb_build_object('ok', false, 'reason', 'no_card',
      'nextCardAt', null);
  end if;
  update public.nickname_cards
  set cards = cards - 1,
      -- 原本卡是滿的（2 張）→ 用掉一張的這一刻才開始算下一張
      granted_at = case when c.cards >= 2 then now() else c.granted_at end,
      changed_count = changed_count + 1,
      last_changed_at = now()
  where user_id = v_me
  returning * into c;
  update public.profiles
  set nickname = v_name, updated_at = now()
  where user_id = v_me;
  insert into public.nickname_log (user_id, old_name, new_name, via)
  values (v_me, p.nickname, v_name, 'card');
  return jsonb_build_object('ok', true, 'nickname', v_name, 'cards', c.cards,
    'nextCardAt', null);
end
$$;

-- 發卡（日後商店內購、鑽石兌換、客服補發）：只開給 service_role。最多存 2 張。
create function public.grant_rename_card(p_user uuid, p_count integer default 1)
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_cards integer;
begin
  if p_user is null or p_count is null or p_count < 1 or p_count > 2 then
    raise exception 'bad_args';
  end if;
  insert into public.nickname_cards (user_id) values (p_user) on conflict (user_id) do nothing;
  update public.nickname_cards
  set cards = least(2, cards + p_count)
  where user_id = p_user
  returning cards into v_cards;
  return v_cards;
end
$$;

-- ════════════════════════════════════════════════════════════════════════
-- 二、串門子幫忙：除草、摸狗
-- ════════════════════════════════════════════════════════════════════════

-- 一列＝「helper 在 day 這天幫 helped 做了一次 kind」。每位好友每天每種最多一次。
create table public.friend_help_acts (
  id uuid primary key default gen_random_uuid(),
  helper uuid not null references auth.users (id) on delete cascade,
  helped uuid not null references auth.users (id) on delete cascade,
  day date not null,
  kind text not null check (kind in ('weed', 'pet')),
  helper_xp smallint not null check (helper_xp between 0 and 20),
  helped_xp smallint not null check (helped_xp between 0 and 20),
  created_at timestamptz not null default now(),
  helped_claimed_at timestamptz,
  helper_claimed_at timestamptz,
  check (helper <> helped),
  unique (helper, helped, day, kind)
);
create index friend_help_acts_helper_day_idx on public.friend_help_acts (helper, day);
create index friend_help_acts_helped_day_idx on public.friend_help_acts (helped, day);
create index friend_help_acts_helped_open_idx on public.friend_help_acts (helped) where helped_claimed_at is null;
create index friend_help_acts_helper_open_idx on public.friend_help_acts (helper) where helper_claimed_at is null;
alter table public.friend_help_acts enable row level security;
revoke all on public.friend_help_acts from anon, authenticated;

-- 這個人這一天幫了幾次（澆水＋除草＋摸狗）。
create function public.friend_help_total(p_helper uuid, p_day date)
returns integer
language sql
stable
set search_path = ''
as $$
  select (select count(*) from public.friend_helps where helper = p_helper and day = p_day)::integer
       + (select count(*) from public.friend_help_acts where helper = p_helper and day = p_day)::integer
$$;

-- 對方存檔（已 friend_farm_parse 過的農場物件）裡的雜草叢數（0..8）與有沒有狗。
create function public.friend_town_view(p_farm jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_weeds integer := 0;
  v_dog boolean := false;
begin
  if jsonb_typeof(p_farm -> 'weeds' -> 'list') = 'array' then
    v_weeds := least(jsonb_array_length(p_farm -> 'weeds' -> 'list'), 8);
  end if;
  if jsonb_typeof(p_farm -> 'hasDog') = 'boolean' then
    v_dog := (p_farm ->> 'hasDog')::boolean;
  end if;
  return jsonb_build_object('weeds', v_weeds, 'hasDog', v_dog);
exception when others then
  return jsonb_build_object('weeds', 0, 'hasDog', false);
end
$$;

-- 除草、摸狗的共同做法。p_kind 只能是 'weed' 或 'pet'（內部呼叫，不開放給 App）。
create function public.friend_help_act(p_kind text, p_friend uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_total_max constant integer := 8;       -- 一個人一天最多幫幾次（澆水＋除草＋摸狗）
  c_received_max constant integer := 6;    -- 一個人一天最多被除草＋摸狗幾次
  c_waiting_max constant integer := 10;    -- 等著一個人領的紀錄上限（兩種表合計）
  v_me uuid := auth.uid();
  v_today date := public.friends_today();
  v_helper_xp integer;
  v_helped_xp integer;
  v_save public.game_saves;
  v_farm jsonb;
  v_town jsonb;
  v_used integer;
  v_count integer;
  v_pending integer;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if p_kind = 'weed' then
    v_helper_xp := 2; v_helped_xp := 3;
  elsif p_kind = 'pet' then
    v_helper_xp := 2; v_helped_xp := 2;
  else
    return jsonb_build_object('ok', false, 'reason', 'bad_kind');
  end if;
  if p_friend is null or p_friend = v_me then
    return jsonb_build_object('ok', false, 'reason', 'not_friend');
  end if;
  if not public.are_friends(v_me, p_friend, true) then
    return jsonb_build_object('ok', false, 'reason', 'not_friend');
  end if;
  -- 鎖雙方的 limits 列（uuid 順序），之後的計數才準；並發的呼叫在這裡排隊。
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

  if exists (select 1 from public.friend_help_acts
             where helper = v_me and helped = p_friend and day = v_today and kind = p_kind) then
    return jsonb_build_object('ok', false, 'reason', 'already_today');
  end if;
  v_used := public.friend_help_total(v_me, v_today);
  if v_used >= c_total_max then
    return jsonb_build_object('ok', false, 'reason', 'daily_limit');
  end if;
  select count(*) into v_count from public.friend_help_acts where helped = p_friend and day = v_today;
  if v_count >= c_received_max then
    return jsonb_build_object('ok', false, 'reason', 'friend_full');
  end if;
  select (select count(*) from public.friend_helps where helped = p_friend and helped_claimed_at is null)
       + (select count(*) from public.friend_help_acts where helped = p_friend and helped_claimed_at is null)
    into v_count;
  if v_count >= c_waiting_max then
    return jsonb_build_object('ok', false, 'reason', 'friend_full');
  end if;

  select * into v_save from public.game_saves where user_id = p_friend;
  v_farm := public.friend_farm_parse(v_save.data);
  if v_farm is null then
    return jsonb_build_object('ok', false, 'reason', 'no_farm');
  end if;
  v_town := public.friend_town_view(v_farm);
  if p_kind = 'weed' then
    select count(*) into v_pending from public.friend_help_acts
    where helped = p_friend and kind = 'weed' and helped_claimed_at is null;
    if (v_town ->> 'weeds')::integer <= 0 then
      return jsonb_build_object('ok', false, 'reason', 'no_weeds');
    end if;
    if v_pending >= (v_town ->> 'weeds')::integer then
      return jsonb_build_object('ok', false, 'reason', 'weeds_waiting');
    end if;
  elsif not (v_town ->> 'hasDog')::boolean then
    return jsonb_build_object('ok', false, 'reason', 'no_dog');
  end if;

  insert into public.friend_help_acts (helper, helped, day, kind, helper_xp, helped_xp)
  values (v_me, p_friend, v_today, p_kind, v_helper_xp, v_helped_xp);
  return jsonb_build_object(
    'ok', true,
    'helperXp', v_helper_xp,
    'helpedXp', v_helped_xp,
    'leftToday', c_total_max - v_used - 1
  );
end
$$;

-- reasons: signed_out, not_friend, rate_limited, already_today, daily_limit, friend_full,
--          no_farm, no_weeds, weeds_waiting
create function public.friend_weed(p_friend uuid)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select public.friend_help_act('weed', p_friend)
$$;

-- reasons: signed_out, not_friend, rate_limited, already_today, daily_limit, friend_full,
--          no_farm, no_dog
create function public.friend_pet(p_friend uuid)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select public.friend_help_act('pet', p_friend)
$$;

-- ── 重寫 friend_water：加上「一天合計最多幫 8 次」，其餘跟 20261104120000 相同 ──────
create or replace function public.friend_water(p_friend uuid, p_plot integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_daily_max constant integer := 5;       -- 一天最多幫幾位好友澆水
  c_total_max constant integer := 8;       -- 澆水＋除草＋摸狗 合計
  c_received_max constant integer := 5;    -- 一個人一天最多被澆水幾次
  c_waiting_max constant integer := 10;    -- 等著一個人領的澆水紀錄上限
  c_helper_xp constant integer := 3;
  c_helped_xp constant integer := 5;
  v_me uuid := auth.uid();
  v_today date := public.friends_today();
  v_save public.game_saves;
  v_farm jsonb;
  v_plot jsonb;
  v_used integer;
  v_total integer;
  v_count integer;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if p_friend is null or p_plot is null or p_plot < 0 or p_plot > 11 then
    return jsonb_build_object('ok', false, 'reason', 'bad_plot');
  end if;
  if not public.are_friends(v_me, p_friend, true) then
    return jsonb_build_object('ok', false, 'reason', 'not_friend');
  end if;
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
  v_total := public.friend_help_total(v_me, v_today);
  if v_used >= c_daily_max or v_total >= c_total_max then
    return jsonb_build_object('ok', false, 'reason', 'daily_limit');
  end if;
  select count(*) into v_count from public.friend_helps where helped = p_friend and day = v_today;
  if v_count >= c_received_max then
    return jsonb_build_object('ok', false, 'reason', 'friend_full');
  end if;
  select (select count(*) from public.friend_helps where helped = p_friend and helped_claimed_at is null)
       + (select count(*) from public.friend_help_acts where helped = p_friend and helped_claimed_at is null)
    into v_count;
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
    'leftToday', least(c_daily_max - v_used, c_total_max - v_total) - 1
  );
end
$$;

-- ── 重寫 friend_farm：多回 town（雜草數、有沒有狗）與每種今天做過沒，
--    leftToday 改成合計剩幾次。其餘跟 20261104120000 相同。 ─────────────────────
create or replace function public.friend_farm(p_friend uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_daily_max constant integer := 5;
  c_total_max constant integer := 8;
  v_me uuid := auth.uid();
  v_save public.game_saves;
  v_farm jsonb;
  v_xp integer;
  v_level integer;
  v_view jsonb;
  v_town jsonb;
  v_today date := public.friends_today();
  v_done boolean;
  v_used integer;
  v_total integer;
  v_pending jsonb;
  v_weed_pending integer;
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
  v_town := public.friend_town_view(v_farm);
  select exists (select 1 from public.friend_helps
                 where helper = v_me and helped = p_friend and day = v_today)
    into v_done;
  select count(*) into v_used from public.friend_helps where helper = v_me and day = v_today;
  v_total := public.friend_help_total(v_me, v_today);
  select coalesce(jsonb_agg(plot order by plot), '[]'::jsonb) into v_pending
  from public.friend_helps where helped = p_friend and helped_claimed_at is null;
  select count(*) into v_weed_pending from public.friend_help_acts
  where helped = p_friend and kind = 'weed' and helped_claimed_at is null;
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
      'leftToday', greatest(least(c_daily_max - v_used, c_total_max - v_total), 0),
      'pendingPlots', v_pending
    ),
    'town', jsonb_build_object(
      'weeds', greatest((v_town ->> 'weeds')::integer - v_weed_pending, 0),
      'hasDog', (v_town ->> 'hasDog')::boolean,
      'weedDoneToday', exists (select 1 from public.friend_help_acts
        where helper = v_me and helped = p_friend and day = v_today and kind = 'weed'),
      'petDoneToday', exists (select 1 from public.friend_help_acts
        where helper = v_me and helped = p_friend and day = v_today and kind = 'pet'),
      'leftToday', greatest(c_total_max - v_total, 0)
    )
  );
end
$$;

-- ── 重寫 friend_helps_claim：多回 acts（別人幫我除草、摸狗），幫人的經驗一起算進 givenXp ──
-- {ok:true, received:[{plot, xp, from}], acts:[{kind, xp, from}], givenXp}
--   舊版頁面只看 received／givenXp：幫人的經驗照領、被幫的除草／摸狗經驗它不會套
--   （紀錄仍會被標成已領）。所以頁面要先上線這版，再套這支 migration。
create or replace function public.friend_helps_claim()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_received jsonb;
  v_acts jsonb;
  v_given integer;
  v_given_acts integer;
begin
  if v_me is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
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
    update public.friend_help_acts h
    set helped_claimed_at = now()
    where h.helped = v_me and h.helped_claimed_at is null
    returning h.kind, h.helped_xp, h.helper, h.created_at
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'kind', got.kind,
      'xp', got.helped_xp,
      'from', coalesce(p.nickname, '銀足朋友')
    ) order by got.created_at), '[]'::jsonb)
  into v_acts
  from got left join public.profiles p on p.user_id = got.helper;
  with got as (
    update public.friend_helps h
    set helper_claimed_at = now()
    where h.helper = v_me and h.helper_claimed_at is null
    returning h.helper_xp
  )
  select coalesce(sum(got.helper_xp), 0)::integer into v_given from got;
  with got as (
    update public.friend_help_acts h
    set helper_claimed_at = now()
    where h.helper = v_me and h.helper_claimed_at is null
    returning h.helper_xp
  )
  select coalesce(sum(got.helper_xp), 0)::integer into v_given_acts from got;
  return jsonb_build_object('ok', true, 'received', v_received, 'acts', v_acts,
    'givenXp', v_given + v_given_acts);
end
$$;

-- 14 天前的紀錄一起清（pg_cron 已排好 friend_helps_cleanup，見 20261104130000）。
create or replace function public.friend_helps_cleanup()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_n integer;
  v_m integer;
begin
  delete from public.friend_helps where day < public.friends_today() - 14;
  get diagnostics v_n = row_count;
  delete from public.friend_help_acts where day < public.friends_today() - 14;
  get diagnostics v_m = row_count;
  return v_n + v_m;
end
$$;

-- ── 權限 ────────────────────────────────────────────────────────────────

revoke all on function
  public.nickname_log_no_update(),
  public.rename_cards_settle(uuid),
  public.grant_rename_card(uuid, integer),
  public.friend_help_total(uuid, date),
  public.friend_town_view(jsonb),
  public.friend_help_act(text, uuid)
  from public, anon, authenticated;
revoke all on function
  public.rename_status(),
  public.rename_with_card(text),
  public.friend_weed(uuid),
  public.friend_pet(uuid)
  from public, anon;
grant execute on function
  public.rename_status(),
  public.rename_with_card(text),
  public.friend_weed(uuid),
  public.friend_pet(uuid)
  to authenticated;
grant execute on function public.grant_rename_card(uuid, integer) to service_role;

commit;
