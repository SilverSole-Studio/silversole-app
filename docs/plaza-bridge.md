# 粗哥廣場 ↔ App 通道

App 的遊戲分頁（`lib/shared/pages/plaza_tab_page.dart`）用 WebView 開 `<gameUrl>game/plaza/`。廣場網頁跟 App 之間只走這份文件寫的通道；App 端的格式定義在 `lib/shared/providers/plaza_bridge.dart`。

**只服務遊戲自己的網站。**下面的通道（`window.silversoleApp`、`appInfo`、`openFriends`、`exitPlaza`、`mpSession`）和相機權限，只給跟 `gameUrl` 同一個 origin（協定、網域、port 都一樣）的頁面；正式版就是 `https://h5.silversole.dongyu.company`。廣場如果在同一個 WebView 裡連到別的網站，那個頁面讀不到 `window.silversoleApp`，呼叫 `appInfo` 拿到 `null`、`openFriends` 與 `exitPlaza` 拿到 `false`、`mpSession` 拿到 `null`，要相機也會被拒絕。相機以外的權限（麥克風、定位等）一律拒絕。

## App → 網頁：現在能顯示什麼

**頁面一開始載入（document start，廣場自己的程式還沒跑）就已經設好**，之後每次載入完、以及數字有變的時候，App 會再設一次：

```js
window.silversoleApp = {
  features: { friends: true },   // false＝不要顯示好友建築
  friendRequests: 2,             // 好友建築上的紅點數字；friends 為 false 時一律 0
  account: {                     // 目前登入的使用者；沒登入時整個 account 不存在
    id: "uuid-of-supabase-user", // Supabase auth 的 user id
    username: "ricky951102"      // 登入 email 的 @ 前面那段；沒有 email 時是 ""
  },
  systemFontScale: 1.0,          // 手機「字體大小」設定的倍率（1.0＝預設，1.3、1.5、2.0…）
  textSize: "normal",            // App 設定頁的「文字大小」："normal"（標準）或 "large"（大）
  subscription: { active: true },// 訂閱中嗎：以伺服器為準（見下面「訂閱與鑽石」）
  diamonds: {                    // 鑽石（2026-11-02）；還沒問到伺服器、沒登入時整個不存在
    balance: 120,                // 現有鑽石
    month: 40,                   // 這個月（台灣時間）已經賺到的
    cap: 300                     // 每月上限
  }
};
```

`account.username`：App 沒有獨立的「帳號名稱」欄位（登入是 email／Google），所以取 email 的 `@` 前面（`ricky951102@gmail.com` → `ricky951102`）。好友的暱稱是使用者自己取的，不拿來當帳號。登入或登出時 App 會重新送一次 `silversoleapp` 事件。注意 username 只是拿來比對的名字，不同網域的 email 可以有相同的前綴，不能當作身分證明。

**`systemFontScale`**：長輩常把手機字體調到最大。App 自己的字最多放大到 1.3 倍，WebView 的 `textZoom` 固定 100（不會被系統再放大一次），所以網頁字不會跟著系統放大。要讓網頁自己跟著變大，就看這個欄位：大於等於 1.15 時自動開大字模式（使用者手動切換的設定優先）。**這是沒有 `textSize` 時的舊辦法**，見下一段。

**`textSize`（2026-11-03）**：App 設定頁多了「文字大小：標準／大」，網頁的大字模式跟它走：`"large"`＝開、`"normal"`＝關，不再看 `systemFontScale`，網頁自己的大字開關也要藏起來（兩邊設定會打架）。第一次啟動時 App 會看手機字體倍率，大於等於 1.15 就先設成「大」，之後以使用者在設定頁選的為準。使用者改了設定，App 會馬上重送一次 `silversoleapp` 事件，網頁收到就套用。沒有這個欄位（舊版 App、瀏覽器直接開）時，網頁維持原本的作法：自己的開關加 `systemFontScale`。

並在 `window` 上觸發 `silversoleapp` 事件（`event.detail` 就是上面這個物件）。

網頁也可以主動問：`await window.flutter_inappwebview.callHandler('appInfo')`，回傳同一個物件。

