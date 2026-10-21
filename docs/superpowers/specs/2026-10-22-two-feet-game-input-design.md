# 雙腳遊戲輸入——設計

- 日期：2026-10-22
- 狀態：設計待使用者審閱
- 範圍：兩個 repo。App（本 repo）把兩隻鞋墊的資料都送進遊戲；H5 遊戲（`silversole-html-games-demo`）的 `engine/sole_input.js` 用這些資料判定左右。
- 依據：雙腳連線（`2026-10-20-double-feet-design.md`）已經完成，兩隻鞋墊各自的 `footSide` 存在配對清單裡。

## 使用者已決定的事

| 項目 | 決定 |
|---|---|
| 目的 | 現有遊戲不變，讓雙腳時的判定更準、更像真的走路。不做新玩法 |
| 單隻鞋墊 | 保留，現有使用者還在用 |
| FSR | 讀數是準的，大部分判定改用壓力 |
| holdLR（重心左／中／右） | 單隻：維持現在的角度判定。雙腳：比較兩腳的壓力 |
| tapLR（左右踏步） | 單隻：改用壓力，這隻腳落地算自己那邊，抬起時推論另一邊。雙腳：左腳落地算左，右腳落地算右 |
| tapSingle（提腳跟／跳） | 維持單腳 IMU（`roll` 跌破門檻）。雙腳時任一腳觸發都算，同一跳只算一下 |

## 1. 現況

- **App：** `GameWebViewPage` 和 `PlazaTabPage` 只讀 `telemetryViewProvider`（主要那隻鞋墊）。每來一筆就把最新一筆（已經過 10 筆移動平均）用 `window.onImuData(json)` 送進網頁，資料裡沒有左右腳。
- **H5：** `sole_input.js` 只吃一條資料，只讀 `pitch` / `roll`。之前的 FSR 判定整段被拿掉了。遊戲只看 `controls`（`holdLR` / `tapLR` / `tapSingle`），收到的是 `onLeftDown/Up`、`onRightDown/Up`、`onTap`。這個介面不變，所以遊戲一行都不用改。

## 2. 判定放在哪裡

判定放在 H5 的 `sole_input.js`，App 只負責轉送資料。

- 判定規則跟遊戲在同一個 repo。調門檻只要部署 H5，不用等 App 上架。
- 今天就是這樣分工，鏡頭輸入（`camera_input.js`）也是同一種外掛方式。
- 不採用另一種做法：「App 判定好事件再送進網頁」。那樣每調一次門檻都要發 App，而且 App 得知道每個遊戲的 `controls`。

## 3. App → 網頁的資料合約

新增一個網頁端函式，舊的保留：

```js
window.onSoleSample({
  foot: "left" | "right" | null,   // 配對清單上的 footSide；還沒指定就是 null
  primary: true | false,           // 是不是主要那隻（primarySoleKeyProvider）
  pitch, roll,                     // 度，韌體融合好的
  pressure: [hallux, littleToe, heel], // 原始值、沒有平均過；順序已經過 fixPressureChannels
  ax, ay, az, gx, gy, gz, battery_percent, is_charging,
})
```

- **每隻鞋墊的每一筆都送**，兩隻都連著就是兩條資料交錯送進來。
- **壓力送原始值：** 移動平均約有 0.2–0.5 秒延遲，踏步判定吃不消。平滑交給 H5，依判定的需要自己做。
- **新舊相容**：App 送出的 JS 是
  `window.onSoleSample ? onSoleSample(J) : (P && window.onImuData && onImuData(J))`
  （`P` 是這筆是否來自主要那隻），所以：

| 組合 | 結果 |
|---|---|
| 新 App ＋ 舊 H5 | 沒有 `onSoleSample`，只送主要那隻到 `onImuData`，跟今天一樣 |
| 舊 App ＋ 新 H5 | 只會呼叫 `onImuData`。新的 `sole_input.js` 把它當成 `foot: null`、`primary: true` 的單隻資料 |
| 新 App ＋ 新 H5 | 雙腳 |

  因此 H5 可以先上線，App 之後再發版。

