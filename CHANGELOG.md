# Changelog

## v1.8.0

> ⚠️ 本版更換了應用程式識別碼（`com.dongyutech.silversole`），會以新 App 的形式安裝，無法直接覆蓋舊版。請先移除舊版再安裝，並重新登入與配對鞋墊。

更新內容:

- 新增「一分鐘足壓檢測」：首頁足部健康卡片的開始按鈕現在可以進行 60 秒檢測，下方即時顯示足壓分布，結束後產生前後腳、內外側的受力比例與評等報告；可提前結束，也會在離開前再次確認。
- 分析頁「步態」分頁改版：拆成「行走能力」與「行走穩定度」兩組指標，提供週、月、季三種時間範圍，每項指標都有 ⓘ 說明；季檢視新增階段趨勢圖。徽章牆移到遊戲頁。
- 新增跌倒警示（示範版）：鞋墊長時間傾倒時，手機每 0.5 秒震動提示，觸發後顯示全螢幕紅色警示「您的家人可能有緊急狀況」，按「我知道了」才會關閉。
- 足壓熱力圖支援左右雙腳顯示，並可播放內建範例資料，未連接鞋墊時也能展示。
- 鞋墊連線改為自動尋找正在廣播的鞋墊：鞋墊重開機後不再連不上，斷線後也會自動重新連線；「我的裝置」新增「清除所有配對」按鈕。
- 電量顯示更清楚：離線或尚未收到最新電量時，以灰色顯示上次的電量；從未連線過則不顯示數值。
- 修正鞋墊回報無效電量（255）時，電量條溢出與圖表暴衝的問題。
- 修正腳跟與大拇趾球的壓力數值對調的問題。
- 新增中英文隱私權政策。

Updates:

> ⚠️ This release changes the application ID (`com.dongyutech.silversole`), so it installs as a new app rather than upgrading the old one. Uninstall the previous version first, then sign in and pair your sole again.

- Added the one-minute foot-pressure check: the start button on the home foot-health card now runs a 60 s session over a live pressure map and ends on a report of forefoot/rearfoot and medial/lateral load with a rating. It can be ended early, and leaving asks for confirmation.
- Rebuilt the Analytics gait tab: metrics are split into walking ability and walking stability, across week, month, and quarter views, each with an ⓘ explainer; the quarter view adds a phase trajectory. The badge wall moves to the Games page.
- Added a fall warning (demo): while the sole stays tipped over, the phone pulses every 0.5 s, then a full-screen red alert reads "Your family member may need help" and stays until "Got it" is tapped.
- The pressure heat map can show both feet and replay a bundled sample, so it can be demoed with no sole connected.
- The app now connects to whichever sole is actually advertising, so a rebooted sole is found again and dropped links reconnect on their own; "My devices" gains a "clear all pairings" button.
- Clearer battery display: while offline or before a fresh reading arrives, the last known level is shown in gray; a sole that has never reported shows no number.
- Fixed the battery bar overflowing and the chart spiking when the sole reports an invalid (255) level.
- Fixed heel and big-toe-ball pressure readings being swapped.
- Added the privacy policy in Traditional Chinese and English.

## v1.7.0

更新內容:

- 新增第二主題（吉祥物主題）：奶油底色、粗黑外框與 DM Sans 字體，首頁、地圖、遊戲、分析、設定五個分頁都有專屬版面，可在設定中隨時切換，原本的藍色主題完整保留。
- 新增「我的裝置」面板：從首頁的裝置卡點入，顯示已配對裝置、即時電量與連線狀態、韌體資訊；主題二可直接從面板配對新裝置。
- 新增「活力幣商店」：從遊戲頁的商店入口進入，分為每日扭蛋、數位券與造型三類，開啟時活力幣會從 0 累加到目前數量。
- 遊戲頁改版：八款遊戲各自連到專屬的 H5 網址，不再全部指向同一個位址。
- 分析頁改版：活力步態與壓力分布兩個分頁、步態指標卡與遊戲徽章牆。
- 主題二首頁新增「裝置近期資料」卡片，並有專屬的即時資料面板，可切換頻道、錄製與匯出。
- 錄製資料改為完整保存三顆壓力感測器的數值。
- 即時 IMU 數據加入 10 筆移動平均濾波，圖表不再劇烈跳動。
- Debug 版本可與正式版同時安裝在同一支手機上。
- 修正在切換主題或深色模式時，地圖分頁造成應用程式崩潰的問題。
- 修正近期資料圖表的圖例色塊與實際線條顏色對不上的問題。
- 修正步態日記卡片的分隔線位置，以及主題二部分卡片未撐滿寬度的問題。
- 吉祥物素材改用 WebP，縮小安裝檔體積。

Updates:

- Added a second theme (the illustrated mascot theme): cream canvas, heavy dark outlines, and DM Sans, with its own layout for Home, Map, Games, Analytics, and Settings. Switch at any time from Settings; the original blue theme is untouched.
- Added a "My devices" panel, opened from the home device card: paired devices, live battery and connection status, and firmware info. The mascot theme can pair a new device straight from the panel.
- Added the Vitality Coin Shop, reached from the Games hub: daily gacha, digital vouchers, and outfits, with the coin balance counting up from zero on open.
- Games hub: each of the eight titles now opens its own H5 URL instead of a single shared address.
- Analytics rebuild: vitality-gait and pressure-distribution tabs, a gait metrics card, and the game badge wall.
- Added a "recent device data" card to the mascot home, with its own live telemetry panel for channel switching, recording, and export.
- Recordings now keep all three pressure sensor values.
- Live IMU is smoothed with a 10-sample moving average, so charts no longer jump.
- Debug builds install alongside the released app on the same phone.
- Fixed a crash on the Map tab when switching theme or dark mode.
- Fixed the recent-data chart legend, whose swatches did not match the plotted lines.
- Fixed the gait diary card's divider placement and several mascot-theme cards that did not fill the width.
- Mascot artwork ships as WebP, shrinking the install size.

## v1.6.0

更新內容:

- 全新藍色設計系統：重塑所有頁面與元件，改用灰底＋純白卡片與 hairline 邊框，字體換為 Google Sans。
- 首頁大改版：新增每日任務彈窗與足部健康檢查卡片；無主要裝置時 FAB 改為新增裝置入口；重製裝置狀態卡。
- 裝置在線狀態改為即時判定：斷線後自動切換為離線，不需手動刷新；離線時顯示真實的「上次連線」相對時間（秒／分鐘／小時／天／7 天以上）。
- 新增娛樂頁與遊戲 WebView。
- 地圖改為全螢幕分頁，採用淺色地圖樣式並調整定位按鈕位置與配色。
- 分析頁新增壓力分頁。
- 改善 BLE 即時 IMU 資料解析（改為二進位協定）。
- 新增 macOS 桌面版建置目標。

Updates:

- New blue design system: re-skinned every page and widget, moved to a gray canvas with pure-white cards and hairline borders, and switched the app font to Google Sans.
- Home revamp: added a daily missions modal and a foot health check card; the FAB becomes an "add device" action when no primary device is set; redesigned the device status card.
- Real-time device online status: the status card now switches to offline on its own after disconnection (no manual refresh) and shows a real relative "last connected" time when offline (seconds / minutes / hours / days / 7+ days).
- Added an Entertainment page and an in-app game WebView.
- Map is now a full-screen tab with a light map style and a repositioned, re-themed locate button.
- Added a Pressure tab on the Analytics page.
- Improved live IMU parsing over BLE (now a packed binary protocol).
- Added a macOS desktop build target.

## v1.5.1

更新內容:

- 新增足底壓力可視化頁面，可從底部導覽列查看三點壓力熱圖與即時感測值。
- 將 IMU pressure 資料模型改為三感測器陣列，並在即時圖表中分別繪製每個壓力感測器曲線。
- 修正登入成功後的導向流程，避免從初始登入路由返回時觸發無可返回頁面的錯誤。
- 新增壓力可視化相關繁中與英文介面文字。

Updates:

- Added a foot pressure visualization page with a bottom navigation entry, three-point pressure heat map, and live sensor readouts.
- Changed the IMU pressure payload model to a three-sensor array and plotted each pressure sensor separately in live charts.
- Fixed successful sign-in navigation to avoid popping from an initial sign-in route with no previous page.
- Added Traditional Chinese and English UI strings for pressure visualization.

## v1.4.0

更新內容:

- 重建分析頁儀表板，加入足底壓力分布、今日狀態、壓力分析、穩定度趨勢與 AI 照護建議區塊。
- 首頁近期資料卡片新增查看入口，可開啟原有即時資料圖表與錄製匯出頁。
- 新增分析頁相關繁中與英文介面文字。

Updates:

- Rebuilt the Analytics dashboard with foot pressure distribution, today status, pressure analysis, stability trend, and AI care suggestion sections.
- Added a View entry on the home recent data card to open the existing live chart and recording export page.
- Added Traditional Chinese and English UI strings for the Analytics page.

## v1.3.0

更新內容:

- 新增登入狀態導向，未登入時導向登入頁
- 新增 BLE base timestamp 寫入與裝置狀態通知上傳流程
- 新增 SilverSole 裝置狀態資料承載模型與心跳函式資料接收服務
- 優化即時與錄製 IMU 圖表，只顯示最近資料視窗並平滑更新
- 設定主要 BLE 裝置前會停止掃描，降低連線衝突

Updates:

- Added auth-aware routing that sends guests to the sign-in page.
- Added BLE base timestamp writing and device status notification upload flow.
- Added SilverSole device status payload models and heartbeat function ingest service.
- Improved live and recorded IMU charts with a recent-data viewport and smoother updates.
- Stops BLE scanning before setting a preferred device to reduce connection conflicts.

## v1.2.1

更新內容:

- 增加簡易跌倒判定
- 優化地圖效能

Updates:

- Added simple fall detection
- Optimized map performance

## v1.1.0

更新內容:

- 分析頁新增錄製資料匯出功能，可將 IMU 記錄整理為 JSON 檔並直接分享
- 分析頁即時圖表新增六軸顯示項目，支援 pitch / roll 視覺化
- 新增錄製資料專用圖表元件，區分即時資料與錄製資料的顯示邏輯
- 新增自動連接主要使用的 SilverSole 裝置

Updates:

- Added export support on the Analytics page to package recorded IMU data as a JSON file and share it directly.
- Added a six-axis chart option on the Analytics page, including pitch / roll visualization.
- Added dedicated chart widgets for recorded telemetry and separated the rendering flow from live telemetry charts.
- Added automatic connection to the preferred SilverSole device used

## v1.0.0

更新內容:

- 因重構基於資料庫之前端架構，與先前版本較有較大差異
- 裝置頁新增配對按鈕，使用藍牙偵測 SilverSole BLE 裝置
- 裝置頁新增重命名裝置、刪除裝置功能
- 支持前台服務 (僅限Android)
- 支持自動連線、斷線重連 (若已綁定主要裝置)
- 新增藍牙實時監測模式
- 修復首次進入應用程式時預設非深色主題的問題
- 重構未綁定裝置時的 UI 表現
- 暫不支持遠端查看資料 (即目前無法查看資料庫狀態)
- 暫不支持上傳資料至資料庫

Updates:

- Due to a database-driven frontend architecture refactor, this version differs significantly from previous versions.
- Added a pairing button on the Devices page to scan for SilverSole BLE devices via Bluetooth.
- Added device renaming and device deletion on the Devices page.
- Added foreground service support (Android only).
- Supports auto-connect and auto-reconnect after disconnection (when a primary device is already set).
- Added real-time Bluetooth monitoring mode.
- Fixed the issue where the app did not default to dark theme on first launch.
- Refactored the UI for the unbound/unpaired device state.
- Remote data viewing is not supported yet (database status cannot be viewed at this time).
- Uploading data to the database is not supported yet.

## v0.10.0

更新內容:

- 新增電量顯示
- 修復自動整理無法運作的問題
- 修復定位權限請求未正常顯示問題
- 近期資料趨勢圖改為實際資料並支援點擊刷新
- 重構設定清單資料模型與元件檔案結構

Updates:

- Add device battery display
- Fix automatic refresh not working issue
- Fix location permission request not showing issue
- Recent data chart now uses real data and supports tap-to-refresh
- Refactor settings list model and widget structure

## v0.9.0

更新內容:

- 新增裝置頁與分析頁（含搜尋與近期資料列表）
- 地圖支援位置權限與最近位置刷新/標記
- 新增深色模式設定
- 新增近期資料趨勢圖卡片
- 調整警報卡片與介面細節

Updates:

- Add Devices and Analytics pages (search and recent data list)
- Map supports location permission and refresh/markers for recent locations
- Add dark mode setting
- Add recent data trend chart card
- Refine warning card and UI details

## v0.8.0

更新內容:

- 新增 SilverSole 裝置在線判斷 (目前需手動刷新)
- 新增 SilverSole 裝置近期警告卡片
- 重構使用者界面

Updates:

- Add SilverSole device online checker (need to refresh manually for now)
- Add SilverSole device recent warning card
- Refactor user interface style

## v0.7.2

更新內容:

- 新增地圖卡片
- 修正資料時區問題
- 優化使用者體驗

Updates:

- Add the Google map card
- Fix the recent data time zone issue
- Optimize user experience

## v0.6.1

更新內容:

- 更新UI介面
- 新增用戶身份設定
- 重構綁定系統

Updates:

- Update the UI.
- Add user identity settings.
- Refactor the binding system.

## v0.5.0

更新內容:

- 支持查詢SilverSole 裝置數據 (需登入)

Updates:

- Support query SilverSole device data

## v0.4.0

更新內容:

- 支持綁定 SilverSole 裝置
- 新增登入持久化 (保持登入狀態)

Updates:

- Added support for binding SilverSole devices
- Added persistent login (keeps you signed in)

## v0.3.0

更新內容:

- 支持「郵箱密碼」登入
- 支持「郵箱密碼」註冊

Updates:

- Support sign in with email and password
- Support sign up with email and password

## v0.2.0

更新內容:

- 新增「登入介面」
- 新增語言系統（支持繁體中文、英文）

Updates:

- Add Sign up page
- Add Localization system (support en, zh_TW)

## v0.1.3

更新內容:

- 新增「更新檢查」
- 修復連網錯誤

Updates:

- Add Update Checker
- Fix internet connect error

點擊下方 APK 檔案即可下載。
Click the APK file below to download.

## v0.1.2

更新內容:

- 新增「更新檢查」

Updates:

- Add Update Checker

點擊下方 APK 檔案即可下載。
Click the APK file below to download.
