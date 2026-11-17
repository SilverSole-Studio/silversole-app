-- supabase/migrations/20261117120000_aa_room.sql
--
-- 銀足樂齡：課程現場「手機自己報到」的臨時中繼（房間）。
--
-- 狀態：草稿，未套用到任何 Supabase 專案。套用前先問 user 與技術長。
-- 依賴：20261113120000_active_aging.sql 的 aa_err()、aa_keys_ok()、aa_uuid()（要先套用那支）。
--   不依賴 20261116180000_aa_consent_qr.sql（那支還沒套用）；限流桶另開 aa_room_buckets，函式改名 aa_room_ip()、aa_room_take()。
-- 流程：指導員平板開房（產生 host 金鑰，伺服器只存 sha256；產生房間代碼放進 QR）
--   → 長輩用自己的手機（一般瀏覽器、沒登入＝anon）掃 QR，答三題健康問題、按同意
--   → 伺服器從空座位裡隨機配一個，回給手機
--   → 平板每 3 秒輪詢拿報到資料，存在平板本機（之後平板自己走原本的同步）→ 平板關房，房間與報到紀錄刪除。
--   平板沒有登入通道（App 橋接有白名單、不改 App），所以 6 支函式全部 anon 可呼叫；
--   平板的身分只有開房時自己產生的 host 金鑰（32 位小寫十六進位）。
--
-- 原則（RPC 濫用自查清單：一律假設對方直接打 API、並發、開分身）：
--   - 三張表全部開 RLS、沒有任何政策、anon 與 authenticated 全部 revoke；只走 security definer RPC，
--     search_path 固定為空字串，物件一律寫全名。
--   - 伺服器只是暫存：不存姓名、不存簽名、不存任何個資。存的只有座位編號（P01…）、三題 yes/no、四項同意 true/false、
--     關係（選項）。房間 6 小時後過期，隨時可由平板關閉刪除；過期房間在有人開新房時順便清。
--   - 限流：全部先扣網路位址的額度（代碼打錯、格式亂寫也扣，防亂猜）；join 再扣房間整體額度；
--     限流桶是文字 key、沒有外鍵（家屬沒有帳號）。
--   - 大小上限：座位 60、代碼與金鑰長度固定、label 40 字、p_form 文字 2000、poll 最多 100 筆。
--   - 白名單：p_form 與 answers、choices 的 key 與值型別全部白名單，多餘 key 拒絕；座位編號用正規式。
--   - 冪等：同一個房間內的 submit_id 唯一；重送回原本的座位，不會多占一個位子。
--   - 並發：join 先 select ... for update 鎖房間列，挑座位與寫入在同一把鎖裡，所以兩支手機不會配到同一個座位
--     （另有 unique (room_id, seat) 當第二層）。
--   - 不能讀回別人的資料：手機（join）只拿到自己的座位；info 只回座位表與剩餘數，不回任何報到內容；
--     報到內容只有 poll 給得出，而且要 host 金鑰。房間代碼 128 位元亂數、host 金鑰 128 位元亂數，探不出來。
--   - 錯誤回 {ok:false, reason}（不 raise），限流的扣款才不會跟著回滾。
--
-- 回傳慣例：成功 {ok:true, ...}；失敗 {ok:false, reason}。
--   reason 只有：invalid、closed、rate_limited
--   （房間不存在、host 不符、代碼格式錯一律 invalid，不讓人探是哪一種；房間關了、過期、沒空位回 closed）。
--
-- 還沒決定的事（寫在這裡免得忘）：
--   - 過期房間目前只在「有人開新房」時順便清（aa_room_open 內 delete）。沒人開房就不會清，之後可改排程（pg_cron）。
--   - 網路位址取自 PostgREST 的 request.headers（先 cf-connecting-ip、再 x-real-ip、最後 x-forwarded-for 第一段）。
--     套用後要用真的請求確認 Supabase 前面的代理有帶其中一個；都沒有時全部人共用同一個 'unknown' 桶（會互相擋）。
--   - 同一個據點的長輩通常共用同一個 Wi-Fi 對外位址（同一個 IP）：join 的 IP 額度是每分鐘 10 次（桶容量 10、每 6 秒回 1），
--     20 人同時掃會有人先收到 rate_limited，手機端要自動重試。要不要放寬，等實測再定。
--   - info、hold、close 的 IP 額度（見各函式註解）是我抓的，沒有規格給數字。
--   - 全站同時開著的房間數目前沒上限，只有每 IP 每小時 20 次開房的限制。
--   - 過期房間的 poll、hold 回 closed（平板要在 6 小時內收完）；info 對過期房間回 ok 但 open = false。