## 4. App 端

- **`SoleSampleBus`（`lib/core/ble/sole_sample_bus.dart`，新）：** 原始樣本的廣播串流，每筆帶 `identityKey`，做法跟 `fallEventBusProvider` 一樣。
  - 在 `ble_foreground_controller.dart` 呼叫 `updateImuNotifyData` 的同一個地方發出。
  - `DebugFakeSole` 也從這裡送，debug 版不用接鞋墊也能測雙腳。
- **`soleSampleScript()`（純函式，新）：** 輸入原始樣本、`foot`、`primary`，輸出上面那段 JS 字串，寫單元測試。
- **網頁轉送（共用）：** `GameWebViewPage` 和 `PlazaTabPage` 現在各寫了一份轉送，改成共用一份：
  - 訂閱 `SoleSampleBus`。
  - 從 `settingsProvider` 查 `footSide`，從 `primarySoleKeyProvider` 查是不是主要那隻。
  - 頁面載入後才送，跟現在的 `_ready` 一樣。
- 不改：`telemetryViewProvider`、`LiveTelemetryNotifier`、移動平均、圖表。

## 5. H5 端（`engine/sole_input.js`）

### 5.1 結構

拆成兩層：

- **`SoleJudge`（純邏輯）：**
  - 輸入：`(sample, 時間)` 和 `controls`。
  - 輸出：`press(side)` / `release(side)` / `tap()` 事件。
  - 不碰 DOM、不讀時鐘，可以在 node 裡測。
- **外殼：** 掛 `window.onSoleSample` / `window.onImuData`，接上 `GameHost`，顯示 `?sole=debug` 的除錯面板。

### 5.2 每隻腳的狀態與模式切換

- 每隻腳分開記：最後收到的時間、角度，以及壓力的平滑值和基準。`foot: null` 的資料記在「未知腳」。
- **雙腳模式：** 左右兩隻都在 `staleMs`（1500 ms）內有資料。
- **單隻模式：** 其他情況，用的那條依序是：
  1. `primary: true` 的那條。
  2. 最近有資料的那條。

  這隻腳的左右依序取：
  1. `foot`。
  2. `?foot=`。
  3. 都沒有就預設左。
- **切換模式時**（例如一隻斷線）：先放開按住的那一邊，重設新模式的基準，不會留下卡住的按鍵。

### 5.3 壓力的處理

- **每隻腳的「負重」** ＝ 三顆加總。
- **先平滑**：指數平滑，時間常數約 60 ms（`pressSmoothMs`），只濾雜訊，不像 App 那樣拖 0.5 秒。
- **站立基準**：每場開始（`bind`）後前 `calibMs`（600 ms）內的平均負重，也就是「站好 → 按開始」這個動作本身就是校正。這段時間不送壓力判定的事件（角度判定照常）。
  - 之後只在「站正、兩腳都著地」時才慢慢跟隨，跟現在角度的中立基準同一個做法。
- **正規化：** 用 `load = 負重 / 站立基準`，雙腳站好時每隻約 1，抬起約 0，單腳撐全身約 2。這樣不同鞋墊的感測器靈敏度差異會被抵掉。

### 5.4 三種操作

**holdLR**

- **雙腳：**
  - 計算 `share = loadL / (loadL + loadR)`。
  - `share ≥ 0.62` 算靠左，`≤ 0.38` 算靠右。
  - 回到 0.45–0.55 之間算站正（放開）。
  - 中間是遲滯區，維持現狀。
- **單隻：** 維持現在的角度判定，程式不動。

**tapLR**

