<!-- supabase/README.md -->
# supabase：銀足的伺服器端（好友系統）

**狀態：沒有套用到任何 Supabase 專案。套用到正式庫之前要先問 user。**

規格：動域科技總倉庫 `02_產品/鞋墊_SilverSole/_好友系統規格書_2026-10-18.md` 第 7、8、10 節。
App 端：`lib/core/friends/supabase_friends_repository.dart`（`friends_provider.dart` 已經改接它）。

## 檔案

| 檔案 | 內容 |
|---|---|
| `migrations/20261019120000_friends.sql` | 9 張表（profiles、friendships、friend_requests、blocks、qr_tokens、orgs、org_members、profile_reports、friend_daily_limits）、RLS、規格 8.1 與 8.2 的函式、私有 bucket `avatars` 與它的 storage 政策、執行權 |
| `tests/supabase_stubs.sql` | **只給本機測試用**：auth、storage、角色的最小替身，加上 Supabase 的預設權限。正式庫已經有這些東西，不能套上去 |
| `tests/friends_rpc_test.mjs` | 45 個案例：Dart 假資料版的測試（`test/friends/fake_friends_repository_test.dart`）加上規格 §10 的 RPC 與 RLS 測試 |

```bash
cd supabase/tests && npm install && npm test
```

測試跑在 PGlite 上（PostgreSQL 17.5 編成 WASM，不用 Docker）。2026-10-19 跑的結果是 45/45 通過。另外做過突變測試：把封鎖判斷或冷卻判斷拿掉，就有 3 個案例失敗，表示這些測試抓得到錯。

**沒測到的：**PGlite 只有一條連線，所以並行的情況沒有測：兩人同時互送邀請、偷菜鎖住好友列的同時有人解除好友。這兩種要在 Supabase 分支上實測。Storage API 本身（上傳、簽網址）也沒有測，替身只模擬了 `storage.objects` 的 RLS。

## 套用前比對（正式庫跑這幾句，結果貼回來）

這台電腦連不到 SilverSole 的 Supabase 專案，現有的 schema 是從 App 程式碼推出來的：`devices`、`silversole_record_data`、`device_locations`、`user_devices`、bucket `firmware`、Edge Function `heartbeat`。

```sql
-- 1. 有沒有撞名（profiles 是 Supabase 範本常見的名字，最可能撞）
select table_name from information_schema.tables
where table_schema = 'public'
  and table_name in ('profiles','friendships','friend_requests','blocks','qr_tokens',
                     'orgs','org_members','profile_reports','friend_daily_limits');
select proname from pg_proc join pg_namespace n on n.oid = pronamespace
where nspname = 'public'
  and (proname like 'friends\_%' or proname in ('are_friends','friend_count','touch_friendship',
       'is_my_friend','get_friends','avatar_upload_allowed','can_read_avatar'));
select id from storage.buckets where id = 'avatars';

-- 2. 健康數據表的 RLS：每張表都要開 RLS，政策只能是「自己的資料」
select c.relname, c.relrowsecurity
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r';
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies where schemaname in ('public', 'storage') order by tablename;

-- 3. pg_cron、pgcrypto 用不到；gen_random_uuid()、sha256() 是內建的
```

看結果的重點：

- 第 1 段應該全部是空的。如果有任何一筆，先不要套。migration 用的是 `create table`，沒有加 `if not exists`，撞名會直接失敗，不會蓋掉原本的表。
- 第 2 段裡，`silversole_record_data`、`devices`、`device_locations` 的政策只能是 `auth.uid()` 對自己的資料。看到 `true`，或任何「別人也讀得到」的條件，要先跟安東尼修好。好友系統沒有開健康數據的讀取權，但這一段要親眼看過才算數。

## 套用順序（每一步都要先問 user）

1. 跑上面的比對。
2. 在 **Supabase 分支**套這支 migration（不是正式庫）。
3. 跑 Supabase advisors（security、performance），處理所有警告。
4. 在分支上用兩個測試帳號實測：
   - 規格 §10 的並行情況。
   - App 真機走一遍：取名、QR、好友碼、據點、封鎖、上傳照片、好友看得到照片。
5. 測過、user 同意後才套正式庫。
6. 菜園的 SQL（主資料夾 `supabase/farm/`，在 feat/farm-redesign 分支）要排在這支後面，因為它會呼叫 `are_friends`、`is_my_friend`、`touch_friendship`。之後兩邊要統一放在 `supabase/migrations/`。

