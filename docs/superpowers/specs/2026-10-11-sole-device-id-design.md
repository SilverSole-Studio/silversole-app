# 鞋墊識別改用 device ID（設計）

- 日期：2026-10-11
- 狀態：已核准，實作中
- 範圍：子專案 ①。子專案 ② 是韌體 OTA，它靠這裡的 device ID 在重開機後找回同一隻鞋墊。Supabase 主鍵、左右腳指定不在這次範圍。
- 依據：韌體 repo `docs/ota-app-handoff.md` §3.7，以及韌體 commit `547ef62`（feat: expose a per-chip device ID over BLE）

## 背景

App 目前用藍牙位址 `remoteId` 辨識鞋墊，因此有三個問題：

1. 配對清單每次鞋墊重開機就多一筆。CLAUDE.md 的說法是 MAC 每次開機都會換。
2. 附近有兩隻以上鞋墊時分不出誰是誰。掃描清單裡全部都叫 `SilverSole`。
3. 只要配對過任何一隻，自動連線就會去連附近**訊號最強的任何鞋墊**，包含別人的。

新韌體給每隻鞋墊一個永久不變的 ID：nRF52840 的 64-bit FICR DEVICEID，以 16 個大寫 hex 字元表示。燒錄和 OTA 都不會改變它，有兩個地方可以拿到：

| 時機 | 位置 | 格式 |
|---|---|---|
| 掃描時 | 廣播 Manufacturer Specific Data（AD `0xFF`） | 公司代碼 2 bytes（LE，目前是 `0xFFFF`，量產前會換）＋ ID 8 bytes（BE）。fbp 裡是 `manufacturerData[0xFFFF]` = 8 bytes |
| 連線後 | Device Information Service `0x180A` → Serial Number String `0x2A25` | UTF-8，16 字元 |

**限制**：有些鞋墊在使用者手上，還跑著沒有 ID 的舊韌體，所以一定要保留沒有 ID 時的備援。

## 設計

### 身分

- 鞋墊身分以 device ID 為準；沒有 ID（舊韌體）時才退回用 `remoteId`。
- `BlePairedDevice.remoteId` 的意思改成「最後一次看到的藍牙位址」，每次連線都會更新。
- `BlePairedDevice.identityKey`：有 `deviceId` 就用它，否則用 `remoteId`。ID 是 16 個 hex 字元、MAC 帶冒號，兩者不會撞。
- `BlePairedDevice.deviceId` 原本來自從未被填值的舊 characteristic，一直是空的，現在改成存晶片 ID。
- `AppSettings.deviceId`（使用者手動輸入的雲端綁定 ID）**不動**。

### 比對規則（`isSameSole`）

候選鞋墊 `c` 和配對紀錄 `d`：兩邊都有 ID 就比 ID，否則比 `remoteId`。

### 掃描（`lib/core/ble/sole_scanner.dart`）

- 常數 `soleManufacturerId = 0xFFFF` 只定義這一處，量產前換掉時只要改這裡。
- `soleDeviceIdFrom(manufacturerData)`：取 `[soleManufacturerId]` 的 8 bytes 轉成大寫 hex；資料不存在或長度不是 8 就回傳 null。
- `SoleCandidate` 新增 `deviceId`，並提供 `SoleCandidate.fromScanResult`，掃描器和配對清單共用。
- `pickSole(candidates, paired:)` 的優先順序：
  1. 主要裝置在附近 → 選它。
  2. 其他已配對的鞋墊在附近 → 選訊號最強的。
  3. 沒有 ID 的鞋墊；或者配對清單裡還有舊紀錄（沒有 ID）時的任何鞋墊 → 選訊號最強的。這一條保留舊行為，讓舊韌體和剛換上新韌體的鞋墊還連得上。
  4. 以上都沒有 → 不連。**有 ID 但沒配對過的陌生鞋墊不會被自動連上。**

### 連線握手（`lib/core/ble/ble_connection_service.dart`）

