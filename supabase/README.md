<!-- supabase/README.md -->
# supabase：銀足的伺服器端（好友系統）

**狀態：2026-10-27 已套用到正式庫（SilverSole，`buvdyjzxeojpuiqeyteh`）**：兩支 migration 都已套用，Edge Function `delete-account` 也已部署。這次跳過了下面「套用順序」的第 2–4 步（先在 Supabase 分支實測），原因是正式版 App 已經在呼叫這些表，不套的話好友功能本來就是壞的；實機實測改在 TestFlight 做。套用前跑過「套用前比對」：沒有撞名，本機測試 60/60 通過。正式庫沒有 `supabase_migrations` 紀錄表，這兩支是用 `supabase db query -f` 直接執行的。之後的 migration 一樣要先問 user。

**已知待處理：**`devices` 的 SELECT 政策是 `true`（任何登入者都讀得到所有裝置的電量與心跳時間），應該改成只能讀自己綁定的裝置。

規格：動域科技總倉庫 `02_產品/鞋墊_SilverSole/_好友系統規格書_2026-10-18.md` 第 7、8、10 節。
App 端：`lib/core/friends/supabase_friends_repository.dart`（`friends_provider.dart` 已經改接它）。

## 檔案

| 檔案 | 內容 |
|---|---|
| `migrations/20261019120000_friends.sql` | 9 張表（profiles、friendships、friend_requests、blocks、qr_tokens、orgs、org_members、profile_reports、friend_daily_limits）、RLS、規格 8.1 與 8.2 的函式、私有 bucket `avatars` 與它的 storage 政策、執行權 |
| `tests/supabase_stubs.sql` | **只給本機測試用**：auth、storage、角色的最小替身，加上 Supabase 的預設權限。正式庫已經有這些東西，不能套上去 |
| `migrations/20261026120000_friends_rpc_abuse.sql` | 修 2026-10-26 技術長藍隊核查的 8 類 RPC 濫用（見下面「RPC 濫用修正」）。接在上一支後面，兩支要一起套 |
| `migrations/20261031120000_game_saves.sql` | H5 遊戲雲端存檔（2026-10-31）：表 `game_saves`、`game_save_load()`、`game_save_store(rev, data)`；只走 RPC、256 KB 上限、每人限流、rev 比對。測試：`npm run test:saves`、`npm run test:saves-concurrency`。**2026-10-31 晚已套用到正式庫**（user 同意；「公司主線計畫」視窗用 apply_migration 套上，套前本機 test:saves 8/8、concurrency 2/2，正式庫先在交易裡試跑再還原；正式庫第一批有 migration 紀錄的） |
| `tests/friends_rpc_test.mjs` | 60 個案例：Dart 假資料版的測試（`test/friends/fake_friends_repository_test.dart`）、規格 §10 的 RPC 與 RLS 測試，加上核查 8 點的攻擊情境（audit 1–8） |
| `tests/friends_concurrency_test.mjs` | 並發攻擊：在本機開一個真的 PostgreSQL（`embedded-postgres`，MIT），用 60 條連線同時打。每個情境先在「只有第一支 migration」跑一次證明漏洞存在，再在兩支都套的版本跑一次 |

```bash
cd supabase/tests && npm install && npm test
npm run test:concurrency   # 真 PostgreSQL，第一次會下載約 30 MB 的 PostgreSQL 執行檔
```

測試跑在 PGlite 上（PostgreSQL 17.5 編成 WASM，不用 Docker）。2026-10-23 跑的結果是 52/52 通過。另外做過突變測試：把封鎖判斷或冷卻判斷拿掉，就有 3 個案例失敗，表示這些測試抓得到錯。

**沒測到的：**PGlite 只有一條連線，所以並行的情況沒有測：兩人同時互送邀請、偷菜鎖住好友列的同時有人解除好友。這兩種要在 Supabase 分支上實測。Storage API 本身（上傳、簽網址）也沒有測，替身只模擬了 `storage.objects` 的 RLS。

## RPC 濫用修正（2026-10-26）

技術長用 AI 做藍隊核查，找到 8 類 RPC 濫用。共通原因：限制只寫在「單一請求、單一配對」，沒想到對方會繞過 App 直接打 API、同時送一堆請求、開分身。

