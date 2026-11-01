-- supabase/migrations/20261101130000_daily_mission_plans.sql
--
-- 每日任務的 AI 版本（Edge Function `daily-missions`）用的表：一人一天一列。
--
-- 為什麼要有這張表：保證一個人一天最多呼叫一次 Claude。函式先「搶位」
-- （insert ... on conflict do nothing），搶到的才呼叫 Claude，沒搶到的讀這一列：
-- 寫好了就回同一份文字，還在處理或失敗了就回規則版（App 端用規則排任務）。
-- 並發請求也一樣，因為搶位靠主鍵，不靠先查再寫。
--
-- 裡面只存 Claude 寫好的任務文字（payload：greeting 與三個 {id, reason}），
-- 不存 App 送來的遊戲紀錄、健檢結果、步數等原始數字。
--
-- 只有 service role（Edge Function）會讀寫：開 RLS、不給任何政策，
-- 並收回 anon、authenticated 的所有權限。
--
-- 還沒套用到正式庫；套用前要先問 user。

begin;

create table public.daily_mission_plans (
  user_id    uuid not null references auth.users (id) on delete cascade,
  day        date not null,
  status     text not null check (status in ('pending', 'done', 'failed')),
  payload    jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- 函式算「全站今天已經幾列」用的。
create index daily_mission_plans_created_at_idx
  on public.daily_mission_plans (created_at);

alter table public.daily_mission_plans enable row level security;
-- 刻意不建立任何 policy：一般登入者完全讀不到、寫不到。

revoke all on table public.daily_mission_plans from anon, authenticated;

commit;
