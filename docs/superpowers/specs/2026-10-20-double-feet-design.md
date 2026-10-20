# 雙腳串接（設計）

- 日期：2026-10-20
- 狀態：設計已核准，實作計畫待寫
- 範圍：子專案 ③。承接子專案 ①（`2026-10-11-sole-device-id-design.md`，它把「左右腳指定」明確排除在外）與 ②（韌體 OTA）。本次做到：兩隻鞋墊同時連線、即時資料依腳別分流、以「踩一下左腳」指派腳別。雲端 schema、步態左右分析的真實資料來源不在範圍。
- 依據：韌體 repo `silversole_firmware_embassy_lab` 全文搜尋 `foot` / `side` / `is_left` **零命中** —— 韌體沒有左右腳概念，兩隻跑同一份映像，只能靠 chip ID 區分，所以腳別必須由 App 指派並持久化。

## 背景

UI 層其實已經準備好了：`FootPressureHeatmap` 有 `leftPressure` 參數與 `FootView.{left,right,both}`，`PressureReadouts` 在沒有資料時顯示 `--`。缺的是資料來源 —— `PressureReading.left` 目前只有 demo clip（`assets/foot-pressure-heatmpt-samples/synthetic_walk_pair_30s.json`）會餵，真實 BLE session 永遠是 null。

而 BLE 管線從頭到尾假設「單一隻鞋墊」：

| 層 | 現況 |
|---|---|
| `BleConnectionService` | 單一 session（`_device` / `_service` / `_stateSub` / `_sessionEpoch`） |
| `bleForegroundControlProvider` | 單一 `boundDevice`、單一搜尋迴圈，`pickSole()` 只挑一隻 |
| `LiveTelemetryState` | 單一 100 筆滾動視窗，沒有腳別維度 |
| `BlePairedDevice` | 只有 `isPreferred`，沒有腳別欄位 |
| 通知 / `deviceOnlineProvider` / `connectedSoleProvider` / OTA | 全部指「那一隻」 |

### 前提查證：flutter_blue_plus 2.1.1 的鎖

本專案鎖定 `flutter_blue_plus 2.1.1`。該版**每個 GATT 操作都搶同一把 `"global"` mutex**（`_MutexFactory.getMutexForKey("global")`，見 `lib/src/bluetooth_device.dart`）：`connect`、`discoverServices`、`read`、`write`、`requestMtu`、`setNotifyValue` 全部跨裝置序列化。官方 README 提到的 `FlutterBluePlus.setOperationQueueMode(OperationQueueMode.perDevice)` 在 2.1.1 與 2.2.1 都**還不存在**（僅 master）。

推論：

1. 雙連線可行 —— notify 不走 mutex，兩條 50 Hz 串流互不阻擋。
2. 兩隻的 handshake 會互相排隊。可接受（handshake 數百 ms ~ 2 s），但搜尋迴圈必須序列化地 attach，不能並行丟兩個 `attachTo`。
3. OTA 的 page write 與另一隻的 handshake 搶同一把鎖 —— 這是 §8 決定「OTA 期間主動 detach 另一隻」的唯一理由。

## 設計

### 1. 核心原則

不開特例分支：管線從「單一隻」改成**以 `identityKey` 為索引的 N 隻**，`FootSide` 只是疊在上面的一層對應關係。連一隻時行為與今天**逐字相同**；第二隻出現就自動一起連。同時連線上限 `maxSoles = 2`。

### 2. 資料模型

- 新 `lib/shared/models/foot_side.dart`：`enum FootSide { left, right }`，附 `labelKey`（`left_foot` / `right_foot`，CSV 已有這兩個 key）。
- `BlePairedDevice` 新增 `FootSide? footSide`（null = 未指派）。需跑 `dart run build_runner build --delete-conflicting-outputs`。
- `isPreferred` **保留**，語義收窄：不再決定「連哪一隻」，只決定單隻 UI（韌體卡、狀態卡、OTA 目標）指的是哪一隻。本節就是這件事的權威 —— `primarySoleKeyProvider` 的順序必須 `isPreferred` 優先（見 §6 的修訂）。
- 既有已配對紀錄 `footSide` 為 null → 單腳行為原樣保留，**不需要遷移腳本**。

### 3. 腳別指派的持久化（`save_service.dart`、`settings_provider.dart`）

- `SettingsNotifier.setFootSide(String identityKey, FootSide? side)`。
- **互斥**：指派某隻為左腳時，清掉其他所有紀錄的左腳旗標（同一腳不能有兩隻）。寫成純函式 `assignFootSide(list, identityKey, side)` 方便單測。
- `AppSettings.soleFor(FootSide side)` → `BlePairedDevice?`。
- `AppSettings.unassignedPairedSoles` → 腳別為 null 的清單，校正流程的輸入。

