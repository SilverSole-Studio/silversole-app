-- supabase/migrations/20261113120000_active_aging.sql
--
-- 銀足樂齡模式（據點課程主持、鏡頭量測紀錄）：資料表、角色、邀請碼、12 支 RPC。
--
-- 狀態：草稿，未套用到任何 Supabase 專案。套用前先問 user 與技術長。
-- 規格：動域科技總倉庫 02_產品/銀足樂齡_ActiveAging/商業營運計畫_無人化外派模式/
--   08_H5與App資料介面_RPC清單.md（欄位、範圍、列舉、筆數）與 07_APP整合需求單_銀足樂齡模式.md。
-- App 端：lib/core/active_aging/（aaRpc 橋接、白名單、reason 對照）。
--
-- 原則（RPC 濫用自查清單）：一律假設對方拿自己的 token 直接打 API、並發、開分身。
--   - 所有 aa_ 表開 RLS、沒有任何政策、anon 與 authenticated 全部 revoke；只走 security definer RPC，
--     search_path 固定為空字串。
--   - 每支 RPC 第一步 aa_gate()：登入、每人限流（token bucket）、角色。同一人的呼叫因 bucket 列鎖而排隊；
--     寫入場次內容時再鎖場次列，之後若有多人同寫一場也排隊，所以「上限」的檢查與寫入在同一把鎖裡。
--   - 冪等：用戶端 UUID 當 key，on conflict 只更新可變欄位。key 一律含場次（session_id, mid），
--     別人拿同一個 mid 打自己的場次，蓋不到你的列。
--   - 錯誤回 {ok:false, reason}（不 raise），這樣限流、鎖定、稽核的紀錄才不會跟著回滾。
--   - 錯誤次數表與稽核表沒有外鍵：刪帳號、刪場次、別的動作都洗不掉。
--   - 型別、範圍、列舉、筆數、jsonb 多餘 key 都由資料庫檢查（RPC 與 check constraint 兩層）。
--   - 不存姓名與影像。量測屬特種個資（個資法第 6 條），要有書面同意才收。
--
-- 回傳慣例：成功 {ok:true, ...}；失敗 {ok:false, reason}。
--   reason：signed_out、not_member、forbidden、rate_limited、invalid、too_large、closed
--   （跟 08 第一節一樣；邀請碼的各種失敗一律 invalid，不讓人探是哪一種）。
--   整批寫入（參加者、同意、事件）全過才寫，有一列不合就整批不寫；
--   量測是逐列：壞的進 rejected，原因 invalid、no_consent、empty、out_of_range、bad_time、immutable、too_large。

begin;

-- ── 小工具（純函式，不碰資料）───────────────────────────────────────────

create function public.aa_err(p_reason text)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('ok', false, 'reason', p_reason)
$$;

-- jsonb 物件，而且所有 key 都在白名單內（多餘欄位一律拒絕）。
create function public.aa_keys_ok(j jsonb, allowed text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select j is not null
    and jsonb_typeof(j) = 'object'
    and not exists (select 1 from jsonb_object_keys(j) k where k <> all (allowed))
$$;

-- j->k 是字串且長度在範圍內。
create function public.aa_is_text(j jsonb, k text, p_min integer, p_max integer)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(j -> k) = 'string'
    and char_length(j ->> k) between p_min and p_max
$$;

-- 缺少或 JSON null。
create function public.aa_is_absent(j jsonb, k text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(j -> k) is null or jsonb_typeof(j -> k) = 'null'
$$;

-- 數字（JSON number）；不是數字回 null。
create function public.aa_num(j jsonb, k text)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(j -> k) = 'number' then (j ->> k)::numeric end
$$;

-- 標準寫法的 UUID 字串（帶連字號）；否則 null。
create function public.aa_uuid(j jsonb, k text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when jsonb_typeof(j -> k) = 'string'
      and (j ->> k) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then (j ->> k)::uuid
  end
$$;

-- ISO 8601 時間字串；否則 null。不收 'now'、'epoch'、'infinity' 這類 Postgres 特殊字串。
create function public.aa_ts(j jsonb, k text)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
begin
  if jsonb_typeof(j -> k) = 'string'
     and (j ->> k) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-][0-9]{2}(:?[0-9]{2})?)$'
  then
    return (j ->> k)::timestamptz;
  end if;
  return null;
exception when others then
  return null;
end
$$;

-- 量測數值：椅子坐立 0 至 60 的整數；單腳站立 0 至 45、一位小數。空值算通過。
create function public.aa_meas_val_ok(p_item text, v numeric)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select v is null
    or (p_item = 'chair30' and v between 0 and 60 and v = trunc(v))
    or (p_item = 'sls' and v between 0 and 45 and v = round(v, 1))
$$;

-- ── 資料表 ────────────────────────────────────────────────────────────

-- 角色：一人一列。revoked_at 有值＝被公司停用，不能再用邀請碼自己啟用回來。
create table public.aa_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role text not null check (role in ('instructor', 'assistant')),
  invite_id uuid,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

-- 邀請碼：公司後台發、可停用、可重發。預設一碼一人。
create table public.aa_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[1-9][0-9]{7}$'),
  role text not null check (role in ('instructor', 'assistant')),
  -- 備註：發給誰或哪個據點，不放身分證、電話。
  label text check (label is null or char_length(label) <= 60),
  max_uses integer not null default 1 check (max_uses between 1 and 50),
  used_count integer not null default 0,
  expires_at timestamptz not null,
  disabled_at timestamptz,
  created_by text,
  created_at timestamptz not null default now(),
  check (used_count between 0 and max_uses)
);
alter table public.aa_roles
  add constraint aa_roles_invite_fk foreign key (invite_id) references public.aa_invites (id) on delete set null;

-- 啟用碼輸入紀錄：只增不改、沒有外鍵（刪帳號重開、別的動作都洗不掉）。
create table public.aa_invite_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  ok boolean not null,
  at timestamptz not null default now()
);
create index aa_invite_attempts_user_idx on public.aa_invite_attempts (user_id, at);
create index aa_invite_attempts_at_idx on public.aa_invite_attempts (at) where not ok;

-- 稽核：誰、呼叫哪個函式、哪一場、結果、何時。只增不改、沒有外鍵；只有管理員（service_role）可讀。
create table public.aa_audit (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  fn text not null,
  session_id uuid,
  ok boolean not null,
  reason text,
  at timestamptz not null default now()
);
create index aa_audit_user_idx on public.aa_audit (user_id, at);
create index aa_audit_session_idx on public.aa_audit (session_id) where session_id is not null;

create table public.aa_rate_buckets (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tokens real not null,
  updated_at timestamptz not null default now()
);

