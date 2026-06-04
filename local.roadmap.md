# SilverSole 銀足 — App 功能 Roadmap / Gap Analysis

> 來源：對照 `SilverSole 銀足 — Pitch Deck（定稿）` 與目前 codebase（branch `main`）。
> 用途：團隊內部 backlog，按 P0/P1/P2 排序。本檔 `local.*` 前綴，不進版控。
> 當前里程碑：**2026 Q2–Q3 — MVP 場域驗證 · 祥復 PoC 50 人次**。
> 最後更新：2026-06-03

---

## 定位（pitch 一句話）

讓長輩「願意每天穿出門」的智慧鞋墊 — **隱形、零操作、即時**。
產品本質是 **硬體 × 遊戲化 × 連續資料** 的飛輪；別人偵測退化，我們讓長輩想動起來。

---

## 一、已完成（地基層）

- [x] Supabase 帳號登入 / 註冊（`core/auth`）
- [x] BLE 連線管線：Android 前景服務、自動重連、訂閱所有 characteristic、寫 base timestamp（`ble_foreground_controller.dart`、`ble_connection_service.dart`）
- [x] 即時 IMU / 壓力串流（rolling 100 筆 + 圖表，`live_telemetry_notifier.dart`）
- [x] 裝置狀態 / 心跳（電量）→ Edge Function `heartbeat`
- [x] GPS 地圖（`map_card.dart`）、足壓 heatmap、足壓視覺化頁
- [x] 跌倒 characteristic + event bus + **app 內**警示卡（`warning_card.dart`）
- [x] 分析儀表板 UI、深色模式、i18n（en / zh-TW）、OTA 更新檢查
- [x] GATT 合約完整定義（含 fall-detect，`ble_uuids.dart`）

---

## 二、P0 — PoC 必備（沒有就驗不了論點）

### [ ] P0-1 連續資料上雲（飛輪地基）

- **現況**：`telemetry_ingest_service.dart` 與 `telemetry_upload_buffer.dart` 的 `enqueue` / `flushQueue` / `uploadOne` **全是空 stub（只有 TODO）**。live 資料看完即丟，**一筆都沒進 DB**。
- **為何 P0**：pitch 護城河（p.7 連續×足底、p.9 時間複利）的前提就是連續資料要進雲端。PoC 50 人次若收不到資料，整個論點無法驗證。
- **工作項**：
  - [ ] 設計 Supabase 資料表結構（telemetry / 足壓 / 步態事件）
  - [ ] 實作本地佇列（離線緩衝 + 重送）
  - [ ] 實作 `flushQueue` / `uploadOne` + retry 機制
  - [ ] RLS policy（沿用現有 `42501 → rls_denied` 慣例）

### [ ] P0-2 跌倒 → 家屬通知（補完安全網）

- **現況**：跌倒事件只在 `warning_card.dart:94` 跳**本機**提示；p.6 流程最後一棒「雲端趨勢分析 → 家屬通知」**未實作**。
- **為何 P0**：安全網是 headline，PoC 場域必被問。「跌倒只有長輩自己手機響」=沒有安全網。
- **工作項**：
  - [ ] 家屬綁定 / 帳號關聯（最小可行：1 對 1）
  - [ ] 跌倒事件上雲（事件表 + 三條件 AND 判定結果）
  - [ ] 推播（FCM）到家屬端
  - [ ] 家屬端可看到「最近警示」清單

---

## 三、P1 — PoC 體感與展示（戴上第一天就有感）

### [ ] P1-1 一分鐘足壓健檢（Day 1 基準報告）

- **現況**：有 heatmap 元件，但**沒有引導式健檢流程 + 基準報告**。
- **工作項**：站立倒數引導 → 足壓分佈 / 重心偏移計算 → 第一張基準報告（可分享給家屬）。

### [ ] P1-2 分析儀表板接真實資料

- **現況**：`analytics_page.dart` 數字為**寫死假資料**（`48 kPa`、`71 kPa`、固定建議文字）。UI 框架在，未接真 telemetry。
- **工作項**：接 `TelemetryQueryService` → 真實足壓 / 穩定度趨勢；移除 hardcoded 值。

### [ ] P1-3 活力趨勢分數 + 步態趨勢

- **現況**：無。
- **工作項**：定義活力分數演算法（足壓 + 步態派生指標，**健康促進語意、不宣稱疾病診斷**）→ 趨勢視覺化。

---

## 四、P2 — 變現層（roadmap 2027 Q3 D2C 才真正需要，PoC 階段刻意延後）

### [ ] P2-1 即時走姿矯正（拖步 / 外八偵測 + 微震動）

- 需硬體震動支援；含步態異常偵測演算法。

### [ ] P2-2 訂閱付費牆（NT$99/月）

- 免費版 vs 進階版功能 gating、IAP（App Store / Play Billing）。

### [ ] P2-3 Walk-to-Earn 點數系統 + 兌換

### [ ] P2-4 多家屬共享（5 位）

- 家屬角色 / 多人綁定（P0-2 的擴充）。

### [ ] P2-5 AI 步態週報 / 90 天變異度 / 退化月報

### [ ] P2-6 CPA 平台導購（折價券 / 導購返利）

---

## 五、風險備註

- **單點風險**：整份 pitch 的護城河都建立在「連續資料」上，但目前**上雲層是空殼**。P0-1 沒完成前，後面所有資料相關功能（分析、週報、退化預警、活力分數）都是空中樓閣。
- **醫材紅線**：活力分數 / 步態 / 足壓皆須維持「健康促進」語意，**不可宣稱疾病診斷**（pitch p.5 明示）。
- **平台限制**：背景 BLE 管線目前 Android-only，iOS 上線前需另評估。