### 4. BLE 連線層（`lib/core/ble/sole_session_registry.dart`，新檔）

`BleConnectionService` 的狀態本來就全是 instance 欄位，**服務本身幾乎不用改**。要改的是它被當 singleton 用。

```dart
/// 一隻鞋墊的連線與其 per-sole 狀態。
class SoleLink {
  final BleConnectionService service;
  BlePairedDevice device;
  Timer? watchdog;
  int imuFailCount;
}

/// identityKey -> SoleLink。
class SoleSessionRegistry {
  SoleLink link(String identityKey, BlePairedDevice device);
  SoleLink? lookup(String identityKey);
  Iterable<SoleLink> get links;
  bool get anyConnected;
  int get connectedCount;
  Future<void> detach(String identityKey);
  Future<void> detachAll();
}
```

`bleConnectProvider` 改成提供 `SoleSessionRegistry`（檔名與 provider 名沿用 `ble_connection_provider.dart`，避免無謂的 rename diff）。

### 5. 編排層（`ble_foreground_controller.dart`，594 行）

目前 closure 裡 per-sole 與全域狀態混在一起。拆法：

- per-sole 狀態搬進 `SoleLink`（§4）。
- 所有 handler 加一個 `String key` 參數：`onImu(key, value)`、`onRecordImu(key, value)`、`onFallDetect(key, value)`、`onDeviceStatus(key, value)`。`onFallDetect` 與 `onDeviceStatus` 原本從 `boundDevice` 取裝置，改成從 `registry.lookup(key)!.device` 取。
- **全域**只留一份：掃描迴圈（`searching` / `retryTimer` / `searchAttempt`）、`held`、通知節流 `notified`、`readyWaiter`。
- watchdog 改成 per-sole（放在 `SoleLink`）。

#### 5.1 `pickSoles`（`sole_scanner.dart`）

`pickSole()` → `pickSoles(candidates, paired:, max:)` 回傳排序後清單。優先序沿用今天，再加腳別：

1. 已指派腳別的鞋墊（左、右各取一），在空中就選。
2. 主要裝置（`isPreferred`）。
3. 其他已配對鞋墊，訊號強者先。
4. 最後手段：無法識別者（沒有 ID 的鞋墊；或配對清單裡還有舊紀錄時的任何鞋墊）。

同一隻不會佔兩個名次；取到 `max` 就停。`pickSole()` 保留為 `pickSoles(..., max: 1).firstOrNull` 的薄包裝，現有 `test/sole_scanner_test.dart` 不會壞。

> 使用者實際擁有 3 隻鞋墊（2 隻借出）。第 1 條優先序就是為此：3 隻都配對過時，已指派左右腳的那兩隻優先連上。

#### 5.2 搜尋迴圈

- 結束條件從「已連上就不找」改成「`registry.connectedCount < desiredCount` 就繼續找」，`desiredCount = min(paired.length, maxSoles)`。
  - 單隻配對 → 行為與今天逐字相同。
  - 兩隻配對、只連上一隻 → 沿 15/30/60 s backoff 繼續找另一腳。
- 一次掃描結果可 attach 多隻，但**依序 await**（§背景推論 2，global mutex）。
- 已不在配對清單裡的 link → `registry.detach(key)`。
- 全部 unpair → `detachAll()` + `stopBleService()`（今天的行為）。

### 6. Telemetry 分流

- `liveTelemetryProvider` → `NotifierProvider.family<LiveTelemetryNotifier, LiveTelemetryState, String>`，key = `identityKey`。
- 新 `lib/shared/providers/foot_telemetry_provider.dart`：
  - `footTelemetryProvider(FootSide)` —— 查 settings 把 side → identityKey 再 watch family；該腳沒鞋墊時回 `const LiveTelemetryState()`。
  - `primaryTelemetryProvider` —— `preferredDevice` → 否則右腳 → 否則第一隻已配對的。
    > 修訂（2026-10-20，最終審查）：原文寫「右腳優先」，與 §2 矛盾 —— §2 說 `isPreferred` 保留下來的語義就是「決定單隻 UI 指哪一隻」，但右腳優先會讓 `isPreferred` 在雙腳都已校正時永遠踩不到：左腳的韌體因此無法檢查或更新，首頁裝置卡也會掛著一隻的名字顯示另一隻的電量。**這一點以 §2 為權威** —— 單隻 UI 指哪一隻，由使用者明確挑的主要裝置決定，右腳只是沒挑時的回退。熱力圖不受影響：`rightFootTelemetryProvider` 只在「右腳沒有鞋墊」時才走回退，而那時這個順序裡的右腳那一項本來就是 null。
  - `latestTelemetryAtProvider` —— 各 sole `updatedAt` 的最大值。