create table public.aa_sessions (
  id uuid primary key,
  -- 開場的人。建立後不能改。寫入權限看 aa_session_members，不是只看這欄。
  owner_id uuid not null references auth.users (id) on delete cascade,
  site text not null check (char_length(site) between 1 and 60),
  series text not null check (series in ('steady', 'hands', 'strength')),
  type text not null check (type in ('normal', 'measure')),
  planned_count integer not null check (planned_count between 0 and 40),
  aed_location text not null default '' check (char_length(aed_location) <= 60),
  started_at timestamptz not null,
  -- closed_at 是用戶端回報的結案時間；closed_server_at 是伺服器收到的時間，7 天補寫期看這個。
  closed_at timestamptz,
  closed_server_at timestamptz,
  -- 保存期限未定（07 第十節）。有值時由管理員的清除函式處理。
  retention_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index aa_sessions_owner_idx on public.aa_sessions (owner_id, started_at desc);

-- 場次成員：第一版只有 owner 一列。預留給「同場多人各用自己的手機寫入」（08 第五節第 1 點）。
create table public.aa_session_members (
  session_id uuid not null references public.aa_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'assistant')),
  joined_at timestamptz not null default now(),
  primary key (session_id, user_id)
);
create index aa_session_members_user_idx on public.aa_session_members (user_id);

create table public.aa_participants (
  session_id uuid not null references public.aa_sessions (id) on delete cascade,
  code text not null check (code ~ '^P[0-9]{2,3}$'),
  rolled boolean not null default false,
  answers jsonb check (
    answers is null or (
      jsonb_typeof(answers) = 'object'
      and public.aa_keys_ok(answers, array['unwell', 'meds', 'fell'])
    )
  ),
  seated boolean not null default false,
  reasons text[] not null default '{}'
    check (reasons <@ array['unwell', 'meds', 'fell']::text[] and cardinality(reasons) <= 3),
  grp text check (grp in ('A', 'B')),
  -- 當事人要求刪除後留一列空殼，擋掉離線佇列之後重送把資料寫回來。
  erased_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, code)
);

-- 同意：(場次, 編號, 類型) 一列，最新一筆生效；撤回寫 granted = false。
create table public.aa_consents (
  session_id uuid not null,
  code text not null,
  type text not null check (type in ('measure', 'portrait', 'camera', 'research')),
  granted boolean not null,
  version text not null check (char_length(version) between 1 and 20),
  method text not null check (method in ('paper', 'esign')),
  at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (session_id, code, type),
  foreign key (session_id, code) references public.aa_participants (session_id, code) on delete cascade
);

-- 同意歷史：append-only（沒有任何 RPC 會改它；只有整場刪除與當事人刪除會一起刪掉）。
create table public.aa_consent_history (
  id bigint generated always as identity primary key,
  session_id uuid not null,
  code text not null,
  type text not null,
  granted boolean not null,
  version text not null,
  method text not null,
  at timestamptz not null,
  recorded_by uuid not null,
  recorded_at timestamptz not null default now(),
  foreign key (session_id, code) references public.aa_participants (session_id, code) on delete cascade
);
create index aa_consent_history_idx on public.aa_consent_history (session_id, code, type, id);

create table public.aa_measurements (
  session_id uuid not null,
  mid uuid not null,
  code text not null,
  item text not null check (item in ('chair30', 'sls')),
  side text not null default '' check (side in ('', 'L', 'R')),
  human1 numeric(4, 1),
  human2 numeric(4, 1),
  camera numeric(4, 1),
  camera2 numeric(4, 1),
  camera_valid boolean,
  camera_note text not null default '' check (char_length(camera_note) <= 200),
  cam_fps numeric(5, 1) check (cam_fps between 0 and 120),
  cam_detect numeric(4, 3) check (cam_detect between 0 and 1),
  assisted boolean not null default false,
  note text not null default '' check (char_length(note) <= 200),
  at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, mid),
  foreign key (session_id, code) references public.aa_participants (session_id, code) on delete cascade,
  check ((item = 'chair30' and side = '') or (item = 'sls' and side in ('L', 'R'))),
  check (
    public.aa_meas_val_ok(item, human1) and public.aa_meas_val_ok(item, human2)
    and public.aa_meas_val_ok(item, camera) and public.aa_meas_val_ok(item, camera2)
  ),
  check (human1 is not null or human2 is not null or camera is not null or camera2 is not null),
  check (camera_valid is null or camera is not null or camera2 is not null)
);
create index aa_measurements_code_idx on public.aa_measurements (session_id, code);

create table public.aa_events (
  session_id uuid not null references public.aa_sessions (id) on delete cascade,
  eid uuid not null,
  type text not null check (type in ('stop', 'note')),
  -- 空字串＝不針對特定參加者。
  code text not null default '' check (code = '' or code ~ '^P[0-9]{2,3}$'),
  condition_index integer check (condition_index between 0 and 5),
  text text not null default '' check (char_length(text) <= 200),
  at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (session_id, eid),
  check (
    (type = 'stop' and condition_index is not null)
    or (type = 'note' and condition_index is null and text <> '')
  )
);
create index aa_events_code_idx on public.aa_events (session_id, code);

-- 全部開 RLS、沒有政策、對 App 的角色全關；只有 security definer 函式與 service_role 碰得到。
do $$
declare
  t text;
begin
  for t in
    select unnest(array[
      'aa_roles', 'aa_invites', 'aa_invite_attempts', 'aa_audit', 'aa_rate_buckets',
      'aa_sessions', 'aa_session_members', 'aa_participants', 'aa_consents',
      'aa_consent_history', 'aa_measurements', 'aa_events'
    ])
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
  end loop;
end
$$;

-- 管理員驗證分析用：人工與鏡頭成對的量測。沒有姓名；只有 service_role 讀得到。
create view public.aa_paired_measurements
with (security_invoker = true) as
select
  s.id as session_id, s.site, s.series, s.type as session_type, s.started_at as session_started_at,
  m.mid, m.code, m.item, m.side,
  m.human1, m.human2, m.camera, m.camera2, m.camera_valid, m.camera_note,
  m.cam_fps, m.cam_detect, m.assisted, m.note, m.at
from public.aa_measurements m
join public.aa_sessions s on s.id = m.session_id;
revoke all on public.aa_paired_measurements from public, anon, authenticated;

-- ── 限流、稽核、角色門檻 ───────────────────────────────────────────────

-- 每人一個 token bucket：容量 30、每秒回 0.5。列鎖住到交易結束，同一個人的呼叫排隊。
create function public.aa_take(p_me uuid, p_cost real)
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
  insert into public.aa_rate_buckets (user_id, tokens, updated_at)
  values (p_me, c_cap, now())
  on conflict (user_id) do nothing;
  update public.aa_rate_buckets
  set tokens = least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) - p_cost,
      updated_at = now()
  where user_id = p_me
    and least(c_cap, tokens + extract(epoch from (now() - updated_at))::real * c_rate) >= p_cost
  returning tokens into v_left;
  return v_left is not null;
