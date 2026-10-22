# 粗哥廣場 ↔ App 通道

App 的遊戲分頁（`lib/shared/pages/plaza_tab_page.dart`）用 WebView 開 `<gameUrl>game/plaza/`。廣場網頁跟 App 之間只走這份文件寫的通道；App 端的格式定義在 `lib/shared/providers/plaza_bridge.dart`。

## App → 網頁：現在能顯示什麼

每次頁面載入完、以及數字有變的時候，App 會設定：

```js
window.silversoleApp = {
  features: { friends: true },   // false＝不要顯示好友建築
  friendRequests: 2              // 好友建築上的紅點數字；friends 為 false 時一律 0
};
```

並在 `window` 上觸發 `silversoleapp` 事件（`event.detail` 就是上面這個物件）。

網頁也可以主動問：`await window.flutter_inappwebview.callHandler('appInfo')`，回傳同一個物件。

**用瀏覽器直接開廣場時，`window.silversoleApp` 不存在**：好友建築不要畫出來（好友只在 App 裡有）。

## 網頁 → App：打開好友頁

```js
window.flutter_inappwebview.callHandler('openFriends')  // 回傳 true；好友沒開時回傳 false
```

App 會蓋上好友頁；使用者按返回就回到廣場，App 會重新送一次 `silversoleapp` 事件更新紅點。

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