| # | 核查找到的 | 怎麼修 | 測試 |
|---|---|---|---|
| 1 | 封鎖會刪掉兩人間的邀請，連拒絕紀錄一起刪，30 天冷卻被洗掉 | 冷卻改存獨立的 `friend_cooldowns`，封鎖、解封、刪好友、取消都刪不掉；`block_user` 只把等待中的邀請改成 cancelled | audit 1 |
| 2 | `create_qr_token` 沒限頻，一秒造 50 列 | 還有 60 秒以上的 token 直接重用；產生新的時刪掉自己過了寬限的舊 token（每人最多兩三列）；另扣限流 | audit 2 |
| 3 | 取消的邀請不算額度 → 送、通知、取消無限重複 | 每天送出 30 封（含取消、含暫扣）；取消後 24 小時內再送同一人一律暫扣、對方看不到 | audit 3 ×2 |
| 4 | 大頭貼每日 5 張是事後 count，並發 50 個全過；孤兒檔永久佔空間 | 上傳政策先鎖人、用計數列扣次數；資料夾總數最多 10 張；可以刪自己的舊照片（目前那張不能刪），App 換照片後自動刪舊的 | audit 4（PGlite）＋並發測試（修前 30/30 進、修後 5） |
| 5 | 檢舉轟炸：100 個假帳號 × 10 次 | 同一人對同一人同一類還沒處理的只留一筆；檢舉人要取好名字且帳號滿 3 天（不到照樣回成功、不記）；被檢舉人一天最多新增 30 筆 | audit 5 |
| 6 | 20 封未回覆的鎖只鎖一對，並發寄 200 人全過 | `friends_lock_pair` 改成依 user_id 順序鎖兩個「人」，所有上限在鎖裡算 | 並發測試（修前 22/60、修後剛好 20） |
| 7 | 暱稱可放零寬字、反向字、冒充系統名、自取「銀足朋友」 | NFKC 正規化＋逐字白名單；`friend_reserved_names` 保留名（銀足、官方、客服、管理員、系統、動域、admin、support、粗哥）；App 端同步檢查 | audit 7＋Dart 單元測試 |
| 8 | 沒有每人全域限流 | `friend_rate_buckets` token bucket（容量 30、每秒回 0.5），`friends_me()`／`friends_uid()` 第一行扣，寫入類 RPC 多扣；同一人的呼叫排隊 | audit 8＋並發測試 |

新的錯誤碼：`rate_limited`（太快了，等一下再試）、`send_limit`（今天的邀請送夠多了）。App 端 `FriendError.rateLimited`、`sendLimit`。

**還沒處理：**
- 被惡意上傳後又沒登記的照片（資料夾上限 10 張以內）不會自己清，要另寫 Edge Function 用 Storage API 定期清（Postgres 刪不了 Storage 的檔）。
- 一人開很多帳號本身擋不住；檢舉已改成以「不同帳號、帳號滿 3 天」計，送邀請仍是每個帳號各自的額度。
- 這些是 AI 查得到的；正式上線前仍建議請專業資安單位審。

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
| 6 | 好友上限 100 | 互邀直接成立、或按同意時，**對方**滿 100 回 `other_friend_limit`（自己滿了才是 `friend_limit`） | 不然對方會變成 101 位。分成兩個代碼，App 才能說「對方的朋友已經滿了」，不會叫他去刪自己的朋友。代價是透露「對方滿了」這件小事 |
| 7 | 防亂猜：查好友碼與據點代碼共用額度 | 沒預覽過就直接送出邀請或加入據點，也扣一次查號；今天預覽過的號碼不再扣 | 不然可以拿送出或加入來白猜號碼 |
| 8 | — | 會動到查號次數的函式（preview_by_code、preview_by_qr、preview_org、join_org、send_friend_request）回傳 `{"error": code}`，其他函式用 `raise exception` | raise 會讓交易回滾，猜錯的次數就記不住了 |
| 9 | — | 「今天」用台灣時間；連錯 5 次的鎖跨過午夜也有效 | 跟菜園的 `farm_today()` 一致 |
| 10 | 被拒 30 天冷卻，期間再邀回 `cooldown` | 冷卻期間再邀（拒絕的那封過期後、或自己取消後再送）**照常回 `sent`**，但這封直接存成 `declined`、不送到對方那裡。送的人看到的跟一般邀請一模一樣：「等回覆」7 天、可以取消、算在 20 封裡、據點名單顯示「等回覆」；對方的邀請、紅點、據點名單都看不到。`responded_at` 沿用原本那次拒絕，冷卻不會因為一直重送而延長 | 回 `cooldown` 等於告訴他「你被拒絕了」，「按不要不通知」就破功（2026-10-23 user 決定）。`friend_requests` 本來就不開 select，App 讀不到 status |
| 11 | QR 5 分鐘失效 | 過期前預覽過的人，過期後 60 秒內還能用同一個 QR 送出邀請（預覽過的 QR 記在 `friend_daily_limits.previewed_codes`，前面加 `qr:`）。沒預覽過、或超過 60 秒，照樣 `qr_expired` | 掃到 4:59、還在看名字就過期，長輩會以為按壞了。App 也改成過一半（2.5 分鐘）就換新的 QR |
| 12 | 第一次呼叫就建 profiles | `get_friend_requests()`、`get_friends()` 不建 profiles（沒有就回空的）；還沒取名字的 profile 查好友碼查不到 | 廣場的紅點、遊戲大廳的好友卡每次都會讀這兩支，不該替沒打開過好友的人配好友碼。取名字之前也還沒決定要用好友 |
| 13 | 同意後只結掉那一封 | 成為好友時，兩人之間所有還開著的邀請（反方向在等的、被悄悄拒絕或暫扣的）一起改成 accepted | 不然送的人那邊會一直顯示「等回覆」給已經是好友的人 |
| 14 | 頭像一律 JPEG | 接受 JPEG、PNG、WebP，副檔名照檔案實際格式（App 讀檔頭判斷），bucket 的 `allowed_mime_types` 同步 | image_picker 縮圖時保留原本格式，PNG 硬標成 JPEG 會壞掉 |