end
$$;

-- 每支 RPC 的第一步。回 {uid, role}，或 {reason}。
create function public.aa_gate(p_cost real, p_need_role boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_role text;
begin
  if v_me is null then
    return jsonb_build_object('reason', 'signed_out');
  end if;
  if not public.aa_take(v_me, p_cost) then
    return jsonb_build_object('reason', 'rate_limited');
  end if;
  select r.role into v_role
  from public.aa_roles r
  where r.user_id = v_me and r.revoked_at is null;
  if p_need_role and v_role is null then
    return jsonb_build_object('reason', 'not_member');
  end if;
  return jsonb_build_object('uid', v_me, 'role', v_role);
end
$$;

-- 稽核一列。沒登入或被限流的呼叫不記（不然拿來灌爆稽核表）。
create function public.aa_log(p_me uuid, p_fn text, p_session uuid, p_res jsonb)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_me is null or coalesce(p_res ->> 'reason', '') in ('signed_out', 'rate_limited') then
    return;
  end if;
  insert into public.aa_audit (user_id, fn, session_id, ok, reason)
  values (p_me, p_fn, p_session, coalesce((p_res ->> 'ok')::boolean, false), p_res ->> 'reason');
end
$$;

-- 取場次：存在而且呼叫者是成員（owner_only 時要是 owner）才回；否則回空的列。
-- 不分「不存在」與「不是你的」，不讓人探別人的場次 id。p_lock＝鎖住這一列到交易結束。
create function public.aa_session_for(p_me uuid, p_id uuid, p_owner_only boolean, p_lock boolean)
returns public.aa_sessions
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
begin
  if p_id is null then
    return null;
  end if;
  if p_lock then
    select * into v_s from public.aa_sessions s where s.id = p_id for update;
  else
    select * into v_s from public.aa_sessions s where s.id = p_id;
  end if;
  if not found then
    return null;
  end if;
  if p_owner_only then
    if v_s.owner_id <> p_me then
      return null;
    end if;
  elsif not exists (
    select 1 from public.aa_session_members m
    where m.session_id = p_id and m.user_id = p_me
  ) then
    return null;
  end if;
  return v_s;
end
$$;

-- 結案超過 7 天（伺服器時間）就不收補寫。
create function public.aa_session_closed(s public.aa_sessions)
returns boolean
language sql
stable
set search_path = ''
as $$
  select s.closed_server_at is not null and now() > s.closed_server_at + interval '7 days'
$$;

-- 時間不能比現在晚超過 1 天，也不能比場次開始早超過 1 天。
create function public.aa_time_ok(p_at timestamptz, p_started timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_at is not null
    and p_at <= now() + interval '1 day'
    and p_at >= p_started - interval '1 day'
$$;

-- ── 逐列檢查（回 null＝通過，否則 reason）────────────────────────────────

create function public.aa_check_participant(j jsonb)
returns text
language plpgsql
immutable
set search_path = ''
as $$
begin
  if not public.aa_keys_ok(j, array['code', 'rolled', 'answers', 'seated', 'reasons', 'group']) then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'code') is distinct from 'string' or (j ->> 'code') !~ '^P[0-9]{2,3}$' then
    return 'invalid';
  end if;
  if not public.aa_is_absent(j, 'rolled') and jsonb_typeof(j -> 'rolled') <> 'boolean' then
    return 'invalid';
  end if;
  if not public.aa_is_absent(j, 'seated') and jsonb_typeof(j -> 'seated') <> 'boolean' then
    return 'invalid';
  end if;
  if not public.aa_is_absent(j, 'group')
     and (jsonb_typeof(j -> 'group') <> 'string' or (j ->> 'group') not in ('A', 'B')) then
    return 'invalid';
  end if;
  if not public.aa_is_absent(j, 'answers') then
    if not public.aa_keys_ok(j -> 'answers', array['unwell', 'meds', 'fell']) then
      return 'invalid';
    end if;
    if exists (
      select 1 from jsonb_each(j -> 'answers') a
      where jsonb_typeof(a.value) <> 'string' or (a.value #>> '{}') not in ('yes', 'no')
    ) then
      return 'invalid';
    end if;
  end if;
  if not public.aa_is_absent(j, 'reasons') then
    if jsonb_typeof(j -> 'reasons') <> 'array' or jsonb_array_length(j -> 'reasons') > 3 then
      return 'invalid';
    end if;
    if exists (
      select 1 from jsonb_array_elements(j -> 'reasons') e
      where jsonb_typeof(e) <> 'string' or (e #>> '{}') not in ('unwell', 'meds', 'fell')
    ) then
      return 'invalid';
    end if;
    if (select count(distinct e) from jsonb_array_elements(j -> 'reasons') e)
       <> jsonb_array_length(j -> 'reasons') then
      return 'invalid';
    end if;
  end if;
  return null;
end
$$;

create function public.aa_check_consent(j jsonb, p_started timestamptz)
returns text
language plpgsql
stable
set search_path = ''
as $$
begin
  if not public.aa_keys_ok(j, array['code', 'type', 'granted', 'version', 'method', 'at']) then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'code') is distinct from 'string' or (j ->> 'code') !~ '^P[0-9]{2,3}$' then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'type') is distinct from 'string'
     or (j ->> 'type') not in ('measure', 'portrait', 'camera', 'research') then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'granted') is distinct from 'boolean' then
    return 'invalid';
  end if;
  if not public.aa_is_text(j, 'version', 1, 20) then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'method') is distinct from 'string' or (j ->> 'method') not in ('paper', 'esign') then
    return 'invalid';
  end if;
  if not public.aa_time_ok(public.aa_ts(j, 'at'), p_started) then
    return 'bad_time';
  end if;
  return null;
end
$$;

create function public.aa_check_measurement(j jsonb, p_started timestamptz)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_item text;
  v_side text;
  v_k text;
  v_has boolean := false;