- 在同一次 `discoverServices()` 的結果裡找 DIS `0x180A`，讀 `0x2A25` 當作 `onReady` 的 deviceId。找不到（舊韌體）就是 null。
- 不再讀主服務裡從來沒被填值的舊 `device_id` characteristic（`A761F782-…`）。

### 配對清單（`save_service.dart`、`settings_provider.dart`）

- 純函式 `upsertPairedDevice(list, device)`：
  - 找出所有跟 `device` 是同一隻的紀錄：ID 相同；或 `remoteId` 相同，而且兩邊的 ID 沒有互相衝突。
  - 沒找到 → 加在最後面。
  - 找到 → 第一筆的位置換成 `device`。`deviceId` 取 `device.deviceId ?? 原紀錄.deviceId`；只要任何一筆是主要裝置，合併後就是主要裝置。其他重複的紀錄刪掉。
- `setPreferredDevice`、`removePairedDevice`、`setLastBatteryPercent` 全部改用 `identityKey` 比對。
- 既有的配對紀錄不刪除，在連線時依上面的規則自動補上 ID，或跟有 ID 的紀錄合併。

### 自動連線（`ble_foreground_controller.dart`）

- 用 `pickSole(scan, paired: …)` 選鞋墊。用 `isSameSole` 找出已知的紀錄，把它的 `remoteId` 更新成這次看到的位址，`deviceId` 用廣播裡的 ID 補上。
- `onReady`：以 DIS 讀到的 ID 為準，跟廣播 ID 不一致時記 log；然後用 `upsertPairedDevice` 寫回。
- 監聽設定的 selector 原本用主要裝置的 `remoteId`，改成主要裝置的 `identityKey` 加 `remoteId`。只有兩者**都**改變時（使用者手動換了主要裝置）才強制搜尋。下面兩種情況不能觸發強制重連：
  - 同一隻鞋墊換了 MAC：`identityKey` 不變。
  - 舊紀錄補上 ID：`remoteId` 不變。

### 介面

- 配對清單：副標題從 MAC 改成 `ID ••••7081`（後 4 碼）。沒有 ID 的顯示 MAC 加上「舊版韌體」；已經配對過的加上「已配對」。
- 兩個主題的裝置頁：名稱旁邊顯示 `••••7081`。
- `HomeDeviceStatusSection` 的「ID: …」改顯示 `deviceId ?? remoteId`。
- `DeviceRow` 的線上判斷、`WarningCard` 的 key 改用 `identityKey`。

### 連帶影響

- 跌倒事件原本在 deviceId 為空時會被丟掉，有新韌體的鞋墊會開始送出。
- heartbeat ingest 會比對 deviceId，但韌體目前沒有送 `device_status`，所以沒有實際影響。

### 文件

更新 CLAUDE.md：
- 辨識方式改成「以 device ID 辨識，沒有 ID 時退回 remoteId」。
- 刪掉「device-id characteristic 從未被填值」的已知問題。
- GATT 清單補上 DIS。

## 測試

- `soleDeviceIdFrom`：`{0xFFFF: [1A 2B 3C 4D 5E 6F 70 81]}` → `1A2B3C4D5E6F7081`；沒有這個 key、長度不對、其他公司代碼都回傳 null。
- `pickSole`：
  - 主要裝置用 ID 比對，換了 MAC 也認得。
  - 已配對的非主要裝置，優先於訊號更強的陌生鞋墊。
  - 陌生的有 ID 鞋墊不會被連。
  - 清單裡有舊紀錄時，陌生鞋墊可以當最後備援。
  - 沒有 ID 的鞋墊照舊行為處理。
  - 現有的測試全部改成新簽名後仍然通過。
- `upsertPairedDevice`：
  - 同一個 ID 換了 MAC → 更新原紀錄，不新增。
  - 舊紀錄用 remoteId 對到 → 補上 ID。
  - 一筆舊紀錄加一筆 ID 紀錄 → 合併成一筆，保留主要裝置標記。
  - 新的鞋墊 → 加在最後。
  - ID 衝突、MAC 相同 → 視為不同鞋墊。
- `BlePairedDevice.identityKey`。