- **踩一下（每隻腳分開判定）：**
  - `load` 跌破 `liftLoad`（0.35）時，記為「抬起」。
  - 抬起之後，`load` 回升超過 `landLoad`（0.7）時，算這隻腳「落地」，送一次 `press(這隻腳)`。
  - 兩次落地至少間隔 `refractoryMs`（180 ms）。
- **雙腳：** 左腳落地送左，右腳落地送右，不再推論。
- **單隻：**
  - 這隻腳落地，送 `press(自己那邊)`。
  - 這隻腳抬起，代表另一腳在撐，送 `press(另一邊)`，也就是推論的那一下。
  - 這跟老街各關現在「量到的腳＋推論的另一腳」行為一致。

**tapSingle**

- **單隻：** 維持現在的 `roll` 門檻判定，程式不動。
- **雙腳：**
  - 兩隻腳各自做一樣的 `roll` 判定，各自上膛。
  - 任一腳觸發就送 `tap()`，`jumpRefractoryMs`（400 ms）是兩腳共用的。
  - 所以雙腳一起跳只算一下，左右腳交替提踵則各算一下。

### 5.5 參數

- 上面括號裡的數字都是初始值，放進 `CFG`。
- 跟現有參數一樣可以用網址調，例如 `?liftLoad=0.3&landLoad=0.75`。
- 最後的值要穿著鞋墊實測後再定。

### 5.6 除錯面板（`?sole=debug`）

- **每隻腳：** 左右、是否 fresh、`load`、平滑後負重、站立基準、是否抬起。
- **整體：** 目前是雙腳還是單隻、`share`、最後一個事件。
- debug 版 App 的網址本來就會帶 `?sole=debug`。

## 6. 錯誤與邊界

| 情況 | 行為 |
|---|---|
| 兩隻都連著，但其中一隻還沒指定左右（`foot: null`） | 用單隻模式，取 `primary` 那條。App 本來就會在雙腳連上時跳出左右腳校正 |
| 遊戲中一隻斷線 | 1.5 秒內沒資料就切到單隻，放開按住的鍵；它回來時重新取基準，再回到雙腳 |
| 兩隻都斷線 | 跟現在一樣當成離線，不送事件 |
| 開始時沒站好（基準取到很小的值） | 基準低於 `minBaseline`（初始值：站立負重的原始加總 200，實測後再定）時不送壓力事件，除錯面板顯示「請站好再開始」。holdLR 單隻和 tapSingle 不受影響 |
| 韌體沒送壓力（舊韌體或資料短少） | 那隻腳的壓力判定不啟用；tapLR 退回現在的角度踏步 |

## 7. 測試

- **App：**
  - `soleSampleScript()` 的單元測試：`foot`、`primary`、JSON 內容、新舊函式的分支。
  - 轉送的測試：兩隻鞋墊的樣本都有送出，`footSide` 和主要裝置都標對。
- **H5：**
  - 新增 `tools/sole_judge_test.mjs`，用 `node --test` 跑。
  - 用合成的兩腳壓力和角度序列測：雙腳 holdLR 的左、中、右和遲滯；雙腳 tapLR 左右交替與不應期；單隻 tapLR 的推論；雙腳 tapSingle 同時跳只算一下；一隻斷線切單隻並放開按鍵；舊 `onImuData` 相容。
  - `tools/smoke.mjs --sole` 照跑，確認沒有爆。
- **實機：** 兩隻鞋墊各玩一款 holdLR（滑雪）、tapLR（腳踏車）、tapSingle（帶團跳），再拔掉一隻確認會切單隻，然後依實測調參數。

## 8. 上線順序

1. **H5：** 開分支並開 PR，用預覽站測，用 debug 版 App 指向預覽站：`--dart-define=GAME_URL=…`。合併後，舊 App 還是走單隻，行為不變。
2. **App：** 在 `main` 上做，跟著下一個 rc 送到 Play 封閉測試。
3. **文件：** 更新 App 的 `CLAUDE.md`（遊戲轉送那段），以及 `sole_input.js` 檔頭的說明。
