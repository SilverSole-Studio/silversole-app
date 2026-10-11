# 鞋墊韌體無線更新（OTA）——App 端設計

- 日期：2026-10-11
- 狀態：設計已核准，下一步是實作計畫
- 範圍：子專案 ②。它依賴子專案 ①（`2026-10-11-sole-device-id-design.md`，commit `603ed05`）提供的 device ID。
- 依據：韌體 repo 的 `docs/ota-app-handoff.md`（協定 v2，commit `7e7528d`）。權威來源是該 repo 的 `docs/ota-ble-protocol.md` 和 `tools/dfu_send.py`。**韌體 repo 只能讀，不能修改。**

## 使用者已決定的事

| 項目 | 決定 |
|---|---|
| 提示方式 | 只在裝置頁的韌體卡片提示。每次連上鞋墊時在背景檢查，不跳出視窗 |
| 開發者模式 | 在韌體卡片的版本號上連點 7 次切換，存在 shared_preferences。開啟後改讀 beta 頻道，並允許降版（需先看過警告） |
| 本機選檔更新 | 只有 debug 版（`kDebugMode`）才有，release 版會被編譯器移除 |
| 伺服器 | 由 Claude 建立公開讀取的 `firmware` bucket，每一次寫入後端前都先跟使用者確認 |
| 多隻鞋墊 | 附近可能同時有兩隻以上，重開機後用 device ID 找回同一隻 |
| 架構 | A：OTA 共用平常那條連線 |

## 1. 伺服器合約（Supabase Storage）

```
firmware/                                  ← 公開 bucket，不加任何 storage.objects 的 SELECT policy
  channels/stable/manifest.json
  channels/beta/manifest.json
  releases/<version>/fw.bin                ← 寫入後就不再修改
  releases/<version>/fw.bin.sig
```

- 檔案用 `storage.from('firmware').getPublicUrl(path)` 取得網址，再用 `dio` 下載。公開 bucket 用網址就能讀；加 SELECT policy 反而會讓 bucket 內容可以被列舉。
- manifest 會被覆寫，上傳時要設 `cacheControl: '60'`，否則 CDN 可能長時間給舊版。CI 也要照這個做。
- manifest 格式照交接文件 §2.2：`schema`、`channel`、`version`、`size`、`sha256`、`bin_path`、`sig_path`、`notes`、`published_at`。
- bucket 名稱、`schema == 1`、檔案大小上限 425984 都寫成常數，各只定義一次。

## 2. 元件

### 2.1 純邏輯（`lib/core/`，可以單元測試）

| 檔案 | 內容 |
|---|---|
| `ble/ota/dfu_protocol.dart` | 列舉 `DfuState`（0–3）和 `DfuResult`（0–10）；`DfuStatus.parse(bytes)`，只接受剛好 7 bytes、開頭是 `0xA0` 的通知；`startCommand(size, sha256)` 38 bytes；`applyCommand(signature)` 65 bytes；`abortCommand` `[0x03]`；`getStatusCommand` `[0x04]`；`dataPacket(offset, chunk)` 是 u32 LE offset 加上資料；`payloadSize(mtu) = min(mtu − 3, 244) − 4`；常數 `pageSize = 4096`、`minMtu = 68` |
| `ble/ota/dfu_link.dart` | 抽象介面 `DfuLink`：`int get mtu`、`bool get isConnected`、`Stream<List<int>> get statusNotifications`、`Future<void> writeControl(bytes)`（有回應）、`Future<void> writeData(bytes)`（無回應） |
| `ble/ota/dfu_transfer.dart` | 交接文件 §4 的演算法，回傳 `Result<void>`，失敗時帶 `DfuFailure`。另有 `onProgress(committed, size)` 和 `cancel()`。各種時間（2 秒、100 ms、10 秒、30 秒）和每包間隔（預設 10 ms）都可以從建構子注入，方便測試 |
| `utils/firmware_version.dart` | 用 `pub_semver` 解析版本；`compareFirmware(device, server)` 回傳升級、降級、相同，或無法解析 |
| `data/firmware_release_service.dart` | `fetchManifest(channel)`、`download(manifest)` 回傳 `FirmwareImage(bin, sig, sha256, version)`；純函式 `validateImage(manifest, bin, sig)` |
| `shared/models/firmware_manifest.dart` | freezed 加 json_serializable 模型 |

### 2.2 BLE 整合

- **`BleConnectionService`**
  - `_preferredMtu` 64 → **247**（韌體的 `att_mtu`）。
  - 在同一次 `discoverServices()` 裡保存 DFU 服務。
  - 握手時讀 DFU `version`，加上 ① 已經在讀的 chip ID，一起透過 `onReady(SoleSessionInfo)` 傳出去。`SoleSessionInfo` 包含 `deviceId`、`firmwareVersion`、`dfuSupported`。
  - `dfuLink()` 回傳 `DfuLink`，鞋墊沒有 DFU 服務時回傳 null。它在需要時才訂閱 control 通知（`onValueReceived` 加 `cancelWhenDisconnected`）。寫入一律不使用 long write，並在送出前確認資料長度 ≤ `mtuNow − 3`。