begin
  if not public.aa_keys_ok(j, array[
    'mid', 'code', 'item', 'side', 'human1', 'human2', 'camera', 'camera2', 'camera_valid',
    'camera_note', 'cam_fps', 'cam_detect', 'assisted', 'note', 'at'
  ]) then
    return 'invalid';
  end if;
  if public.aa_uuid(j, 'mid') is null then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'code') is distinct from 'string' or (j ->> 'code') !~ '^P[0-9]{2,3}$' then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'item') is distinct from 'string' or (j ->> 'item') not in ('chair30', 'sls') then
    return 'invalid';
  end if;
  v_item := j ->> 'item';
  if not public.aa_is_absent(j, 'side') and jsonb_typeof(j -> 'side') <> 'string' then
    return 'invalid';
  end if;
  v_side := coalesce(j ->> 'side', '');
  if (v_item = 'chair30' and v_side <> '') or (v_item = 'sls' and v_side not in ('L', 'R')) then
    return 'invalid';
  end if;
  -- 數值欄位：缺、null 或數字；不是數字就拒絕。
  foreach v_k in array array['human1', 'human2', 'camera', 'camera2'] loop
    if not public.aa_is_absent(j, v_k) then
      if jsonb_typeof(j -> v_k) <> 'number' then
        return 'invalid';
      end if;
      v_has := true;
    end if;
  end loop;
  if not v_has then
    return 'empty';
  end if;
  foreach v_k in array array['human1', 'human2', 'camera', 'camera2'] loop
    if not public.aa_meas_val_ok(v_item, public.aa_num(j, v_k)) then
      return 'out_of_range';
    end if;
  end loop;
  foreach v_k in array array['cam_fps', 'cam_detect'] loop
    if not public.aa_is_absent(j, v_k) and jsonb_typeof(j -> v_k) <> 'number' then
      return 'invalid';
    end if;
  end loop;
  if public.aa_num(j, 'cam_fps') is not null and public.aa_num(j, 'cam_fps') not between 0 and 120 then
    return 'out_of_range';
  end if;
  if public.aa_num(j, 'cam_detect') is not null and public.aa_num(j, 'cam_detect') not between 0 and 1 then
    return 'out_of_range';
  end if;
  if not public.aa_is_absent(j, 'camera_valid') then
    if jsonb_typeof(j -> 'camera_valid') <> 'boolean' then
      return 'invalid';
    end if;
    if public.aa_is_absent(j, 'camera') and public.aa_is_absent(j, 'camera2') then
      return 'invalid';
    end if;
  end if;
  if not public.aa_is_absent(j, 'assisted') and jsonb_typeof(j -> 'assisted') <> 'boolean' then
    return 'invalid';
  end if;
  foreach v_k in array array['camera_note', 'note'] loop
    if not public.aa_is_absent(j, v_k) and not public.aa_is_text(j, v_k, 0, 200) then
      return 'invalid';
    end if;
  end loop;
  if not public.aa_time_ok(public.aa_ts(j, 'at'), p_started) then
    return 'bad_time';
  end if;
  return null;
end
$$;

create function public.aa_check_event(j jsonb, p_started timestamptz)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_type text;
  v_idx numeric;
begin
  if not public.aa_keys_ok(j, array['eid', 'type', 'code', 'condition_index', 'text', 'at']) then
    return 'invalid';
  end if;
  if public.aa_uuid(j, 'eid') is null then
    return 'invalid';
  end if;
  if jsonb_typeof(j -> 'type') is distinct from 'string' or (j ->> 'type') not in ('stop', 'note') then
    return 'invalid';
  end if;
  v_type := j ->> 'type';
  if not public.aa_is_absent(j, 'code') then
    if jsonb_typeof(j -> 'code') <> 'string'
       or ((j ->> 'code') <> '' and (j ->> 'code') !~ '^P[0-9]{2,3}$') then
      return 'invalid';
    end if;
  end if;
  if not public.aa_is_absent(j, 'text') and not public.aa_is_text(j, 'text', 0, 200) then
    return 'invalid';
  end if;
  if v_type = 'stop' then
    v_idx := public.aa_num(j, 'condition_index');
    if v_idx is null or v_idx <> trunc(v_idx) or v_idx not between 0 and 5 then
      return 'invalid';
    end if;
  else
    if not public.aa_is_absent(j, 'condition_index') then
      return 'invalid';
    end if;
    if not public.aa_is_text(j, 'text', 1, 200) then
      return 'invalid';
    end if;
  end if;
  if not public.aa_time_ok(public.aa_ts(j, 'at'), p_started) then
    return 'bad_time';
  end if;
  return null;
end
$$;

-- ── RPC 本體（aa__*：不開放給 App，由下面的外層函式呼叫並寫稽核）────────────

-- 1 aa_me
create function public.aa__me(p_role text)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('ok', true, 'active', p_role is not null, 'role', p_role)
$$;