## 效能

- `profiles (avatar_path) where avatar_path is not null` 有部分索引：`can_read_avatar()` 每次簽網址都用照片路徑反查。
- storage 政策與 `avatar_upload_allowed()`、`can_read_avatar()` 判斷「自己的資料夾」寫成 `name like auth.uid()::text || '/%'`（不用 `storage.foldername()`），`storage.objects` 的 name 索引用得上。uuid 裡沒有 `%`、`_`，前綴比對不會誤中。

## Edge Function `delete-account`（App 內刪除帳號）

`functions/delete-account/index.ts`：App 個人頁的「刪除帳號」呼叫它（App Store 審核 5.1.1(v)）。只收 POST；用呼叫者自己的 JWT（`Authorization` 標頭）向 Auth 查出是誰，不看 request body，所以刪不到別人。接著用 service role：先刪 `avatars/{user_id}/` 下的照片，再刪這個人的 `user_devices` 列（正式庫 `user_devices.user_id` 參照 auth.users 是 **ON DELETE NO ACTION**，有列就刪不掉帳號），最後 `auth.admin.deleteUser`，好友系統的表都從 auth.users 連帶刪除。好友 migration 和 avatars bucket 還沒套到正式庫也沒關係：找不到 bucket 或表會記 log、跳過，帳號照樣刪。回 `{ ok: true }`（200）或 `{ error }`（401 / 405 / 500）。App 把 401、404 當成「帳號已經不在」直接登出。

部署（不需要額外 secret，`SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY` 是平台內建的）：

```bash
supabase functions deploy delete-account --project-ref <ref>
```

函式自己驗 token，所以有沒有加 `--no-verify-jwt` 都能用。

## 給菜園與之後功能的保證

- `are_friends(a, b, lock)`、`friend_count(u)`、`touch_friendship(a, b)` 對 `public`、`anon`、`authenticated` 都收回了執行權，只有 security definer 函式能呼叫。
- `touch_friendship` 每次都真的執行 UPDATE（不節流），不是好友時更新 0 列。菜園拿它當好友那一列的獨佔鎖用。
- `remove_friend` 會 DELETE 那一列；`block_user` 會先記下封鎖，再 DELETE 那一列與雙方之間的邀請。所以偷菜鎖住那一列的時候，解除好友和封鎖都要排隊等它結束。
- `is_my_friend(other)` 開放給 App 呼叫，宣告成 stable、不加鎖，菜園的 RLS 政策也用它。

## 還沒做

- **中控台後台**（規格 8.5）：建據點、換代碼、停用據點、移出成員、處理檢舉（抽掉照片或暱稱）。建議做法是 Edge Function `friends-admin` 加上一組只放在 Cloudflare Secret 的金鑰，要跟安東尼確認。現在要測試就用 SQL editor 直接 insert `orgs`。
  - 抽掉照片：`avatar_path = null`、`avatar_removed = true`、`avatar_removed_count + 1`，滿 3 次設 `avatar_upload_banned_until = now() + 30 days`；檔案要用 Storage API 刪（Postgres 不能直接刪 storage.objects）。
  - 抽掉暱稱：`nickname = '銀足朋友'`、`nickname_removed = true`。
- **換掉的舊照片**留在 Storage（好友已經讀不到），之後由後台清。
- App 端的照片裁切：現在上傳的是 image_picker 縮到 512 以內的原格式照片，還沒裁成正方形（`profile_page.dart` 的 TODO）。