- `telemetryViewProvider` 改成轉發 `primaryTelemetryProvider`。**現有 9 個消費端（`imu_chart_section`、`game_webview_page`、`foot_check_session_page`、`home_device_status_section`、`devices_page`、`devices_page_t2`、`home_body_t2`、`record_imu_chart_section`、`analytics_detail_page`）一行都不用改，行為等於今天。**
- `deviceOnlineProvider` 改成「任一已連鞋墊有新鮮資料」：吃 `latestTelemetryAtProvider`，其餘計時器邏輯與 `firmwareUpdateProvider.busy` 的 gate 不動。
- `record`（錄製）仍只跟 primary 那隻，見 §10。

### 7. 壓力熱力圖接上真實左腳（`pressure_demo_scope.dart`）

- `right` = `footTelemetryProvider(FootSide.right)` 最新一筆的 `pressure`；
- `left` = `footTelemetryProvider(FootSide.left)` 最新一筆的 `pressure`，沒有該腳就 null；
- demo clip 播放時仍整組覆蓋兩腳（今天的行為）。
- 更新 `PressureReading.left` 與 `FootPressureHeatmap.leftPressure` 的 doc comment —— 「永遠是 null」不再成立。

### 8. 校正流程：踩一下左腳

#### 8.1 純邏輯（`lib/core/ble/foot_side_calibration.dart`，可單測）

```dart
class FootSideCalibrator {
  FootSideCalibrator({
    this.baselineSamples = 50,   // 50 Hz 約 1 秒
    this.triggerDelta = 300,
    this.holdSamples = 3,
    this.arbitration = const Duration(milliseconds: 200),
    this.ambiguityRatio = 0.2,
  });

  /// 餵一筆樣本；決定出來才回傳非 null。
  FootSideDecision? add(String soleKey, int pressureSum, DateTime at);
  void reset();
}

@immutable
class FootSideDecision {
  const FootSideDecision.left(String this.leftKey) : ambiguous = false;
  const FootSideDecision.ambiguous() : leftKey = null, ambiguous = true;
  final String? leftKey;
  final bool ambiguous;
}
```

演算法（確定性，用 `clock` 套件的 fake clock 即可測）：

1. 每隻先收 `baselineSamples` 筆靜止樣本 → baseline = 平均值。
2. 某隻連續 `holdSamples` 筆滿足 `sum - baseline >= triggerDelta` → 視為「被踩」。
3. 第一隻被踩時開一個 `arbitration` 窗（200 ms），期間記錄**兩隻**的 peak delta。
4. 窗結束比較：次高者 peak >= (1 - `ambiguityRatio`) x 最高者 peak → `ambiguous`（要求重踩）；否則最高者 = **左腳**，另一隻自動 = 右腳。
5. 超時由 UI 負責（15 s）→ 退到手動指派。

#### 8.2 觸發與 UI

- 觸發：**兩隻都連上且有未指派腳別時自動彈 modal**。由 `lib/shared/providers/foot_side_calibration_provider.dart` 判斷，`app.dart` 監聽並 push route。需防重入（同一次連線只彈一次）。
- 完成前熱力圖**不畫雙腳**（維持單腳 + 空輪廓）。
- `lib/shared/pages/foot_side_calibration_modal.dart`：兩條即時壓力條（以 `BlePairedDevice.shortId` 標示）+「請用左腳踩一下」+ 15 s 倒數 +「手動指派」+「重做」。
- **留可關閉的出口**（返回鍵 / 「稍後再說」）：FSR 故障時不能把使用者卡死；關閉後下次「兩隻都連上」的轉換再提示。

### 9. 前景通知（`sole_notification_text.dart`）

擴成接受清單：`左 85% · 右 92%` / `左腳離線 · 右 92%`。**單隻時輸出保持逐字不變**，`test/sole_notification_text_test.dart` 現有案例照過。

### 10. OTA

受 §背景推論 3 約束：

- `SoleConnectionController.dfuLink()` → `dfuLink(String identityKey)`；`reacquire(target, timeout:)` 補上 key。
- `hold()` / `release()` **維持全域**，且 hold 期間**主動 detach 另一隻**（page write 與另一隻的 handshake 搶同一把 mutex，放著會拖慢甚至打斷傳輸）。`release()` 後由搜尋迴圈找回來。
- `connectedSoleProvider` 旁邊新增 `connectedSolesProvider`（`Map<String, ConnectedSole>`）；`connectedSoleProvider` 保留為 primary 那隻，`firmware_update_page.dart` 不用改。
- `firmwareCheckProvider` / `firmwareUpdateProvider` 仍只對 primary。兩腳都要更新 = 跑兩次。**不做並行 OTA。**

### 11. 假的第二隻鞋墊（`kDebugMode` only）

使用者目前只有 1 隻鞋墊在手（另 2 隻借給團隊成員），校正 modal 幾乎無法手測，所以需要一個開發用的假鞋墊。