- **`SoleScanner.watch(timeout, stopWhen)`**：一次長掃描，期間看到的鞋墊全部回傳；看到 `stopWhen` 符合的就提早停止。不能用多次短掃描，因為 Android 30 秒內最多只能呼叫 5 次 `startScan`。
- **`bleForegroundControlProvider`** 改成回傳 `SoleConnectionController`（非 Android 平台回傳一個什麼都不做的版本）：
  - `hold()`：取消搜尋退避和 watchdog。`searchAndAttach`（包含使用者手動換主要裝置時的強制搜尋）在 hold 期間直接返回，避免傳到一半被拆掉連線。
  - `reacquire(target, timeout)`：detach 連線服務，停止它對舊 MAC 的重連；`watch()` 找目標；用平常的 handlers attach 上去，等 `onReady` 後回傳 `SoleSessionInfo`。
  - `release()`：恢復平常的自動連線。
- **`connectedSoleProvider`**：`ConnectedSole?`，包含 `device`、`firmwareVersion`、`dfuSupported`。controller 在 `onReady` 時寫入，斷線時清成 null。

### 2.3 重新連線時怎麼判斷目標（純函式 `matchReacquireTarget`）

| 更新前的目標 | 判斷方式 | 結果 |
|---|---|---|
| 有 device ID | 廣播裡出現同一個 ID | 確定是同一隻 |
| 沒有 ID（舊韌體） | 出現同一個 remoteId | 確定是同一隻 |
| 沒有 ID，也沒有出現同一個 remoteId | 整段掃描只看到**一隻**鞋墊，而且它的 ID 不屬於其他已配對的紀錄 | 推測是同一隻 |
| 其他情況 | — | 找不到 |

### 2.4 狀態與介面

- `AppSettings.firmwareDevMode`，對應 `LocalSavableKey.firmwareDevMode`。
- **`firmwareUpdateCheckProvider`**：watch `connectedSoleProvider`（identityKey、版本、是否支援 DFU）和開發者模式，讀對應頻道的 manifest，算出 `FirmwareCheck`：
  - 未連線。
  - 需要接線更新：沒有 DFU 服務。
  - 版本無法解析：只記 log，不提供更新。
  - manifest 的 schema 看不懂：不提供更新。
  - 已是最新。
  - 有新版。
  - 可以降版：只有開發者模式。
  - 無法檢查：網路錯誤，可以重試。
- **`firmwareUpdateProvider`**：OTA 狀態機，階段如下：
  `idle → downloading → transferring(committed, size) → verifying → rebooting → succeeded / notUpdated / unconfirmed / failed(DfuFailure)`。
  - 傳送前檢查：沒有連線、沒有 DFU 服務、即時電量 < 30%（255 視為未知，照常送出）、MTU < 68。
  - 從開始傳送到 release 之前，`hold()` 一直有效，螢幕常亮也一直開著（`wakelock_plus`）。
- **`deviceOnlineProvider`**：OTA 進行中（transferring 到 rebooting）一律回報在線，不會因為 50 Hz 資料暫停被判成離線。
- **韌體卡片**（兩個主題各一張）：
  - 顯示連著的鞋墊名稱、ID 後 4 碼、版本，以及 `FirmwareCheck` 對應的標籤或按鈕。
  - 版本號連點 7 次切換開發者模式，並跳出 snackbar 提示。
  - 開發者模式下顯示 beta 標示和降版按鈕；只有 debug 版才顯示「從檔案更新」。
  - 刪除 `MockFirmware`。原本「即時同步 {} Hz」是假資料，跟著拿掉，`firmware_detail` 只顯示版本。
- **`/firmware-update` 頁面**（兩個主題共用，用原生 Material 元件）：
  - 確認：目前版本 → 新版本、`notes`、預估時間（`size ÷ 7 KB/s`），以及注意事項：App 保持在前景、手機靠近鞋墊、鞋墊會暫停傳資料。降版時多一個警告對話框。
  - 進度：顯示 `committed / size`。
  - 結果：成功、更新未完成（可重試）、無法確認、失敗（訊息，以及能不能重試）。
  - 傳送中用 `PopScope` 擋住返回鍵；取消時送 ABORT 再 release。

## 3. 演算法細節（`DfuTransfer`）

