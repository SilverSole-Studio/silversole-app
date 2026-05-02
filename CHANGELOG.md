# Changelog

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