-- 2 aa_invite_redeem
-- 失敗一律回 invalid（不分碼不存在、停用、過期、用完），並記一筆失敗；
-- 每人 15 分鐘內 5 次、24 小時內 20 次失敗就鎖；全站 1 小時內 300 次失敗全部暫停（擋開分身亂猜）。
create function public.aa__invite_redeem(p_me uuid, p_role text, p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_inv public.aa_invites;
  v_row public.aa_roles;
begin
  select * into v_row from public.aa_roles r where r.user_id = p_me;
  if found then
    if v_row.revoked_at is not null then
      return public.aa_err('forbidden');
    end if;
    -- 已啟用：冪等，不再消耗邀請碼。
    return jsonb_build_object('ok', true, 'role', p_role);
  end if;
  if (select count(*) from public.aa_invite_attempts a
        where a.user_id = p_me and not a.ok and a.at > now() - interval '15 minutes') >= 5
     or (select count(*) from public.aa_invite_attempts a
        where a.user_id = p_me and not a.ok and a.at > now() - interval '24 hours') >= 20
     or (select count(*) from public.aa_invite_attempts a
        where not a.ok and a.at > now() - interval '1 hour') >= 300 then
    return public.aa_err('rate_limited');
  end if;
  if p_code is null or p_code !~ '^[1-9][0-9]{7}$' then
    insert into public.aa_invite_attempts (user_id, ok) values (p_me, false);
    return public.aa_err('invalid');
  end if;
  select * into v_inv from public.aa_invites i where i.code = p_code for update;
  if not found or v_inv.disabled_at is not null or v_inv.expires_at <= now()
     or v_inv.used_count >= v_inv.max_uses then
    insert into public.aa_invite_attempts (user_id, ok) values (p_me, false);
    return public.aa_err('invalid');
  end if;
  update public.aa_invites set used_count = used_count + 1 where id = v_inv.id;
  insert into public.aa_roles (user_id, role, invite_id) values (p_me, v_inv.role, v_inv.id);
  insert into public.aa_invite_attempts (user_id, ok) values (p_me, true);
  return jsonb_build_object('ok', true, 'role', v_inv.role);
end
$$;

-- 3 aa_session_upsert
create function public.aa__session_upsert(p_me uuid, p_session jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_started timestamptz;
  v_planned numeric;
  v_s public.aa_sessions;
  v_aed text;
begin
  if p_session is null or jsonb_typeof(p_session) <> 'object' then
    return public.aa_err('invalid');
  end if;
  if octet_length(p_session::text) > 4096 then
    return public.aa_err('too_large');
  end if;
  if not public.aa_keys_ok(p_session, array[
    'id', 'site', 'series', 'type', 'planned_count', 'aed_location', 'started_at'
  ]) then
    return public.aa_err('invalid');
  end if;
  v_id := public.aa_uuid(p_session, 'id');
  v_started := public.aa_ts(p_session, 'started_at');
  v_planned := public.aa_num(p_session, 'planned_count');
  if v_id is null or v_started is null
     or not public.aa_is_text(p_session, 'site', 1, 60)
     or jsonb_typeof(p_session -> 'series') is distinct from 'string'
     or (p_session ->> 'series') not in ('steady', 'hands', 'strength')
     or jsonb_typeof(p_session -> 'type') is distinct from 'string'
     or (p_session ->> 'type') not in ('normal', 'measure')
     or v_planned is null or v_planned <> trunc(v_planned) or v_planned not between 0 and 40
     or (not public.aa_is_absent(p_session, 'aed_location')
         and not public.aa_is_text(p_session, 'aed_location', 0, 60)) then
    return public.aa_err('invalid');
  end if;
  -- 開場時間：不能晚於現在超過 1 天，也不能早於 60 天前。
  if v_started > now() + interval '1 day' or v_started < now() - interval '60 days' then
    return public.aa_err('invalid');
  end if;
  v_aed := coalesce(p_session ->> 'aed_location', '');

  select * into v_s from public.aa_sessions s where s.id = v_id for update;
  if found then
    if v_s.owner_id <> p_me then
      return public.aa_err('forbidden');
    end if;
    if public.aa_session_closed(v_s) then
      return public.aa_err('closed');
    end if;
    -- 系列、類型、開場時間建立後不能改（量測的時間範圍靠開場時間）。
    if v_s.series <> (p_session ->> 'series') or v_s.type <> (p_session ->> 'type')
       or v_s.started_at <> v_started then
      return public.aa_err('invalid');
    end if;
    update public.aa_sessions
    set site = p_session ->> 'site', planned_count = v_planned::integer,
        aed_location = v_aed, updated_at = now()
    where id = v_id;
    return jsonb_build_object('ok', true);
  end if;

  -- 新場次：每人同時開著的 3 場（3 天內開的、還沒結案）、24 小時內新開 10 場、累計 500 場。
  if (select count(*) from public.aa_sessions s
        where s.owner_id = p_me and s.closed_at is null and s.started_at > now() - interval '3 days') >= 3
     or (select count(*) from public.aa_sessions s
        where s.owner_id = p_me and s.created_at > now() - interval '24 hours') >= 10
     or (select count(*) from public.aa_sessions s where s.owner_id = p_me) >= 500 then
    return public.aa_err('too_large');
  end if;
  begin
    insert into public.aa_sessions (id, owner_id, site, series, type, planned_count, aed_location, started_at)
    values (v_id, p_me, p_session ->> 'site', p_session ->> 'series', p_session ->> 'type',
            v_planned::integer, v_aed, v_started);
    insert into public.aa_session_members (session_id, user_id, role) values (v_id, p_me, 'owner');
  exception when unique_violation then
    -- 同時有別人搶先用了同一個 id。
    return public.aa_err('forbidden');
  end;
  return jsonb_build_object('ok', true);
end
$$;

-- 4 aa_session_close：第一次結案時間為準，重送不改；7 天內仍可補寫其他資料。
create function public.aa__session_close(p_me uuid, p_id uuid, p_closed_at timestamptz)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
begin
  v_s := public.aa_session_for(p_me, p_id, true, true);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  if v_s.closed_server_at is not null then
    if public.aa_session_closed(v_s) then
      return public.aa_err('closed');
    end if;
    return jsonb_build_object('ok', true);
  end if;
  if p_closed_at is null or p_closed_at < v_s.started_at or p_closed_at > now() + interval '1 day' then
    return public.aa_err('invalid');
  end if;
  update public.aa_sessions
  set closed_at = p_closed_at, closed_server_at = now(), updated_at = now()
  where id = v_s.id;
  return jsonb_build_object('ok', true);
end
$$;

-- 5 aa_participants_upsert（整批全過才寫，不然整批不寫）
create function public.aa__participants_upsert(p_me uuid, p_sid uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
  v_n integer;
  v_i integer;
  v_row jsonb;
  v_err text;
  v_have integer;
  v_new integer;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return public.aa_err('invalid');
  end if;
  if octet_length(p_rows::text) > 102400 or jsonb_array_length(p_rows) > 60 then
    return public.aa_err('too_large');
  end if;
  v_s := public.aa_session_for(p_me, p_sid, false, true);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  if public.aa_session_closed(v_s) then
    return public.aa_err('closed');
  end if;
  v_n := jsonb_array_length(p_rows);
  for v_i in 0 .. v_n - 1 loop
    v_row := p_rows -> v_i;
    v_err := public.aa_check_participant(v_row);
    if v_err is null and exists (
      select 1 from public.aa_participants p
      where p.session_id = v_s.id and p.code = v_row ->> 'code' and p.erased_at is not null
    ) then
      v_err := 'invalid';
    end if;
    if v_err is not null then
      return public.aa_err(v_err);
    end if;
  end loop;
  select count(*) into v_have from public.aa_participants p where p.session_id = v_s.id;
  select count(*) into v_new
  from (select distinct e ->> 'code' as c from jsonb_array_elements(p_rows) e) x
  where not exists (
    select 1 from public.aa_participants p where p.session_id = v_s.id and p.code = x.c
  );
  if v_have + v_new > 60 then
    return public.aa_err('too_large');
  end if;
  begin
    for v_i in 0 .. v_n - 1 loop
      v_row := p_rows -> v_i;
      insert into public.aa_participants as p (session_id, code, rolled, answers, seated, reasons, grp)
      values (
        v_s.id, v_row ->> 'code',
        coalesce((v_row ->> 'rolled')::boolean, false),
        nullif(v_row -> 'answers', 'null'::jsonb),
        coalesce((v_row ->> 'seated')::boolean, false),
        array(select jsonb_array_elements_text(v_row -> 'reasons')),
        v_row ->> 'group'
      )
      on conflict (session_id, code) do update
      set rolled = excluded.rolled, answers = excluded.answers, seated = excluded.seated,
          reasons = excluded.reasons, grp = excluded.grp, updated_at = now();
    end loop;
  exception when others then
    return public.aa_err('invalid');
  end;
  update public.aa_sessions set updated_at = now() where id = v_s.id;
  return jsonb_build_object('ok', true, 'n', v_n);
end
$$;

-- 6 aa_consents_upsert：現行表最新一筆（at 較新的才蓋過去，舊的重送蓋不掉撤回）＋歷史表 append-only。
create function public.aa__consents_upsert(p_me uuid, p_sid uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
  v_n integer;
  v_i integer;
  v_row jsonb;
  v_err text;
  v_have integer;
  v_new integer;
  v_cnt integer;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return public.aa_err('invalid');
  end if;
  if octet_length(p_rows::text) > 102400 or jsonb_array_length(p_rows) > 240 then
    return public.aa_err('too_large');
  end if;
  v_s := public.aa_session_for(p_me, p_sid, false, true);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  if public.aa_session_closed(v_s) then
    return public.aa_err('closed');
  end if;
  v_n := jsonb_array_length(p_rows);
  for v_i in 0 .. v_n - 1 loop
    v_row := p_rows -> v_i;
    v_err := public.aa_check_consent(v_row, v_s.started_at);
    if v_err is null and not exists (
      select 1 from public.aa_participants p
      where p.session_id = v_s.id and p.code = v_row ->> 'code' and p.erased_at is null
    ) then
      v_err := 'invalid';
    end if;
    if v_err is not null then
      return public.aa_err(v_err);
    end if;
  end loop;
  select count(*) into v_have from public.aa_consents c where c.session_id = v_s.id;
  select count(*) into v_new
  from (select distinct e ->> 'code' as c, e ->> 'type' as t from jsonb_array_elements(p_rows) e) x
  where not exists (
    select 1 from public.aa_consents c
    where c.session_id = v_s.id and c.code = x.c and c.type = x.t
  );
  if v_have + v_new > 240 then
    return public.aa_err('too_large');
  end if;
  begin
    for v_i in 0 .. v_n - 1 loop
      v_row := p_rows -> v_i;
      insert into public.aa_consents as c (session_id, code, type, granted, version, method, at)
      values (v_s.id, v_row ->> 'code', v_row ->> 'type', (v_row ->> 'granted')::boolean,
              v_row ->> 'version', v_row ->> 'method', public.aa_ts(v_row, 'at'))
      on conflict (session_id, code, type) do update
      set granted = excluded.granted, version = excluded.version, method = excluded.method,
          at = excluded.at, updated_at = now()
      where excluded.at > c.at;
      get diagnostics v_cnt = row_count;
      if v_cnt > 0 then
        insert into public.aa_consent_history
          (session_id, code, type, granted, version, method, at, recorded_by)
        values (v_s.id, v_row ->> 'code', v_row ->> 'type', (v_row ->> 'granted')::boolean,
                v_row ->> 'version', v_row ->> 'method', public.aa_ts(v_row, 'at'), p_me);
      end if;
    end loop;
  exception when others then
    return public.aa_err('invalid');
  end;
  update public.aa_sessions set updated_at = now() where id = v_s.id;
  return jsonb_build_object('ok', true, 'n', v_n);
end
$$;

-- 7 aa_measurements_upsert：逐列驗，壞的列進 rejected，好的列照收。
create function public.aa__measurements_upsert(p_me uuid, p_sid uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
  v_n integer;
  v_i integer;
  v_row jsonb;
  v_err text;
  v_mid uuid;
  v_total integer;
  v_added integer := 0;
  v_acc integer := 0;
  v_rej jsonb := '[]'::jsonb;
  v_ins boolean;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return public.aa_err('invalid');
  end if;
  if octet_length(p_rows::text) > 102400 or jsonb_array_length(p_rows) > 100 then
    return public.aa_err('too_large');
  end if;
  v_s := public.aa_session_for(p_me, p_sid, false, true);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  if public.aa_session_closed(v_s) then
    return public.aa_err('closed');
  end if;
  v_n := jsonb_array_length(p_rows);
  select count(*) into v_total from public.aa_measurements m where m.session_id = v_s.id;
  for v_i in 0 .. v_n - 1 loop
    v_row := p_rows -> v_i;
    v_mid := case when jsonb_typeof(v_row) = 'object' then public.aa_uuid(v_row, 'mid') end;
    v_err := public.aa_check_measurement(v_row, v_s.started_at);
    -- 該編號要有 measure 的 granted = true（現行表）而且沒被刪除，才收量測。
    if v_err is null and not exists (
      select 1
      from public.aa_consents c
      join public.aa_participants p on p.session_id = c.session_id and p.code = c.code
      where c.session_id = v_s.id and c.code = v_row ->> 'code'
        and c.type = 'measure' and c.granted and p.erased_at is null
    ) then
      v_err := 'no_consent';
    end if;
    if v_err is null
       and not exists (select 1 from public.aa_measurements m where m.session_id = v_s.id and m.mid = v_mid)
       and v_total + v_added >= 500 then
      v_err := 'too_large';
    end if;
    if v_err is null then
      begin
        v_ins := null;
        insert into public.aa_measurements as m (
          session_id, mid, code, item, side, human1, human2, camera, camera2, camera_valid,
          camera_note, cam_fps, cam_detect, assisted, note, at
        ) values (
          v_s.id, v_mid, v_row ->> 'code', v_row ->> 'item', coalesce(v_row ->> 'side', ''),
          public.aa_num(v_row, 'human1'), public.aa_num(v_row, 'human2'),
          public.aa_num(v_row, 'camera'), public.aa_num(v_row, 'camera2'),
          (v_row ->> 'camera_valid')::boolean,
          coalesce(v_row ->> 'camera_note', ''),
          public.aa_num(v_row, 'cam_fps'), public.aa_num(v_row, 'cam_detect'),
          coalesce((v_row ->> 'assisted')::boolean, false),
          coalesce(v_row ->> 'note', ''), public.aa_ts(v_row, 'at')
        )
        on conflict (session_id, mid) do update
        set human1 = excluded.human1, human2 = excluded.human2, camera = excluded.camera,
            camera2 = excluded.camera2, camera_valid = excluded.camera_valid,
            camera_note = excluded.camera_note, cam_fps = excluded.cam_fps,
            cam_detect = excluded.cam_detect, assisted = excluded.assisted,
            note = excluded.note, at = excluded.at, updated_at = now()
        -- 編號、項目、左右腳建立後不能改。
        where m.code = excluded.code and m.item = excluded.item and m.side = excluded.side
        returning (m.xmax = 0) into v_ins;
        if v_ins is null then
          v_err := 'immutable';
        elsif v_ins then
          v_added := v_added + 1;
        end if;
      exception when others then
        v_err := 'invalid';
      end;
    end if;
    if v_err is null then
      v_acc := v_acc + 1;
    else
      v_rej := v_rej || jsonb_build_array(jsonb_build_object('mid', v_mid, 'reason', v_err));
    end if;
  end loop;
  update public.aa_sessions set updated_at = now() where id = v_s.id;
  return jsonb_build_object('ok', true, 'accepted', v_acc, 'rejected', v_rej);
end
$$;

-- 8 aa_events_upsert（整批全過才寫）
create function public.aa__events_upsert(p_me uuid, p_sid uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
  v_n integer;
  v_i integer;
  v_row jsonb;
  v_err text;
  v_have integer;
  v_new integer;
  v_cnt integer;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return public.aa_err('invalid');
  end if;
  if octet_length(p_rows::text) > 102400 or jsonb_array_length(p_rows) > 100 then
    return public.aa_err('too_large');
  end if;
  v_s := public.aa_session_for(p_me, p_sid, false, true);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  if public.aa_session_closed(v_s) then
    return public.aa_err('closed');
  end if;
  v_n := jsonb_array_length(p_rows);
  for v_i in 0 .. v_n - 1 loop
    v_row := p_rows -> v_i;
    v_err := public.aa_check_event(v_row, v_s.started_at);
    -- 有編號就要是這場報到過、沒被刪除的人。
    if v_err is null and coalesce(v_row ->> 'code', '') <> '' and not exists (
      select 1 from public.aa_participants p
      where p.session_id = v_s.id and p.code = v_row ->> 'code' and p.erased_at is null
    ) then
      v_err := 'invalid';
    end if;
    if v_err is not null then
      return public.aa_err(v_err);
    end if;
  end loop;
  select count(*) into v_have from public.aa_events e where e.session_id = v_s.id;
  select count(*) into v_new
  from (select distinct public.aa_uuid(e, 'eid') as id from jsonb_array_elements(p_rows) e) x
  where not exists (select 1 from public.aa_events e where e.session_id = v_s.id and e.eid = x.id);
  if v_have + v_new > 200 then
    return public.aa_err('too_large');
  end if;
  begin
    for v_i in 0 .. v_n - 1 loop
      v_row := p_rows -> v_i;
      insert into public.aa_events as e (session_id, eid, type, code, condition_index, text, at)
      values (
        v_s.id, public.aa_uuid(v_row, 'eid'), v_row ->> 'type', coalesce(v_row ->> 'code', ''),
        public.aa_num(v_row, 'condition_index')::integer, coalesce(v_row ->> 'text', ''),
        public.aa_ts(v_row, 'at')
      )
      on conflict (session_id, eid) do update
      set text = excluded.text, at = excluded.at, updated_at = now()
      where e.type = excluded.type and e.code = excluded.code
        and e.condition_index is not distinct from excluded.condition_index;
      get diagnostics v_cnt = row_count;
      if v_cnt = 0 then
        raise exception 'immutable';
      end if;
    end loop;
  exception when others then
    return public.aa_err('invalid');
  end;
  update public.aa_sessions set updated_at = now() where id = v_s.id;
  return jsonb_build_object('ok', true, 'n', v_n);
end
$$;

-- 9 aa_session_pull：成員才給（第一版只有 owner 一個成員）。
create function public.aa__session_pull(p_me uuid, p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
begin
  v_s := public.aa_session_for(p_me, p_id, false, false);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  return jsonb_build_object(
    'ok', true,
    'session', jsonb_build_object(
      'id', v_s.id, 'site', v_s.site, 'series', v_s.series, 'type', v_s.type,
      'planned_count', v_s.planned_count, 'aed_location', v_s.aed_location,
      'started_at', v_s.started_at, 'closed_at', v_s.closed_at
    ),
    'participants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', p.code, 'rolled', p.rolled, 'answers', p.answers, 'seated', p.seated,
        'reasons', to_jsonb(p.reasons), 'group', p.grp, 'erased', p.erased_at is not null
      ) order by p.code)
      from public.aa_participants p where p.session_id = v_s.id
    ), '[]'::jsonb),
    'consents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', c.code, 'type', c.type, 'granted', c.granted, 'version', c.version,
        'method', c.method, 'at', c.at
      ) order by c.code, c.type)
      from public.aa_consents c where c.session_id = v_s.id
    ), '[]'::jsonb),
    'measurements', coalesce((
      select jsonb_agg(to_jsonb(m) - 'session_id' - 'created_at' - 'updated_at' order by m.at, m.mid)
      from public.aa_measurements m where m.session_id = v_s.id
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(to_jsonb(e) - 'session_id' - 'created_at' - 'updated_at' order by e.at, e.eid)
      from public.aa_events e where e.session_id = v_s.id
    ), '[]'::jsonb)
  );
