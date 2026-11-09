# 分享「日常活動紀錄」

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. TDD. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 使用者（長輩或家屬）可以把自己的日常活動紀錄做成一張圖，自己決定分享給誰（例如自己的治療師或醫師）。App 不媒合、不抽成、不上傳。

## 使用者已決定（2026-11-03）

| 項目 | 決定 |
|---|---|
| 為什麼 | 原本想做「媒合治療師＋預約」，但醫療法第 61 條（仲介招攬）、物理治療師法第 12 條（須醫師診斷照會）、個資與醫材定位都有風險；先做「紀錄讓使用者自己帶去」 |
| 入口 | **分析頁右上角「分享」鈕**（兩個主題都要；吉祥物主題沒有 AppBar，放在標題列右邊） |
| 上線時機 | **現在就上線，有什麼放什麼**；步態開關打開後自動多出步態段落 |
| 格式 | **手機上產生一張長圖**，用系統分享（LINE、簡訊、存相簿、列印）；資料不經過伺服器 |
| 姓名 | **選填、預設不印**：分享前可以打一個稱呼（例如「王媽媽」），不打就不印 |
| 用詞 | 健康促進；不寫「復健、治療、診斷、處方、風險、異常」；不下任何健康判斷，只列紀錄 |

## 紀錄內容（只放有資料的段落）

1. **標題列**：「日常活動紀錄」、產生日期、統計期間（最近 7 天）、稱呼（有填才印）。
2. **足壓健檢**（有做過才有）：最近一次的日期、等級（照健檢頁的三段說法），以及**前腳掌／腳跟、內側／外側比例**（這次開始存；舊紀錄沒有比例就只印等級與日期）。
3. **遊戲運動**（最近 7 天有玩才有）：有運動的天數、合計分鐘、玩過哪些遊戲與各自次數（遊戲中文名照 `mission_catalog`；不認得的 slug 合併成「其他遊戲」）。
4. **步態**（只在 `realGaitEnabledProvider` 為真且有資料時）：最近 7 天每天的走路步數（小長條圖）、平均步頻、平均每天走路分鐘。
5. **行動力**（只在步態開關開且有等級時）：最近一個有等級的週的主等級字母＋一句話（沿用行動力卡的字串），以及細項字母。
6. **頁尾固定**：「本紀錄為健康促進與運動參與紀錄，非醫療診斷。數據由 SilverSole 鞋墊與 App 記錄，僅供參考。」＋ App 名稱。

全部段落都沒有資料時：分享鈕仍在，但預覽頁顯示「還沒有可以分享的紀錄」，分享鈕停用。

## 流程

分析頁「分享」→ **預覽頁**（全螢幕）：
- 上方：稱呼輸入框（選填，最多 12 字）、每個有資料段落一個勾選框（預設全勾）——這就是使用者的同意：看得到、勾得到才會出現在圖上。
- 中間：紀錄預覽（就是要輸出的那張圖，包在 `RepaintBoundary`）。
- 下方：「分享」按鈕 → 把預覽畫成 PNG（`RenderRepaintBoundary.toImage(pixelRatio: 3)`），寫到暫存資料夾，用 `share_plus` 分享（照 `lib/shared/widgets/create_file_and_share.dart` 的寫法，另加一個寫 bytes 的版本）。分享後刪暫存檔不是必要（系統會清），不做。

紀錄圖固定寬度（邏輯寬 360、輸出約 1080 px），用淺色底，不跟深色模式走，方便印出與在 LINE 上看。

## 檔案

| 檔案 | 動作 |
|---|---|
| `lib/shared/providers/last_foot_check_provider.dart` | `FootCheckRecord` 加選填 `foreRatio`、`medialRatio`（可空）；encode／decode 相容舊格式；`fromReport` 帶入（只踩腳跟時 medial 照健檢原本的值） |
| `lib/core/report/activity_report.dart` | 新增：`ActivityReport` 資料模型＋純函式 `buildActivityReport({today, footCheck, activity, gaitHistory?, mobility?})` |
| `lib/shared/widgets/report/activity_report_card.dart` | 新增：紀錄圖的版面（只吃 `ActivityReport`＋稱呼＋勾選的段落） |
| `lib/shared/pages/activity_report_page.dart` | 新增：預覽頁（稱呼、勾選、預覽、分享） |
| `lib/shared/widgets/create_file_and_share.dart` | 加 `createImageAndShare(bytes, fileName)` |
| `lib/core/routing/router.dart` | 加路由 `/activity-report` |
| `lib/shared/pages/analytics_page.dart`、`theme_two/analytics_page_t2.dart` | 右上角分享鈕 |
| `assets/translations/strings.csv` | 新字串（尾端；英文不含逗號；中文全形標點） |

---

### Task 1：健檢存比例＋紀錄資料
- `FootCheckRecord` 加 `foreRatio`、`medialRatio`；`tryDecode` 讀得了舊的（沒有這兩欄）與新的；測試舊格式、新格式、壞資料。
- `buildActivityReport`：依上面「紀錄內容」1–5 組資料；段落沒資料就是 null；步態與行動力只在傳入 `gaitHistory`／`mobility` 時才算（呼叫端依 `realGaitEnabledProvider` 決定要不要傳）。
- 測試：全空 → 所有段落 null；只有健檢（舊紀錄無比例）→ 只有等級日期；健檢有比例 → 比例正確且兩端相加 100；7 天遊戲紀錄的天數／分鐘／次數、超過 7 天的不算、不認得的 slug 併成其他；步態 7 天長條（沒資料的天是 0）、平均步頻只算有資料的天；行動力取最近有等級的週。
- Commit：`feat(report): gather a week of the wearer's activity for sharing`

### Task 2：紀錄圖與預覽頁
- `ActivityReportCard`：照上面版面；固定淺色；健康促進用詞；頁尾免責。
- `ActivityReportPage`：稱呼、勾選、預覽、分享；全空時顯示提示並停用分享。
- `createImageAndShare`；路由 `/activity-report`；兩個主題的分析頁加分享鈕（圖示＋可及性標籤「分享紀錄」）。
- 測試（widget，用 `settleTranslations`）：全空 → 提示、分享停用；有健檢＋遊戲 → 兩段都在、取消勾選遊戲後預覽不見遊戲段落；填稱呼 → 預覽出現稱呼，不填 → 沒有稱呼列；免責文字一定在；分享按鈕呼叫注入的分享函式並帶 PNG bytes（用 provider 或建構子注入假的分享函式，不呼叫真的 share_plus）。分析頁有分享鈕且點了會到 `/activity-report`。
- 字串檢查：`grep` 新字串不含「復健、治療、診斷、處方、風險、異常」（免責句裡的「非醫療診斷」是唯一例外，要在報告寫明）。
- Commit：`feat(report): share a one-image activity record from the analytics page`

## 完成條件
- [ ] 正式版：分析頁右上角有分享；有健檢／遊戲紀錄就能產生圖並用系統分享；沒有資料時清楚提示
- [ ] 步態開關打開時多出步態與行動力段落
- [ ] 資料不經過伺服器；稱呼選填預設不印
- [ ] `flutter analyze lib test` 沒有新問題；`flutter test` 全過；分支只在本地，不推