`lib/core/ble/debug_fake_sole.dart`：**不假造 BLE**，而是在 `SoleLink` 層造假 —— 一個 `FakeSoleLink` 以 50 Hz timer 把合成的 `ImuNotifyDataModel` 推進該 sole 的 telemetry notifier。

- 預設**靜止**（壓力接近 0 加小雜訊），這樣校正不會自己判定。
- 除錯面板提供「踩一下」按鈕 → 一次 400 ms 的壓力尖峰，用來驅動校正流程。
- 走路資料需要時重用既有的 `synthetic_walk_pair_30s.json` 左腳軌跡。
- 入口：裝置頁一個 `kDebugMode` 限定的 tile（「加入假的第二隻鞋墊」），會寫入一筆 identityKey 為 `FAKE…` 的配對紀錄並啟動假 link。

### 12. 檔案清單

新增 —— 實作（7）：
`lib/shared/models/foot_side.dart`、`lib/core/ble/sole_session_registry.dart`、`lib/core/ble/foot_side_calibration.dart`、`lib/core/ble/debug_fake_sole.dart`、`lib/shared/providers/foot_telemetry_provider.dart`、`lib/shared/providers/foot_side_calibration_provider.dart`、`lib/shared/pages/foot_side_calibration_modal.dart`

新增 —— 測試（3）：
`test/foot_side_calibration_test.dart`、`test/foot_side_assign_test.dart`、`test/foot_telemetry_provider_test.dart`

修改（18）：
`ble_paired_device_model.dart`(+regen)、`save_service.dart`、`settings_provider.dart`、`sole_scanner.dart`、`ble_connection_provider.dart`、`ble_foreground_controller.dart`、`live_telemetry_notifier.dart`、`telemetry_view_provider.dart`、`device_online_provider.dart`、`connected_sole_provider.dart`、`sole_connection_controller.dart`、`firmware_update_provider.dart`、`sole_notification_text.dart`、`pressure_demo_scope.dart`、`devices_page.dart`、`theme_two/devices_page_t2.dart`、`app.dart`、`assets/translations/strings.csv`

既有測試擴充（2）：`test/sole_scanner_test.dart`、`test/sole_notification_text_test.dart`

合計約 30 個檔案。核心是 §5（編排層）與 §6（telemetry 分流）。

### 13. i18n

`strings.csv` 新增 key：`foot_side_calibration_title`、`foot_side_calibration_prompt`、`foot_side_calibration_hint`、`foot_side_calibration_ambiguous`、`foot_side_calibration_timeout`、`foot_side_assign_manually`、`foot_side_retry`、`foot_side_later`、`foot_side_unassigned`、`debug_add_fake_sole`、`debug_fake_sole_stomp`。`left_foot` / `right_foot` 已存在。

## 不在這次範圍

- 並行 OTA（兩腳都要更新就跑兩次）。
- 雙腳錄製 —— `record-request` 仍只寫給 primary 那隻，`record` 狀態也只跟它。
- 用真實資料餵步態左右比較圖（`gait_analysis_data.dart` 的左右站立相分佈仍是罐頭資料）。
- per-foot 雲端上傳 —— 上傳佇列本來就還沒實作（`TelemetryIngestService` 是孤兒）。心跳 / device status 上傳本來就以裝置為單位，兩隻各自上傳即可，不需改動。
- Supabase schema：`devices` 表沒有腳別欄位，本次不加。

## 測試

| 檔案 | 內容 |
|---|---|
| `test/foot_side_calibration_test.dart`（新） | 左先踩、右先踩、兩隻同時（ambiguous）、都沒反應（undecided）、baseline 未收滿時不判定 |
| `test/sole_scanner_test.dart`（擴） | `pickSoles` 的優先序（已指派腳別優先）、`max` 上限、同一隻不佔兩名次、`pickSole` 行為不變 |
| `test/sole_notification_text_test.dart`（擴） | 雙隻文案、單隻輸出逐字不變 |
| 新 `test/foot_side_assign_test.dart` | `assignFootSide` 純函式的互斥性 |
| 新 `test/foot_telemetry_provider_test.dart` | side → sole 對應、未指派時 `primaryTelemetryProvider` 的回退順序 |

> widget test 注意 `easy_localization` 的既有坑：prefs mock 必填，且一個測試檔只能 mount 一次 `EasyLocalization`。

驗證：`flutter analyze` + `flutter test` 全綠。實機雙腳驗收由使用者（或持有另外兩隻的團隊成員）執行。

## 文件

實作完成後更新 `CLAUDE.md` 的「The BLE → telemetry pipeline」一節：連線編排從單一 session 改成 registry、telemetry 以 identityKey 分流、腳別指派的來源與持久化、OTA 期間 detach 另一隻的理由。
