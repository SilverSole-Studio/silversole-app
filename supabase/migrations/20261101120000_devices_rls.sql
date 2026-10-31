-- supabase/migrations/20261101120000_devices_rls.sql
--
-- 補 devices、user_devices 兩個 RLS 洞（2026-10-31 唯讀查正式庫確認）。
-- 這兩張表早於 migrations/ 就存在，不是這個資料夾建的。
--
-- 洞 1：devices 只有一條 SELECT 政策 "Enable read access for authenticated users"，
--       條件是 true。任何登入的人都讀得到每一台裝置的電量、充電狀態、心跳時間。
-- 洞 2：user_devices 的 INSERT 政策只檢查 user_id = 自己，沒檢查 device_id 是不是
--       他的。晶片 ID 是用藍牙廣播的，旁邊的人聽得到；任何人都能替自己綁上別人的
--       device_id。洞 1 補成「只讀自己綁的裝置」之後，這個洞就等於讓攻擊者自己
--       開通讀取權，而 device_locations、silversole_record_data 的政策本來就是看
--       user_devices，所以那兩張表（位置與足壓紀錄）也一起被讀走。
--
-- 修法：
--   - devices 改成只有「user_devices 裡有自己綁定」的裝置才讀得到。
--   - 拿掉 user_devices 的 INSERT 政策，使用者不能再直接寫綁定。之後的綁定只走
--     security definer 的 RPC，並要求證明人真的拿著那隻鞋墊（還沒做，見 README）。
--
-- 為什麼不用改 App：devices 的資料由人工建立，heartbeat Edge Function 用 service
-- role 更新（service role 不受 RLS 影響）；App 裡讀 devices、寫 user_devices 的呼叫
-- 已在 2026 年 4 月與 7 月移除，現在沒有任何程式碼會碰到這兩條路。
--
-- 不動：user_devices 的 SELECT 政策（本來就是 user_id = 自己）、device_locations、
-- silversole_record_data、任何 grant。

begin;

-- 正式庫兩張表本來就開著；重跑也不會出事。
alter table public.devices enable row level security;
alter table public.user_devices enable row level security;

drop policy if exists "Enable read access for authenticated users" on public.devices;

create policy devices_select_own on public.devices
  for select to authenticated
  using (
    exists (
      select 1
      from public.user_devices ud
      where ud.device_id = devices.device_id
        and ud.user_id = (select auth.uid())
    )
  );

drop policy if exists "Enable insert for users based on user_id" on public.user_devices;

commit;
