# 粗哥廣場 ↔ App 通道

App 的遊戲分頁（`lib/shared/pages/plaza_tab_page.dart`）用 WebView 開 `<gameUrl>game/plaza/`。廣場網頁跟 App 之間只走這份文件寫的通道；App 端的格式定義在 `lib/shared/providers/plaza_bridge.dart`。

**只服務遊戲自己的網站。**下面的通道（`window.silversoleApp`、`appInfo`、`openFriends`）和相機權限，只給跟 `gameUrl` 同一個 origin（協定、網域、port 都一樣）的頁面；正式版就是 `https://h5.silversole.dongyu.company`。廣場如果在同一個 WebView 裡連到別的網站，那個頁面讀不到 `window.silversoleApp`，呼叫 `appInfo` 拿到 `null`、`openFriends` 拿到 `false`，要相機也會被拒絕。相機以外的權限（麥克風、定位等）一律拒絕。

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
  systemFontScale: 1.0           // 手機「字體大小」設定的倍率（1.0＝預設，1.3、1.5、2.0…）
};
```

`account.username`：App 沒有獨立的「帳號名稱」欄位（登入是 email／Google），所以取 email 的 `@` 前面（`ricky951102@gmail.com` → `ricky951102`）。好友的暱稱是使用者自己取的，不拿來當帳號。登入或登出時 App 會重新送一次 `silversoleapp` 事件。注意 username 只是拿來比對的名字，不同網域的 email 可以有相同的前綴，不能當作身分證明。

**`systemFontScale`**：長輩常把手機字體調到最大。App 自己的字最多放大到 1.3 倍，WebView 的 `textZoom` 固定 100（不會被系統再放大一次），所以網頁字不會跟著系統放大。要讓網頁自己跟著變大，就看這個欄位：大於等於 1.15 時自動開大字模式（使用者手動切換的設定優先）。

並在 `window` 上觸發 `silversoleapp` 事件（`event.detail` 就是上面這個物件）。

網頁也可以主動問：`await window.flutter_inappwebview.callHandler('appInfo')`，回傳同一個物件。

**用瀏覽器直接開廣場時，`window.silversoleApp` 不存在**：好友建築不要畫出來（好友只在 App 裡有）。

## 網頁 → App：打開好友頁

```js
window.flutter_inappwebview.callHandler('openFriends')  // 回傳 true；好友沒開時回傳 false
```

App 會蓋上好友頁；使用者按返回就回到廣場，App 會重新送一次 `silversoleapp` 事件更新紅點。好友頁還開著的時候再呼叫一次，不會疊第二層，一樣回傳 `true`。

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