**用瀏覽器直接開廣場時，`window.silversoleApp` 不存在**：好友建築不要畫出來（好友只在 App 裡有）。

## 網頁 → App：打開好友頁

```js
window.flutter_inappwebview.callHandler('openFriends')  // 回傳 true；好友沒開時回傳 false
```

App 會蓋上好友頁；使用者按返回就回到廣場，App 會重新送一次 `silversoleapp` 事件更新紅點。好友頁還開著的時候再呼叫一次，不會疊第二層，一樣回傳 `true`。

## 網頁 → App：回 App（2026-11-03）

遊戲分頁（小鎮大廳與所有遊戲）**一律不顯示 App 下方的導覽列**，避免玩的時候誤觸換頁。網頁要離開時走這個通道：

```js
window.flutter_inappwebview.callHandler('exitPlaza')  // 回傳 true；不是遊戲自己的網站回傳 false
```

App 會切回首頁分頁，導覽列就出現了。小鎮選單的「回 App」就是呼叫它（只在 App 裡、`flutter_inappwebview` 存在時才顯示）。

手機返回鍵：在小鎮大廳按，App 切回首頁分頁（不會直接關掉 App）；在遊戲裡按，維持原本的作法，退回上一頁（小鎮）；離開遊戲網站的頁面也是退回上一頁，沒有上一頁就切回首頁分頁。

## 網頁端參考寫法

```js
// 廣場裡任何地方都可以用：讀目前的 App 狀態（不在 App 裡就是 null）
function appInfo() { return window.silversoleApp || null; }

function friendsOn() {
  var info = appInfo();
  return !!(info && info.features && info.features.friends);
}

// 數字變了就重畫（紅點、建築要不要出現）
window.addEventListener("silversoleapp", function () { requestRedraw(); });

// flutter_inappwebview 晚一點才準備好時，也主動問一次
window.addEventListener("flutterInAppWebViewPlatformReady", function () {
  window.flutter_inappwebview.callHandler("appInfo").then(function (info) {
    if (info) { window.silversoleApp = info; requestRedraw(); }
  });
});

// 大字模式：App 有 textSize 就跟它走，沒有才看 systemFontScale
function largeText(userChoice) {
  var info = appInfo();
  if (info && info.textSize) return info.textSize === "large";
  return userChoice || (info && info.systemFontScale >= 1.15);
}

// 小鎮選單的「回 App」
function exitPlaza() {
  if (!window.flutter_inappwebview) return;
  window.flutter_inappwebview.callHandler("exitPlaza");
}

// 點到好友建築
function openFriends() {
  if (!window.flutter_inappwebview) return;
  window.flutter_inappwebview.callHandler("openFriends");
}
```

`requestRedraw()` 換成廣場自己的重畫函式。

## 好友什麼時候會開

- 開發版（debug）：一律開，用 App 內建的假資料，可以試畫面。
- 正式版：資料庫（`supabase/migrations/20261019120000_friends.sql`）套用後，用 `--dart-define=FRIENDS_BACKEND=supabase` 打包才會開。沒開之前 `features.friends` 都是 `false`，廣場不會出現好友建築。

## 雲端存檔（2026-10-31）

遊戲的進度（金幣、收藏冊、車、農場、旅行紀錄…）原本只存在手機的 localStorage。廣場分頁另外接兩個 handler，把整包存到帳號上（`supabase/migrations/20261031120000_game_saves.sql`）：

```js
// 開廣場時：拿雲端那包
const r = await window.flutter_inappwebview.callHandler("gameSaveLoad");
// { ok: true, rev: 3, savedAt: "...", data: "<JSON 字串>" }；沒存過 rev 0、data null
// 失敗：{ ok: false, reason: "signed_out" | "rate_limited" | "offline" }

// 存：rev 是手上那份的版本，只有跟伺服器一樣才寫得進去
const w = await window.flutter_inappwebview.callHandler("gameSaveStore", { rev: 3, data: "<JSON 字串>" });
// { ok: true, rev: 4 }，或 { ok: false, reason: "conflict", rev: 5 }（別支手機先存了 → 改成載入雲端）
// 其他失敗：too_big（> 256 KB）、bad_data、signed_out、rate_limited、offline
```

