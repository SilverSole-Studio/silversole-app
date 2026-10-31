# 足壓分佈：客戶看比例、原始讀數收進開發者模式

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. TDD. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 「分析 → 足壓分佈」給客戶看的是即時熱圖＋前後、內外比例；原始讀數和「範例動作」只在開發者模式出現。原則是「畫面上的數字要是真的，沒有就不顯示」。

**使用者已決定（2026-10-31）：**

| 項目 | 決定 |
|---|---|
| 即時熱圖 | **保留現在的熱圖**給客戶看（使用者：「留原本的就好」） |
| 比例 | 每隻有顯示的腳：「前腳掌 X% ▓░ Y% 腳跟」、「內側 X% ▓░ Y% 外側」，講法跟一分鐘足部健檢結果頁相同 |
| 原始讀數（大拇趾球／小拇趾／腳跟） | 只在開發者模式顯示 |
| 範例動作（合成資料播放） | 只在開發者模式顯示 |
| 沒踩在鞋墊上 | 不顯示數字，改顯示一句提示 |

**開發者模式** = 既有的 `settingsProvider.select((s) => s.firmwareDevMode)`（在「我的裝置」連點韌體那一行切換，正式版也能用）。不另做新開關。

**Base：** 從 `feat/daily-gait`（PR SilverSole-Studio/silversole-app#12）的 `e86e4b1` 開出 `feat/pressure-shares`。兩個分析頁已經是 `ConsumerStatefulWidget`。

**範圍外：** `foot_check_result_page.dart`（足部健檢頁歸 UI 視窗，不碰）、`lib/core/theme`、`foot_pressure_heatmap.dart` 的畫法。

---

## 檔案

| 檔案 | 動作 |
|---|---|
| `lib/core/utils/pressure_shares.dart` | 新增：`PressureShares`（前腳掌占比、內側占比可空）＋`PressureShareWindow`（最近 2 秒滾動平均、站上判斷） |
| `lib/shared/widgets/pressure_share_bars.dart` | 新增：`PressureShareBars` 元件，每隻腳兩條比例條或一行提示 |
| `lib/shared/widgets/pressure_demo_scope.dart` | 改：加 `showMenu`（預設 true）；false 時不畫選單、也不能啟動播放 |
| `lib/shared/pages/analytics_page.dart`、`lib/shared/pages/theme_two/analytics_page_t2.dart` | 改：`_PressurePanel` 讀開發者模式；熱圖＋比例條給所有人，原始讀數與範例選單只在開發者模式 |
| `assets/translations/strings.csv` | 加字串（尾端，英文不含逗號、中文全形標點） |
| 測試 | `test/pressure_shares_test.dart`、`test/pressure_share_bars_test.dart`、更新 `test/analytics_pressure_demo_test.dart` |

---

### Task 1：`PressureShares` 與 2 秒視窗（純 Dart）

**行為規格：**

- `PressureShares.from(List<int> meanPressure)`：輸入 `[大拇趾球, 小拇趾, 腳跟]` 的平均值。
  - `total = 三者相加`；`total < PressureShareWindow.minLoad` → 回傳 null（沒踩在鞋墊上）。
  - `foreRatio = (大拇趾球 + 小拇趾) / total`。
  - `medialRatio = 大拇趾球 / (大拇趾球 + 小拇趾)`；前腳掌負荷 < `total × 0.05` 時為 **null**（只踩腳跟時沒有可信的內外比例，**不能**像 `FootPressureTally` 那樣回 0.5）。
- `PressureShareWindow`（一隻腳一個）：
  - `add(DateTime at, List<int> pressure)`：長度 < 3 的讀數忽略；丟掉比 `at - 2 秒` 更舊的樣本。
  - `shares` getter：視窗內少於 `minSamples`（5 筆）→ null；否則用平均值算 `PressureShares.from`。
  - `minLoad`：常數 300（原始計數，三顆相加），跟步態偵測的 `GaitConfig.minLoadRange` 同一量級；doc 註明是初始值、要用真資料調。
  - `clear()`。

**測試（先寫、先看它失敗）：** `test/pressure_shares_test.dart`

- 穩定站立 `[900, 600, 1500]` × 10 筆 → foreRatio 0.5、medialRatio 0.6。
- 只踩腳跟 `[0, 10, 2000]` → foreRatio ≈ 0.005、medialRatio null。
- 沒踩 `[20, 10, 30]` → shares null。
- 少於 5 筆 → null。
- 超過 2 秒的舊樣本不算：先放 10 筆 `[3000,0,0]`，3 秒後放 10 筆 `[0,0,3000]` → foreRatio 0。
- 長度不足 3 的讀數被忽略。

Commit：`feat(pressure): load shares over the last two seconds`

### Task 2：`PressureShareBars` 元件

**行為規格：**