begin;

-- ── 資料表 ────────────────────────────────────────────────────────────

create table public.aa_rooms (
  id uuid primary key default gen_random_uuid(),
  -- 放進 QR 的亂數代碼（32 位小寫十六進位，由 aa_room_open 產生）。
  code text not null unique check (code ~ '^[0-9a-f]{32}$'),
  -- 平板 host 金鑰的 sha256（64 位小寫十六進位）；金鑰本身不存。
  host_hash text not null check (host_hash ~ '^[0-9a-f]{64}$'),
  -- 全部座位編號，依座位圖順序。
  seats text[] not null check (
    array_ndims(seats) = 1 and cardinality(seats) between 1 and 60
  ),
  cols smallint not null check (cols between 1 and 5),
  label text not null default '' check (char_length(label) <= 40),
  -- 平板手動報到過、不能再配的位子。
  held text[] not null default '{}',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '6 hours',
  closed boolean not null default false
);
create index aa_rooms_expires_idx on public.aa_rooms (expires_at);

create table public.aa_room_entries (
  n bigint generated always as identity primary key,
  room_id uuid not null references public.aa_rooms (id) on delete cascade,
  seat text not null check (seat ~ '^P[0-9]{2,3}$'),
  submit_id uuid not null,
  answers jsonb not null,
  choices jsonb not null,
  relation text not null check (relation in ('', '配偶', '子女', '其他家屬', '法定代理人或輔助人')),
  created_at timestamptz not null default now(),
  unique (room_id, seat),
  unique (room_id, submit_id)
);

-- 限流桶（文字 key，沒有外鍵）：'open:ip:…'、'info:ip:…'、'join:ip:…'、'join:room:…'、'poll:ip:…'、'host:ip:…'。
create table public.aa_room_buckets (
  key text primary key check (char_length(key) <= 100),
  tokens real not null,
  at timestamptz not null default now()
);
create index aa_room_buckets_at_idx on public.aa_room_buckets (at);

alter table public.aa_rooms enable row level security;
alter table public.aa_room_entries enable row level security;
alter table public.aa_room_buckets enable row level security;
revoke all on public.aa_rooms from public, anon, authenticated;
revoke all on public.aa_room_entries from public, anon, authenticated;
revoke all on public.aa_room_buckets from public, anon, authenticated;

-- ── 小工具（內部用，不開放給 App）──────────────────────────────────────────

-- 呼叫端的網路位址（PostgREST 放在 request.headers）。拿不到就是 'unknown'。
create function public.aa_room_ip()
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  h json;
  v text;
begin
  h := current_setting('request.headers', true)::json;
  v := coalesce(
    nullif(btrim(h ->> 'cf-connecting-ip'), ''),
    nullif(btrim(h ->> 'x-real-ip'), ''),
    nullif(btrim(split_part(coalesce(h ->> 'x-forwarded-for', ''), ',', 1)), '')
  );
  return left(coalesce(v, 'unknown'), 60);
exception when others then
  return 'unknown';
end
$$;

-- token bucket：容量 p_cap、每秒回 p_rate，扣 p_cost。列鎖到交易結束，同一個 key 的呼叫排隊。
-- 順手清一天以上沒動的桶（約 2% 的呼叫做一次）。
create function public.aa_room_take(p_key text, p_cap real, p_rate real, p_cost real)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_left real;
begin
  insert into public.aa_room_buckets (key, tokens, at)
  values (p_key, p_cap, now())
  on conflict (key) do nothing;
  update public.aa_room_buckets
  set tokens = least(p_cap, tokens + extract(epoch from (now() - at))::real * p_rate) - p_cost,
      at = now()
  where key = p_key
    and least(p_cap, tokens + extract(epoch from (now() - at))::real * p_rate) >= p_cost
  returning tokens into v_left;
  if random() < 0.02 then
    delete from public.aa_room_buckets where at < now() - interval '1 day';
  end if;
  return v_left is not null;