```
START → 等 STATUS（2 秒）
  BATTERY_UNKNOWN：每 10 秒重送 START，最多 3 次，之後算 batteryUnknown
  state != RECEIVING 或 result != OK：依下表處理後結束
每一頁：送 [committed, min(committed + 4096, size)]，每包間隔 gap
  寫 data 拋錯：已斷線算 disconnected；否則停止送這一頁，當作掉包
  等 STATUS（2 秒）：
    OK 而且 committed 前進：更新進度，retries = 0
    BAD_OFFSET、逾時、掉包：retries++，等 100 ms，清掉殘留的 STATUS，從 committed 重送
    BAD_STATE：停止（鞋墊在 30 秒試用期）
    其他錯誤：依下表處理
  retries > 10：tooManyRetries
APPLY → 等 STATUS（30 秒）；收到 VERIFYING 就再等一次（30 秒）
  APPLIED + OK：成功
HASH_MISMATCH / FLASH_ERROR：不論出現在哪個階段，都從 START 整個重來一次；第二次再出現才算失敗
```

**`DfuFailure` 與處理方式**（每一種都有在地化訊息，而且都強調「鞋墊仍可正常使用」）：

| 失敗 | 可重試 | 說明 |
|---|---|---|
| `notConnected`、`disconnected`、`tooManyRetries`、`timeout` | 是 | 請使用者靠近一點、保持 App 在前景再試 |
| `cancelled` | 是 | 使用者取消 |
| `dfuUnsupported`、`unsupportedVersion` | 否 | 韌體太舊，需要接線更新，請聯絡客服 |
| `mtuTooSmall` | 是 | 記錄實際協商到的 MTU |
| `lowBattery` | 是 | 請先充電 |
| `batteryUnknown` | 是 | 鞋墊剛開機，稍後再試 |
| `badState` | 是 | 鞋墊剛換版還在試用期，30 秒後再試 |
| `hashMismatch`、`flashError` | 是 | 已經自動重來過一次 |
| `badSignature`、`tooLarge`、`badCommand` | 否 | 記錄並請使用者回報 |
| `manifestUnavailable`、`downloadFailed` | 是 | 網路問題 |
| `imageInvalid` | 否 | 長度、SHA 或 sig 長度不符，不送進鞋墊 |

## 4. 換版後的確認

`reacquire(target, 90 秒)` 之後：

- 找不到鞋墊，或讀不到 version → **無法確認**：「鞋墊仍可正常使用，請稍後到裝置頁查看版本。」
- 讀到的 version 等於新版 → **成功**；如果是 2.3 表裡「推測是同一隻」的情況，結果也標成推測。
- 讀到的 version 等於舊版 → **更新未完成**，可以重試。
- 用本機檔案更新時沒有預期版本，只顯示「更新前 X → 更新後 Y」，不判斷成功或失敗。

**已知限制**：舊韌體鞋墊更新到有 ID 的韌體後，如果 MAC 也換了，配對清單會多一筆新紀錄，舊紀錄要手動刪除。① 的合併邏輯沒辦法確定兩筆是同一隻。

## 5. 套件

- `crypto`、`pub_semver`：已經是間接依賴，改成直接依賴，版本跟 `pubspec.lock` 一致。
- `wakelock_plus`：新增，實作前用 Context7 查最新的用法。

## 6. 不在這次範圍

照交接文件 §9：斷線續傳、背景更新、同時更新多隻鞋墊、防降版。另外 CI 自動上傳和 iOS（App 的 BLE 只支援 Android）也不做。

## 7. 測試

- **協定**：START、APPLY、data 封包逐 byte 比對；STATUS 解析（長度、開頭 byte 不對時拒絕）；`payloadSize(247) == 240`、`payloadSize(68) == 61`。
- **semver**：`0.4.0-rc.1 < 0.4.0`、`0.10.0 > 0.9.0`、相同、無法解析。
- **`validateImage`**：size 是 0、超過上限、和 manifest 不符；SHA 不符；sig 長度不是 64。
- **`matchReacquireTarget`**：2.3 表的每一列。
- **`DfuTransfer`**（假的連線加 `fake_async`）：
  - 正常完成，每包長度都用滿上限。
  - 掉最後一包，靠逾時恢復。
  - BAD_OFFSET 恢復。
  - 連續重送超過 10 次後停止。
  - 寫 data 拋錯後恢復。
  - BAD_STATE 停止。
  - BAD_SIGNATURE 不重試。
  - BATTERY_UNKNOWN 重試後成功，以及重試用完。
  - HASH_MISMATCH 重來一次後成功，以及連續兩次失敗。
  - APPLY 先收到 VERIFYING 再收到 APPLIED。
  - 傳送中斷線。
  - 取消時送出 ABORT。
- **實機**：照交接文件 §8 的 12 條逐條驗收。需要使用者提供兩個版本的已簽章 `fw.bin` 和 `fw.bin.sig`。

## 8. 文件

更新 CLAUDE.md：
- MTU 改成 247。
- 加入 OTA 流程和檔案位置。
- `SoleConnectionController` 的 hold、reacquire、release。
- `connectedSoleProvider`。
- 伺服器合約和 manifest 的快取規則。