- 參數：`feet`（`FootView`）、`right`（`PressureShares?`）、`left`（`PressureShares?`）、`rightConnected`、`leftConnected`（bool）。
- 每隻有顯示的腳一區；`FootView.both` 時區塊上方標「左腳／右腳」（沿用 `left_foot`、`right_foot`）。
- 有 shares：兩條比例條。
  - 前後：左 `forefoot`（前腳掌）、右 `foot_check_rearfoot` 的意思但用「腳跟」→ 新字串 `pressure_share_heel`（en "Heel"，zh「腳跟」）。
  - 內外：沿用 `foot_check_medial`（內側）、`foot_check_lateral`（外側）；medialRatio null 時這一條換成一行小字 `pressure_share_side_none`（en "Inner and outer split shows once the forefoot is loaded"，zh「前腳掌踩下去才看得到內外比例」）。
  - 比例條外觀照 `foot_check_result_page.dart` 的 `_SplitBar`（標籤 X%｜LinearProgressIndicator｜Y% 標籤，四捨五入一次、兩邊相加 = 100）。**在新檔裡自己實作**，不要改或 import 健檢頁的私有類別。
- 沒有 shares 但鞋墊有連：一行 `pressure_share_stand`（en "Stand on the insole to see the split"，zh「站上鞋墊才看得到比例」）。
- 鞋墊沒連：一行 `pressure_share_no_sole`（en "No insole connected"，zh「鞋墊未連線」）。
- 不出現任何評語（不寫偏前、偏外、內旋等）。

**測試：** `test/pressure_share_bars_test.dart`（掛 EasyLocalization 的測試一律用 `test/helpers/translations.dart` 的 `settleTranslations(tester)`，因為 strings.csv > 50 KB）

- 右腳 shares(fore 0.38, medial 0.6) → 看得到「Forefoot 38%」「62% Heel」「Medial 60%」「40% Lateral」。
- medialRatio null → 看得到 side_none 提示、看不到 Medial。
- shares null＋已連 → stand 提示；未連 → no_sole 提示；兩者都沒有任何 `%`。
- `FootView.both` → 看得到「Left foot」「Right foot」標題。

Commit：`feat(pressure): split bars for forefoot-heel and inner-outer`

### Task 3：範例選單可以關掉

`PressureDemoScope` 加 `final bool showMenu`（預設 true，現有呼叫端行為不變）。`showMenu == false`：`header` 給 `const SizedBox.shrink()`；若播放中途 showMenu 變成 false（開發者模式被關掉），停止播放、回到即時資料（在 `didUpdateWidget` 處理）。

**測試：** 在 `test/analytics_pressure_demo_test.dart` 加一個用 `PressureDemoScope(showMenu: false, ...)` 的案例：找不到範例選單（用現有測試找選單的同一種方式）。

Commit：`feat(pressure): let the sample menu be hidden`

### Task 4：分析頁接上

兩個主題的 `_PressurePanel` 改成 `ConsumerStatefulWidget`（或讀 provider 的方式照檔內慣例）：

- `devMode = ref.watch(settingsProvider.select((s) => s.firmwareDevMode))`。
- 每隻腳一個 `PressureShareWindow`，存在 State 裡；每次 builder 拿到新的 `reading`（`reading.right` / `reading.left` 跟上一次是不同的 List 物件）就 `add(clock.now(), ...)`。播放範例時餵的是範例資料（開發者模式才會發生），切換 `feet` 或範例開關時 `clear()`。
- 版面（由上到下）：`header`（只有開發者模式才有範例選單）→ 熱圖（不變）→ `PressureShareBars` →（開發者模式才有）一個小標「原始讀數（開發者模式）」`pressure_raw_title` ＋ 現有 `PressureReadouts`。
- `rightConnected` = `reading.hasData`；`leftConnected` = `reading.left != null`（跟 `PressureReadouts` 現在判斷「--」的方式一致）。
- 頁面類別的 doc comment 更新：熱圖與比例是給所有人的，原始讀數與範例只在開發者模式。

**測試：** 更新 `test/analytics_pressure_demo_test.dart`：

- 預設（開發者模式關）：看不到範例選單、看不到 `kSensorLabels` 原始讀數標籤；有即時資料時看得到比例條。
- 開發者模式開（override `settingsProvider` 讓 `firmwareDevMode: true`）：範例選單與原始讀數都在。
- 原本依賴範例選單或原始讀數的測試，改成在開發者模式下跑，**斷言內容不變**；在報告中逐一列出改了哪些。

驗證：`flutter analyze lib test`（只會有 `tool/friends_screenshots_test.dart` 原本的 2 個問題）＋全部 `flutter test`。

Commit：`feat(pressure): customers see shares, raw readings move to developer mode`

---

## 完成條件

- [ ] 開發者模式關：足壓分佈只有熱圖＋比例條（或提示），沒有原始數字、沒有範例選單
- [ ] 開發者模式開：多出範例選單與原始讀數
- [ ] 沒踩、沒連時沒有任何百分比
- [ ] 全部測試通過；分支只在本地，不推