end
$$;

-- 10 aa_session_list：只列自己是成員的場次。回 {ok, sessions:[...]}（見說明：跟 08 的純陣列不同）。
create function public.aa__session_list(p_me uuid, p_limit integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  return jsonb_build_object('ok', true, 'sessions', coalesce((
    select jsonb_agg(to_jsonb(x) order by x.started_at desc)
    from (
      select s.id, s.site, s.series, s.type, s.started_at, s.closed_at,
        jsonb_build_object(
          'participants', (select count(*) from public.aa_participants p where p.session_id = s.id),
          'consents', (select count(*) from public.aa_consents c where c.session_id = s.id),
          'measurements', (select count(*) from public.aa_measurements m where m.session_id = s.id),
          'events', (select count(*) from public.aa_events e where e.session_id = s.id)
        ) as counts
      from public.aa_sessions s
      join public.aa_session_members mem on mem.session_id = s.id and mem.user_id = p_me
      order by s.started_at desc
      limit v_lim
    ) x
  ), '[]'::jsonb));
end
$$;

-- 11 aa_session_delete：只有 owner；整場連帶刪除（成員、參加者、同意與歷史、量測、事件）。
-- 結案超過 7 天也可以刪（刪除是當事人與據點的權利，不受補寫期限制）。稽核紀錄留著。
create function public.aa__session_delete(p_me uuid, p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
begin
  v_s := public.aa_session_for(p_me, p_id, true, true);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  delete from public.aa_sessions where id = v_s.id;
  return jsonb_build_object('ok', true);
end
$$;

-- 12 aa_participant_erase：刪該編號的量測、事件、同意（含歷史），並清掉報到資料（健康問答）。
-- 參加者那一列留成空殼（erased_at），之後離線佇列重送的同編號資料一律被擋。只有 owner。
create function public.aa__participant_erase(p_me uuid, p_sid uuid, p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_s public.aa_sessions;
begin
  if p_code is null or p_code !~ '^P[0-9]{2,3}$' then
    return public.aa_err('invalid');
  end if;
  v_s := public.aa_session_for(p_me, p_sid, true, true);
  if v_s.id is null then
    return public.aa_err('forbidden');
  end if;
  if not exists (select 1 from public.aa_participants p where p.session_id = v_s.id and p.code = p_code) then
    return public.aa_err('invalid');
  end if;
  delete from public.aa_measurements where session_id = v_s.id and code = p_code;
  delete from public.aa_events where session_id = v_s.id and code = p_code;
  delete from public.aa_consent_history where session_id = v_s.id and code = p_code;
  delete from public.aa_consents where session_id = v_s.id and code = p_code;
  update public.aa_participants
  set answers = null, reasons = '{}', seated = false, rolled = false, grp = null,
      erased_at = coalesce(erased_at, now()), updated_at = now()
  where session_id = v_s.id and code = p_code;
  return jsonb_build_object('ok', true);
end
$$;

-- ── 開放給 App 的 12 支 RPC（外層：門檻、本體、稽核）─────────────────────

create function public.aa_me()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, false);
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  return public.aa__me(g ->> 'role');
end
$$;

create function public.aa_invite_redeem(p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(2, false);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__invite_redeem((g ->> 'uid')::uuid, g ->> 'role', p_code);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_invite_redeem', null, r);
  return r;
end
$$;

create function public.aa_session_upsert(p_session jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__session_upsert((g ->> 'uid')::uuid, p_session);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_session_upsert',
    case when jsonb_typeof(p_session) = 'object' then public.aa_uuid(p_session, 'id') end, r);
  return r;
end
$$;

create function public.aa_session_close(p_id uuid, p_closed_at timestamptz)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__session_close((g ->> 'uid')::uuid, p_id, p_closed_at);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_session_close', p_id, r);
  return r;
end
$$;

create function public.aa_participants_upsert(p_session_id uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__participants_upsert((g ->> 'uid')::uuid, p_session_id, p_rows);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_participants_upsert', p_session_id, r);
  return r;
end
$$;

create function public.aa_consents_upsert(p_session_id uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__consents_upsert((g ->> 'uid')::uuid, p_session_id, p_rows);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_consents_upsert', p_session_id, r);
  return r;
end
$$;

create function public.aa_measurements_upsert(p_session_id uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__measurements_upsert((g ->> 'uid')::uuid, p_session_id, p_rows);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_measurements_upsert', p_session_id, r);
  return r;
end
$$;

create function public.aa_events_upsert(p_session_id uuid, p_rows jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__events_upsert((g ->> 'uid')::uuid, p_session_id, p_rows);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_events_upsert', p_session_id, r);
  return r;
end
$$;

create function public.aa_session_pull(p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(3, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__session_pull((g ->> 'uid')::uuid, p_id);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_session_pull', p_id, r);
  return r;
end
$$;

create function public.aa_session_list(p_limit integer default 20)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(2, true);
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  return public.aa__session_list((g ->> 'uid')::uuid, p_limit);
end
$$;

create function public.aa_session_delete(p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__session_delete((g ->> 'uid')::uuid, p_id);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_session_delete', p_id, r);
  return r;
end
$$;

create function public.aa_participant_erase(p_session_id uuid, p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  g jsonb := public.aa_gate(1, true);
  r jsonb;
begin
  if g ? 'reason' then
    return public.aa_err(g ->> 'reason');
  end if;
  r := public.aa__participant_erase((g ->> 'uid')::uuid, p_session_id, p_code);
  perform public.aa_log((g ->> 'uid')::uuid, 'aa_participant_erase', p_session_id, r);
  return r;
end
$$;

-- ── 公司管理員專用（service_role；不經 App 與 H5）────────────────────────

-- 8 位數字、不以 0 開頭；跟好友碼同格式，但只對 aa_invites 查重。
create function public.aa_new_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  loop
    v_code := (
      ('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint
        % 90000000 + 10000000
    )::text;
    exit when not exists (select 1 from public.aa_invites where code = v_code);
  end loop;
  return v_code;
end
$$;

create function public.aa_admin_invite_create(
  p_role text, p_label text default null, p_max_uses integer default 1, p_days integer default 14
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_inv public.aa_invites;
begin
  if p_role not in ('instructor', 'assistant') or p_days not between 1 and 90 then
    raise exception 'invalid';
  end if;
  insert into public.aa_invites (code, role, label, max_uses, expires_at, created_by)
  values (public.aa_new_code(), p_role, p_label, p_max_uses, now() + make_interval(days => p_days), 'admin')
  returning * into v_inv;
  return jsonb_build_object('id', v_inv.id, 'code', v_inv.code, 'role', v_inv.role,
    'expires_at', v_inv.expires_at);
end
$$;

create function public.aa_admin_invite_disable(p_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  update public.aa_invites set disabled_at = coalesce(disabled_at, now()) where id = p_id
$$;

-- 重發：停用舊碼（已啟用的人不受影響），用同樣的角色、備註、人數、效期發一組新碼。
create function public.aa_admin_invite_reissue(p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_old public.aa_invites;
begin
  select * into v_old from public.aa_invites where id = p_id for update;
  if not found then
    raise exception 'not_found';
  end if;
  update public.aa_invites set disabled_at = coalesce(disabled_at, now()) where id = p_id;
  return public.aa_admin_invite_create(
    v_old.role, v_old.label, v_old.max_uses,
    greatest(1, least(90, ceil(extract(epoch from (v_old.expires_at - v_old.created_at)) / 86400)::integer))
  );
end
$$;

-- 停用一個人（p_revoked = true，他不能再用邀請碼自己啟用回來）；false 則直接給角色並解除停用。
create function public.aa_admin_role_set(p_user uuid, p_role text, p_revoked boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if p_revoked then
    update public.aa_roles set revoked_at = coalesce(revoked_at, now()) where user_id = p_user;
  else
    insert into public.aa_roles (user_id, role) values (p_user, p_role)
    on conflict (user_id) do update set role = excluded.role, revoked_at = null;
  end if;
end
$$;

-- 保存期限到了的場次整場刪除。還沒有排程呼叫它；要用時加 pg_cron。
create function public.aa_admin_purge_expired()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  delete from public.aa_sessions where retention_until is not null and retention_until < now();
  get diagnostics v_n = row_count;
  return v_n;
end
$$;

-- ── 權限：預設全關，只開 12 支 RPC 給登入的人，管理函式只開給 service_role ────

do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.proname like 'aa\_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    if f.proname in (
      'aa_me', 'aa_invite_redeem', 'aa_session_upsert', 'aa_session_close',
      'aa_participants_upsert', 'aa_consents_upsert', 'aa_measurements_upsert',
      'aa_events_upsert', 'aa_session_pull', 'aa_session_list', 'aa_session_delete',
      'aa_participant_erase'
    ) then
      execute format('grant execute on function %s to authenticated', f.sig);
    elsif f.proname like 'aa\_admin\_%' then
      execute format('grant execute on function %s to service_role', f.sig);
    end if;
  end loop;
end
$$;

commit;