end
$$;

-- host 金鑰的 sha256（十六進位）。金鑰格式不對回 null。
create function public.aa_room_hash(p_host text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_host is not null and p_host ~ '^[0-9a-f]{32}$'
    then encode(extensions.digest(convert_to(p_host, 'utf8'), 'sha256'), 'hex')
  end
$$;

-- ── 1 開房（平板）─────────────────────────────────────────────────────
-- 每 IP 一小時 20 次：容量 20、每秒回 20/3600。順便刪掉過期的房間（entries 跟著 cascade 刪）。
create function public.aa_room_open(p_host text, p_seats text[], p_cols integer, p_label text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_label text := coalesce(p_label, '');
  v_hash text;
  v_code text;
begin
  if not public.aa_room_take('open:ip:' || public.aa_room_ip(), 20, 20.0 / 3600.0, 1) then
    return public.aa_err('rate_limited');
  end if;
  v_hash := public.aa_room_hash(p_host);
  if v_hash is null
     or p_seats is null
     or array_ndims(p_seats) is distinct from 1
     or cardinality(p_seats) not between 1 and 60
     or exists (select 1 from unnest(p_seats) s where s is null or s !~ '^P[0-9]{2,3}$')
     or (select count(distinct s) from unnest(p_seats) s) <> cardinality(p_seats)
     or p_cols is null or p_cols not between 1 and 5
     or char_length(v_label) > 40 then
    return public.aa_err('invalid');
  end if;

  delete from public.aa_rooms where expires_at < now();

  v_code := encode(extensions.gen_random_bytes(16), 'hex');
  begin
    insert into public.aa_rooms (code, host_hash, seats, cols, label)
    values (v_code, v_hash, p_seats, p_cols::smallint, v_label);
  exception when others then
    return public.aa_err('invalid');
  end;
  return jsonb_build_object('ok', true, 'code', v_code);
end
$$;

-- ── 2 房間資訊（手機掃 QR 後先呼叫，顯示課名與座位圖）──────────────────────
-- 每 IP：容量 30、每 2 秒回 1（比 join 寬，數字是我抓的）。
create function public.aa_room_info(p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_room public.aa_rooms;
  v_left integer;
begin
  if not public.aa_room_take('info:ip:' || public.aa_room_ip(), 80, 1, 1) then
    return public.aa_err('rate_limited');
  end if;
  if p_code is null or p_code !~ '^[0-9a-f]{32}$' then
    return public.aa_err('invalid');
  end if;
  select * into v_room from public.aa_rooms r where r.code = p_code;
  if not found then
    return public.aa_err('invalid');
  end if;
  select count(*) into v_left
  from unnest(v_room.seats) s
  where s <> all (v_room.held)
    and not exists (
      select 1 from public.aa_room_entries e where e.room_id = v_room.id and e.seat = s
    );
  return jsonb_build_object(
    'ok', true,
    'label', v_room.label,
    'cols', v_room.cols,
    'seats', to_jsonb(v_room.seats),
    'left', v_left,
    'open', (not v_room.closed and v_room.expires_at > now() and v_left > 0)
  );
end
$$;

-- ── 3 長輩報到（手機）─────────────────────────────────────────────────
-- p_form：submit_id（UUID 字串）、answers（unwell、meds、fell，值 'yes'／'no'，三個都要有）、
--   choices（measure、camera、portrait、research，值 boolean，四個都要有）、
--   relation（''、配偶、子女、其他家屬、法定代理人或輔助人）。
-- 先扣 IP（每分鐘 10 次：容量 10、每秒回 1/6）、再扣房間（每分鐘 60 次：容量 60、每秒回 1）。
-- 只回 {ok:true, seat}，不回任何別人的資料。
create function public.aa_room_join(p_code text, p_form jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_rid uuid;
  v_room public.aa_rooms;
  v_sub uuid;
  v_seat text;
begin
  if not public.aa_room_take('join:ip:' || public.aa_room_ip(), 60, 1, 1) then
    return public.aa_err('rate_limited');
  end if;
  if p_code is null or p_code !~ '^[0-9a-f]{32}$'
     or p_form is null or jsonb_typeof(p_form) <> 'object' then
    return public.aa_err('invalid');
  end if;
  if char_length(p_form::text) > 2000 then
    return public.aa_err('invalid');
  end if;
  -- 表單白名單與型別：四個 key 都要有、不准多。
  if not public.aa_keys_ok(p_form, array['submit_id', 'answers', 'choices', 'relation'])
     or not (p_form ? 'submit_id' and p_form ? 'answers' and p_form ? 'choices' and p_form ? 'relation') then
    return public.aa_err('invalid');
  end if;
  v_sub := public.aa_uuid(p_form, 'submit_id');
  if v_sub is null then
    return public.aa_err('invalid');
  end if;
  if not public.aa_keys_ok(p_form -> 'answers', array['unwell', 'meds', 'fell'])
     or (select count(*) from jsonb_object_keys(p_form -> 'answers')) <> 3
     or exists (
       select 1 from jsonb_each(p_form -> 'answers') a
       where jsonb_typeof(a.value) <> 'string' or (a.value #>> '{}') not in ('yes', 'no')
     ) then
    return public.aa_err('invalid');
  end if;
  if not public.aa_keys_ok(p_form -> 'choices', array['measure', 'camera', 'portrait', 'research'])
     or (select count(*) from jsonb_object_keys(p_form -> 'choices')) <> 4
     or exists (
       select 1 from jsonb_each(p_form -> 'choices') c
       where jsonb_typeof(c.value) <> 'boolean'
     ) then
    return public.aa_err('invalid');
  end if;
  if jsonb_typeof(p_form -> 'relation') is distinct from 'string'
     or (p_form ->> 'relation') not in ('', '配偶', '子女', '其他家屬', '法定代理人或輔助人') then
    return public.aa_err('invalid');
  end if;

  select r.id into v_rid from public.aa_rooms r where r.code = p_code;
  if not found then
    return public.aa_err('invalid');
  end if;
  if not public.aa_room_take('join:room:' || v_rid::text, 60, 1, 1) then
    return public.aa_err('rate_limited');
  end if;

  -- 鎖房間列：挑座位與寫入在同一把鎖裡。房間可能在上一步到這裡之間被平板刪掉。
  select * into v_room from public.aa_rooms r where r.id = v_rid for update;
  if not found then
    return public.aa_err('closed');
  end if;
  -- 同一份重送：回原本的座位。
  select e.seat into v_seat
  from public.aa_room_entries e
  where e.room_id = v_room.id and e.submit_id = v_sub;
  if found then
    return jsonb_build_object('ok', true, 'seat', v_seat);
  end if;
  if v_room.closed or v_room.expires_at <= now() then
    return public.aa_err('closed');
  end if;
  select s into v_seat
  from unnest(v_room.seats) s
  where s <> all (v_room.held)
    and not exists (
      select 1 from public.aa_room_entries e where e.room_id = v_room.id and e.seat = s
    )
  order by random()
  limit 1;
  if v_seat is null then
    return public.aa_err('closed');
  end if;
  begin
    insert into public.aa_room_entries (room_id, seat, submit_id, answers, choices, relation)
    values (v_room.id, v_seat, v_sub, p_form -> 'answers', p_form -> 'choices', p_form ->> 'relation');
  exception when others then
    return public.aa_err('invalid');
  end;
  return jsonb_build_object('ok', true, 'seat', v_seat);
end
$$;

-- ── 4 輪詢（平板）─────────────────────────────────────────────────────
-- 每 IP 每分鐘 120 次：容量 120、每秒回 2。host 不符一律 invalid。
create function public.aa_room_poll(p_code text, p_host text, p_after bigint)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_room public.aa_rooms;
  v_hash text;
  v_rows jsonb;
begin
  if not public.aa_room_take('poll:ip:' || public.aa_room_ip(), 120, 2, 1) then
    return public.aa_err('rate_limited');
  end if;
  v_hash := public.aa_room_hash(p_host);
  if p_code is null or p_code !~ '^[0-9a-f]{32}$' or v_hash is null then
    return public.aa_err('invalid');
  end if;
  select * into v_room from public.aa_rooms r where r.code = p_code;
  if not found or v_room.host_hash <> v_hash then
    return public.aa_err('invalid');
  end if;
  if v_room.closed or v_room.expires_at <= now() then
    return public.aa_err('closed');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'n', x.n, 'seat', x.seat, 'answers', x.answers, 'choices', x.choices, 'relation', x.relation
    ) order by x.n), '[]'::jsonb)
  into v_rows
  from (
    select e.n, e.seat, e.answers, e.choices, e.relation
    from public.aa_room_entries e
    where e.room_id = v_room.id and e.n > coalesce(p_after, 0)
    order by e.n
    limit 100
  ) x;
  return jsonb_build_object('ok', true, 'open', true, 'entries', v_rows);
end
$$;

-- ── 5 手動報到的座位保留（平板）────────────────────────────────────────
-- 把 p_seats 併進 held（去重）。p_seats 必須都在房間的 seats 裡。
-- 每 IP：容量 60、每秒回 1（數字是我抓的）。
create function public.aa_room_hold(p_code text, p_host text, p_seats text[])
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_room public.aa_rooms;
  v_hash text;
begin
  if not public.aa_room_take('host:ip:' || public.aa_room_ip(), 60, 1, 1) then
    return public.aa_err('rate_limited');
  end if;
  v_hash := public.aa_room_hash(p_host);
  if p_code is null or p_code !~ '^[0-9a-f]{32}$' or v_hash is null
     or p_seats is null
     or array_ndims(p_seats) is distinct from 1
     or cardinality(p_seats) not between 1 and 60
     or exists (select 1 from unnest(p_seats) s where s is null or s !~ '^P[0-9]{2,3}$') then
    return public.aa_err('invalid');
  end if;
  select * into v_room from public.aa_rooms r where r.code = p_code for update;
  if not found or v_room.host_hash <> v_hash then
    return public.aa_err('invalid');
  end if;
  if v_room.closed or v_room.expires_at <= now() then
    return public.aa_err('closed');
  end if;
  if not (p_seats <@ v_room.seats) then
    return public.aa_err('invalid');
  end if;
  update public.aa_rooms
  set held = coalesce((
    select array_agg(distinct x) from unnest(held || p_seats) x
  ), '{}')
  where id = v_room.id;
  return jsonb_build_object('ok', true);
end
$$;

-- ── 6 關房（平板）─────────────────────────────────────────────────────
-- 直接刪房間（entries 跟著 cascade 刪）。每 IP：容量 60、每秒回 1（數字是我抓的）。
create function public.aa_room_close(p_code text, p_host text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash text;
  v_id uuid;
begin
  if not public.aa_room_take('host:ip:' || public.aa_room_ip(), 60, 1, 1) then
    return public.aa_err('rate_limited');
  end if;
  v_hash := public.aa_room_hash(p_host);
  if p_code is null or p_code !~ '^[0-9a-f]{32}$' or v_hash is null then
    return public.aa_err('invalid');
  end if;
  delete from public.aa_rooms r
  where r.code = p_code and r.host_hash = v_hash
  returning r.id into v_id;
  if v_id is null then
    return public.aa_err('invalid');
  end if;
  return jsonb_build_object('ok', true);
end
$$;

-- ── 權限：預設全關；6 支對外函式開給 anon 與 authenticated，小工具不開 ───────

revoke all on function public.aa_room_ip() from public, anon, authenticated;
revoke all on function public.aa_room_take(text, real, real, real) from public, anon, authenticated;
revoke all on function public.aa_room_hash(text) from public, anon, authenticated;

revoke all on function public.aa_room_open(text, text[], integer, text) from public, anon, authenticated;
grant execute on function public.aa_room_open(text, text[], integer, text) to anon, authenticated;

revoke all on function public.aa_room_info(text) from public, anon, authenticated;
grant execute on function public.aa_room_info(text) to anon, authenticated;

revoke all on function public.aa_room_join(text, jsonb) from public, anon, authenticated;
grant execute on function public.aa_room_join(text, jsonb) to anon, authenticated;

revoke all on function public.aa_room_poll(text, text, bigint) from public, anon, authenticated;
grant execute on function public.aa_room_poll(text, text, bigint) to anon, authenticated;

revoke all on function public.aa_room_hold(text, text, text[]) from public, anon, authenticated;
grant execute on function public.aa_room_hold(text, text, text[]) to anon, authenticated;

revoke all on function public.aa_room_close(text, text) from public, anon, authenticated;
grant execute on function public.aa_room_close(text, text) to anon, authenticated;

commit;