一樣只有遊戲自己的網站（`isGameOrigin`）呼叫得到。遊戲端怎麼打包、什麼時候存、換帳號怎麼辦，見總倉庫 `02_產品/鞋墊_SilverSole/_遊戲雲端存檔_介面_2026-10-31.md`。

## 聯機對戰（2026-11-03）

所有遊戲要能跟好友一起玩。App 只多這一個通道，**之後每款遊戲接聯機都不用再改 App、不用重新發版**：

```js
const s = await window.flutter_inappwebview.callHandler("mpSession");
// { url: "https://xxxx.supabase.co", anonKey: "...", accessToken: "<目前登入者的 JWT>", expiresAt: 1790000000000 }
// 沒登入、App 沒設定後端、或不是遊戲自己的網站：null
```

- `expiresAt` 是**毫秒**（跟 `Date.now()` 直接比）。App 在剩不到 2 分鐘時會先換一張新的再給；換不到又還沒過期就給舊的；過期了就回 `null`。網頁在剩不到 1 分鐘時再問一次，並用新 token 更新 supabase-js（`supabase.realtime.setAuth(token)`，重建 client 也可以）。
- 拿到之後網頁自己用 supabase-js 連：`createClient(url, anonKey, { global: { headers: { Authorization: "Bearer " + accessToken } } })`；開房、加入、邀請、送一步都是 RPC（`mp_create_room`、`mp_join_room`、`mp_invite`、`mp_my_invites`、`mp_accept_invite`、`mp_submit_move`、`mp_leave`，見 `supabase/migrations/20261103120000_mp_rooms.sql`），即時通知走私人頻道 `room:<房間 id>`（對方上線、有人走了一步）與 `user:<自己的 id>`（有人邀請）。好友名單用既有的 `get_friends` RPC。
- **這個 token 是使用者本人的登入憑證**：拿到的頁面可以用這個人的身分打他所有的 RPC。所以只給遊戲自己的網站（`isGameOrigin`），App 不存它、不記 log；遊戲網站上不能放任何第三方的 script。
- 資料庫那支 migration **還沒套用**之前，RPC 會回「找不到函式」；網頁要把這個當成「沒有聯機」，不出現「線上對戰」按鈕，不能報錯。
- 廣場分頁與每日任務開的遊戲頁（`GameWebViewPage`）都有接。

## 遊戲紀錄（每日任務用，2026-11-01）

每款遊戲結算時回報一次，App 把它記在手機上（只留最近 8 天），「每日任務」靠它判斷「今天有沒有玩過這款」：

```js
window.flutter_inappwebview.callHandler("gameActivity", { slug: "fish", stage: "lantern", seconds: 95 });
// 回傳 { ok: true }；格式不對回 { ok: false }；不是遊戲網站來的頁面回 null
```

- `slug`：網址 `/game/` 後那段。踩進老街一律用 `laojie`，並多帶 `stage`（關卡代號）。slug、stage 都要符合 `^[a-z0-9_-]{1,32}$`，`stage` 可省略。
- `seconds`：實際遊玩秒數，0–10800 的整數。
- 不看回傳值也可以（fire-and-forget）。App 只擋格式，不認得的 slug 照記。
- 一樣只有遊戲自己的網站（`isGameOrigin`）呼叫得到。**廣場分頁與每日任務開的遊戲頁（`GameWebViewPage`）都有接這個 handler**，所以從哪裡進的遊戲都記得到。
- 清單與開法見總倉庫 `02_產品/鞋墊_SilverSole/_遊戲slug清單_2026-11-01.md`。

## 訂閱與鑽石（2026-11-02）

鑽石只給訂閱中的人，只靠「穿鞋墊運動」賺，只能換實物（金幣照舊只換遊戲內的東西）。數字與設計：總倉庫 `02_產品/鞋墊_SilverSole/_鑽石設計_2026-11-02.md`。帳在伺服器（`supabase/migrations/20261102120000_diamonds.sql`），手機只記「今天動了幾分鐘」。