## 跟規格書不一樣的地方

| # | 規格書 | 這裡 | 為什麼 |
|---|---|---|---|
| 1 | `friend_requests` 開放 select 自己送或收的那封 | 不開，一律走 `get_friend_requests()` | 送的人直接讀表會看到 `status = 'declined'`，「按不要不通知」就破功了 |
| 2 | 照片由 RPC 產生 1 小時的簽名網址；avatars 不加 SELECT 政策 | RPC 只回照片路徑，App 用 `createSignedUrls(…, 3600)` 換網址；avatars 加一條 SELECT 政策，只放行「自己的資料夾」和「好友目前那一張照片」 | Postgres 產生不了 Storage 的簽名網址。這條政策下，非好友、換掉的舊照片、被抽掉的照片都簽不出網址，不能列出別人的資料夾 |
| 3 | — | 多了這些欄位：`profiles.nickname_removed`、`avatar_removed`（「被抽掉了」的提示）、`nickname_changed_on`（配合 `nickname_changed_today` 換日）、`friend_daily_limits.previewed_codes`、`profile_reports.handled_by` | 規格裡的行為需要這些欄位才做得出來 |
| 4 | 8.2 沒有列 | 多了 `acknowledge_removals()` | App 顯示過「照片被移除了」之後要清掉提示（介面原本就有這個方法） |
| 5 | 預覽：找不到、過期、被封鎖一律回 `not_found` | QR 過期回 `qr_expired`；找不到、是自己、有封鎖還是回 `not_found`，而且先判斷這三種 | App 要顯示「條碼過期了，請對方重新打開」（規格 3.1）；被封鎖的人看到的仍然跟亂掃一樣 |
| 6 | 好友上限 100 | 互邀直接成立、或按同意時，**對方**滿 100 也回 `friend_limit` | 不然對方會變成 101 位。代價是透露「對方滿了」這件小事 |
| 7 | 防亂猜：查好友碼與據點代碼共用額度 | 沒預覽過就直接送出邀請或加入據點，也扣一次查號；今天預覽過的號碼不再扣 | 不然可以拿送出或加入來白猜號碼 |
| 8 | — | 會動到查號次數的函式（preview_by_code、preview_by_qr、preview_org、join_org、send_friend_request）回傳 `{"error": code}`，其他函式用 `raise exception` | raise 會讓交易回滾，猜錯的次數就記不住了 |
| 9 | — | 「今天」用台灣時間；連錯 5 次的鎖跨過午夜也有效 | 跟菜園的 `farm_today()` 一致 |

## 給菜園與之後功能的保證

- `are_friends(a, b, lock)`、`friend_count(u)`、`touch_friendship(a, b)` 對 `public`、`anon`、`authenticated` 都收回了執行權，只有 security definer 函式能呼叫。
- `touch_friendship` 每次都真的執行 UPDATE（不節流），不是好友時更新 0 列。菜園拿它當好友那一列的獨佔鎖用。
- `remove_friend` 會 DELETE 那一列；`block_user` 會先記下封鎖，再 DELETE 那一列與雙方之間的邀請。所以偷菜鎖住那一列的時候，解除好友和封鎖都要排隊等它結束。
- `is_my_friend(other)` 開放給 App 呼叫，宣告成 stable、不加鎖，菜園的 RLS 政策也用它。

## 還沒做

- **中控台後台**（規格 8.5）：建據點、換代碼、停用據點、移出成員、處理檢舉（抽掉照片或暱稱）。建議做法是 Edge Function `friends-admin` 加上一組只放在 Cloudflare Secret 的金鑰，要跟安東尼確認。現在要測試就用 SQL editor 直接 insert `orgs`。
  - 抽掉照片：`avatar_path = null`、`avatar_removed = true`、`avatar_removed_count + 1`，滿 3 次設 `avatar_upload_banned_until = now() + 30 days`；檔案要用 Storage API 刪（Postgres 不能直接刪 storage.objects）。
  - 抽掉暱稱：`nickname = '銀足朋友'`、`nickname_removed = true`。
- **刪除帳號時清掉照片檔**：資料表會跟著 auth.users 連帶刪除，但 avatars 裡的檔案要靠刪帳號流程呼叫 Storage API 刪掉。
- **換掉的舊照片**留在 Storage（好友已經讀不到），之後由後台清。
- App 端的照片裁切：現在上傳的是 image_picker 縮到 512 以內的 JPEG，還沒裁成正方形（`profile_page.dart` 的 TODO）。