- **`silversoleApp.subscription.active`**：伺服器上這個帳號的 `subscriptions` 那一列 `active_until >= 今天` 才是 `true`。還沒接金流，由管理者手動開通，做法見 `docs/diamonds-subscription-admin.md`。debug 版與開發者模式的「假裝已訂閱」開關也會讓它變 `true`（只改畫面，伺服器不認）。
- **`silversoleApp.diamonds`**：`{balance, month, cap}`。**沒有這個欄位＝不在 App 裡、沒登入、或還沒問到伺服器**，遊戲不要顯示餘額（不要當成 0）。數字變了（賺到、重新整理）App 會重送一次 `silversoleapp` 事件。
- **怎麼賺**：只有遊戲分頁與每日任務開的遊戲頁回報 `gameActivity`、而且當下**鞋墊連線中**的秒數，才累計成「今天的運動分鐘」。累計滿 15 分鐘，App 向伺服器要當天的 10 鑽石；一天一次、每月最多 300、沒訂閱不給。失敗（沒網路、被限流）下次回報或回到廣場時會再試。
- **遊戲這邊不用做任何事**就會賺到：照舊在結算時呼叫 `gameActivity`。遊戲不能自己改餘額，也沒有扣鑽石的通道；兌換實物還沒開放（伺服器 `diamond_redeem` 目前一律回 `not_open`），兌換站的實物分頁在訂閱中要顯示「即將開放」。
- 回報的分鐘是手機說的，伺服器沒有原始鞋墊資料，所以最壞情況是有人假報、當月領滿 300 鑽石（約 NT$30）。

## 每日任務 `dailyMissions`（唯讀）

小鎮用 `await window.flutter_inappwebview.callHandler("dailyMissions")`（不帶參數）拿今天的每日任務與完成狀態。只有遊戲站自己的頁面會得到答案，其他頁回 `null`。

```json
{
  "day": "2026-11-13",
  "missions": [
    { "id": "foot_check", "title": "足壓量測一次", "done": false },
    { "id": "bike", "title": "…", "done": true }
  ]
}
```

- `day`：App 判斷「今天」用的本地日期鍵。`id` 是任務 id；`title` 是 App 任務頁顯示的中文名稱；`done` 是 App 現在的完成判定。
- 今天還沒有清單時，App 用打開每日任務頁的同一套邏輯產生並存起來；產生不出來回 `missions: []`。
- 只讀：H5 改不了任務或完成狀態（完成只認 App 自己記的量測與 `gameActivity`）。回傳不含個資。

## 銀足樂齡模式（`aaRpc`，只在 `/game/aa/` 頁面）

不是廣場的通道。「我的」頁的隱藏入口開 `<gameUrl>game/aa/`（`ActiveAgingPage`），那個頁面有：

- `window.silversoleApp.features.activeAging === true`（只有 `aa_me().active` 的帳號才有這個 key；一般帳號根本沒有）。H5 頁自己要檢查，不能只靠入口隱藏。
- `callHandler('aaRpc', { fn, args })` → `{ ok: true, data }` 或 `{ ok: false, reason }`。`fn` 只能是 12 個名字（見 `lib/core/active_aging/aa_bridge.dart`），`args` 的 key 是 08 號文件參數表去掉 `p_`（`session_id`、`rows`、`closed_at`…），多一個 key 就拒絕。`reason`：`signed_out`、`not_member`、`forbidden`、`rate_limited`、`offline`、`invalid`、`too_large`、`closed`。`data` 是伺服器回傳去掉 `ok` 的其餘欄位。
- 相機（只給同 origin，跟遊戲一樣）。這個頁面只能留在 `/game/aa/` 底下，導到別處的請求會被取消。

資料庫：`supabase/migrations/20261113120000_active_aging.sql`（草稿，未套用）；開關 `--dart-define=ACTIVE_AGING_BACKEND=supabase`，沒開之前沒有人有角色。測試：`supabase/tests/aa_rpc_test.mjs`。
