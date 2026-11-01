# 每日任務：依資料排任務＋AI 寫說明

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. TDD. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 首頁的「每日任務」面板依每個人的資料排今天的任務（遊戲紀錄、足部健檢、步態開關打開時再加步數與行動力）；AI 版本由 Claude 寫一句鼓勵話與每個任務的理由。

## 使用者已決定（2026-11-01）

| 項目 | 決定 |
|---|---|
| 目的 | 讓**現有的每日任務**有 AI 噱頭，**不做推播通知** |
| 同意 | AI 預設關；第一次打開面板時說明要送哪些數字、送去哪裡，按同意才用；面板裡有開關可隨時關 |
| 資料 | 健檢＋遊戲紀錄；步態開關（REAL_GAIT）打開時自動加入步數、步頻、走路時間、行動力等級 |
| 模型 | **Claude Haiku 5.5**（`claude-haiku-5-5`） |
| 金鑰 | **這次先不接金鑰**：程式做好，AI 用開關 `AI_MISSIONS` 關著；不部署函式、不套 migration |
| 介面（UI 視窗提醒） | 面板裡**不放粗哥頭像**（一個畫面最多一隻粗哥）；「AI 推薦」標籤要**圖示＋文字** |

## 遊戲端介面（「銀足APP」視窗已上線，e3311ae）

每款遊戲結算時：`window.flutter_inappwebview.callHandler('gameActivity', {slug, stage?, seconds})`。slug＝網址 `/game/` 後那段；踩進老街多帶 `stage`；seconds＝實際遊玩秒數。fire-and-forget，不看回傳值。清單與開法：總倉庫 `02_產品/鞋墊_SilverSole/_遊戲slug清單_2026-11-01.md`。

App 端只擋格式：slug、stage 符合 `^[a-z0-9_-]{1,32}$`（stage 可省略），seconds 為 0–10800 的整數；不認得的 slug **照記**。只收遊戲網域來的頁面（跟 `gameSaveLoad` 同一個來源檢查）。

## 任務清單（App 與伺服器共用同一組 id）

| id | 任務 | 開法（接在 `Constants.gameUrl` 後） | 完成條件 |
|---|---|---|---|
| `foot_check` | 量一次足壓（一分鐘健檢） | 既有健檢流程（照現在面板的做法） | 今天做過健檢（`lastFootCheckProvider.isOnDay(today)`） |
| `walkgroup` `bike` `canoe` `fish` `ski` `hop` `rhythm` `quiz` `pool` | 玩一局該遊戲 | `game/<id>/` | 今天有該 slug 的 gameActivity |
| `laojie` | 踩進老街玩一關 | `game/laojie/<stage>/?theme=<theme>&from=world`，`(theme, stage)` 依日期輪替：`xinbei/lantern`、`taipei/goldfish`、`taoyuan/peach`、`yilan/qiangu`、`hualien/qixingtan` | 今天有任一 `laojie` 的 gameActivity |

`racer`、`golf` 是隱藏關，**不當任務**。

---

## 批 A：遊戲紀錄＋規則排任務（不碰 AI）

### Task A1：gameActivity 收進手機

- `lib/core/missions/game_activity_store.dart`（純 Dart 邏輯＋shared_preferences 存取，照 `save_service.dart` 慣例加 `LocalSavableKey.gameActivity`）：
  - `GameActivity {slug, stage?, seconds, at}`；`GameActivityLog` 依本地日期（沿用 `gaitDateKey` 的格式）分組，只留最近 8 天。
  - `static GameActivity? tryParse(Object? args, DateTime at)`：照上面規則驗格式，不合格回 null。
  - 查詢：某天玩過哪些 slug、某 slug 最近一次玩是哪天、某天每個 slug 的總秒數。
- Riverpod：`gameActivityProvider`（Notifier，啟動載入、`record(GameActivity)` 存檔；寫法照 `last_foot_check_provider.dart`）。
- `PlazaBridge` 加常數 `gameActivity`；`plaza_tab_page.dart` 加 handler：來源檢查同 `gameSaveLoad`，`tryParse` 合格就 `record`，回 `{ok: true}`，不合格回 `{ok: false}`。
- `docs/plaza-bridge.md` 補這個 handler 的說明。
- 測試：tryParse（合格、slug 大寫／太長／含空白、stage 省略、seconds 負數／超過 10800／小數）、8 天修剪、跨日分組、存讀來回；handler 的來源檢查（照既有 gameSave 測試的寫法，若有）。

Commit：`feat(missions): remember which games were played each day`

### Task A2：任務清單與規則排任務

- `lib/core/missions/mission_catalog.dart`：上表的 id、標題 key、開法、完成判斷（純函式，輸入今天的 activity 與健檢紀錄）。`laojie` 的輪替以「一年中的第幾天 % 5」決定。
- `lib/core/missions/mission_plan.dart`：`MissionPlan {day, source: rule|ai, greeting?, items: [{id, reason?}]}`、JSON 存讀（`LocalSavableKey.dailyMissionPlan`，只存今天一份）。
- `lib/core/missions/rule_planner.dart`（純函式）`MissionPlan planByRules({today, activity, lastFootCheck})`：
  1. 最近 3 天沒做健檢 → 第一個任務 `foot_check`。
  2. 剩下的從遊戲任務（9 款＋`laojie`）挑：最近 3 天沒玩過的優先，依「一年中的第幾天」輪替起點；不夠就挑最久沒玩的。
  3. 一共 3 個，id 不重複；`source = rule`，沒有 greeting、沒有 reason。
  - **步態規則（user 11/1 加；只在 `realGaitEnabledProvider` 為真時生效）**，優先順序排在健檢之後、遊戲輪替之前：
    - G1 步數：昨天有資料、昨天之前 7 天裡至少 3 天有資料，且昨天步數 < 那幾天平均的 0.7 倍 → 排 `walkgroup`（揪團健走）。
    - G2 步頻：最近一個有等級的週，行動力的步頻細項是 D 或 E → 排 `rhythm`（節奏踩踩）。
    - 只加任務、不寫任何健康評語；步態關著時完全不看這些資料。
  - 同一天固定：面板第一次算出來就存起來，當天再打開讀存檔，不會因為玩了遊戲而換任務。
- 測試：從沒健檢→第一個是健檢；昨天做過健檢→沒有健檢任務；最近 3 天玩過的不優先；同一天兩次呼叫結果一樣；換天會換；永遠 3 個且不重複；`racer`／`golf` 永遠不會出現。

Commit：`feat(missions): pick today's missions from the wearer's own activity`

### Task A3：面板改用排好的任務

- `daily_missions_bottom_modal.dart`：任務改成讀今天的 `MissionPlan`（沒有就用 `planByRules` 算並存起來），每列顯示標題、（有的話）理由、完成或「去完成」按鈕；按鈕依 catalog 開到對的地方（健檢照現在的寫法，遊戲用既有的遊戲 WebView 路由，參考現在 `mission_balance_game` 的導頁方式）。
- 完成判斷照上表，真的做了才算完成。
- 面板上方的副標（還剩幾個）照現在的寫法依完成數算。
- 字串：每個任務的標題 key（例：`mission_play_fish` →「玩一局粗哥接魚」）；名稱照 slug 清單檔的中文名；英文不含逗號；中文全形標點。
- 拿掉不再用的舊任務字串（若沒有別處引用）。
- 測試：widget 測試（用 `settleTranslations`）——從沒健檢、沒玩遊戲 → 3 列、第一列是健檢；記一筆 `fish` activity 且今天的任務有 fish → 那列顯示已完成。

Commit：`feat(missions): daily missions sheet shows today's planned missions`

---

## 批 B：AI（開關 `AI_MISSIONS`，預設關，不接金鑰）

### Task B1：伺服器函式與資料表（只寫、不部署、不套用）

- `supabase/migrations/20261101130000_daily_mission_plans.sql`：
  `daily_mission_plans(user_id uuid references auth.users on delete cascade, day date, status text check in ('pending','done','failed'), payload jsonb, created_at timestamptz default now(), primary key (user_id, day))`；開 RLS、**不給任何政策**、`revoke all ... from anon, authenticated`（只有 service role 用）。檔頭中文說明。
- `supabase/functions/daily-missions/logic.ts`（**不 import 任何東西**，純函式，可用 Node 24 直接跑測試）：
  - `MISSION_IDS`（同上表 11 個）。
  - `validateInput(body)`：`day` 為 `yyyy-MM-dd` 且與伺服器 UTC 日期相差 ≤ 1 天；`stats` 只接受下列欄位，型別與範圍都檢查，其他欄位一律丟掉：
    - `games_yesterday`: 最多 20 筆 `{slug, stage?, seconds}`（同 App 的格式規則）
    - `games_7d`: 最多 30 筆 `{slug, plays}`（plays 0–200）
    - `foot_check_days_ago`: 0–365 或 null；`foot_check_rating`: `good|veryGood|excellent|null`
    - `gait`（可省略）：`steps` 0–100000、`cadence` 0–250、`walking_min` 0–1440、`mobility_grade` `a|b|c|d|e|null`
    - **沒有任何使用者輸入的文字欄位**（不讓人透過這支函式對模型下指令）。
  - `buildPrompt(stats, day)`：system 提示（繁體中文〔臺灣〕、對長輩說話、溫暖簡短、只跟自己比、**不給醫療或健康判斷、不出現「治療、診斷、處方、風險、異常、安全、沒問題、病」**；從清單挑剛好 3 個不重複 id；greeting ≤ 30 字、每個 reason ≤ 20 字；`laojie` 只說「踩進老街」不指定關卡）＋ user 訊息（統計轉成條列文字，id 清單附中文名）。
  - `validateOutput(obj)`：3 個、不重複、都在清單內；長度上限；不含禁用字；不合格回 null。
- `supabase/functions/daily-missions/index.ts`（Deno）：
  1. 只收 POST；用呼叫者 JWT 查使用者（寫法照 `supabase/functions/delete-account/index.ts`），沒登入 401。
  2. `ANTHROPIC_API_KEY` 沒設 → 回 `{mode: "fallback", reason: "not_configured"}`（200），**不寫任何資料**。
  3. `validateInput` 失敗 → 400。
  4. 全站當天已有 ≥ 5000 列 → `{mode: "fallback", reason: "daily_cap"}`。
  5. 搶位：`insert (user_id, day, status='pending') on conflict do nothing`；沒搶到就讀那列——`done` 回它的 payload（`mode: "ai"`）、`pending`／`failed` 回 `{mode: "fallback", reason: "busy"|"failed"}`。保證一人一天最多呼叫一次 Claude，並發也一樣。
  6. 呼叫 Claude：官方 SDK `npm:@anthropic-ai/sdk`＋`npm:zod`，`client.messages.parse({model: "claude-haiku-5-5", max_tokens: 2000, output_config: {effort: "low", format: zodOutputFormat(schema)}, system, messages})`；`stop_reason === "refusal"` 或 `parsed_output` 為 null 或 `validateOutput` 失敗 → 標 `failed`、回 fallback。成功 → 標 `done` 存 payload、回 `{mode: "ai", greeting, missions: [{id, reason}]}`。整段 8 秒逾時。
  7. 錯誤一律不把模型原文或金鑰資訊回給客戶端。
- `supabase/functions/daily-missions/logic.test.ts`：`node --test` 跑（Node 24 原生支援 TS 型別剝除）；涵蓋 validateInput（多餘欄位被丟、超範圍拒絕、日期差 2 天拒絕）、validateOutput（重複 id、清單外 id、超長、含禁用字）、buildPrompt 含所有 id 且不含 racer／golf。在 `supabase/tests/package.json` 加 `"test:missions": "node --test ../functions/daily-missions/logic.test.ts"`。
- `supabase/README.md`：補檔案表兩列與「部署方式」（要 user 同意：設 `ANTHROPIC_API_KEY` secret、`supabase functions deploy daily-missions`、套 migration）。

Commit：`feat(supabase): daily-missions function written for Claude Haiku 5.5 (not deployed)`

### Task B2：App 端 AI 與同意

- `Constants.aiMissions`（`--dart-define=AI_MISSIONS=on`）＋`aiMissionsEnabledProvider`（**debug 也預設關**，因為還沒有金鑰）。
- `lib/core/missions/ai_mission_client.dart`：`supabase.functions.invoke('daily-missions', body: {...})`，8 秒逾時；`mode == "ai"` 且 id 都在 App 的 catalog → 轉成 `MissionPlan(source: ai, greeting, items with reason)`；其他情況回 null。送出的 stats 只照 B1 列的欄位組；`gait` 只在 `realGaitEnabledProvider` 為真時帶。
- 同意：`LocalSavableKey.aiMissionsConsent`（`unset|yes|no`）。開關關時完全不出現同意、不呼叫伺服器。開關開時：
  - 第一次打開面板且 consent 為 unset → 先跳說明（送哪些數字：昨天玩過的遊戲與秒數、最近一次健檢是幾天前與結果、步態開關開時加步數／步頻／走路時間／行動力等級；送到「動域科技的伺服器，再交給 Anthropic 的 Claude 產生文字」；不送姓名、不存原始資料）＋「同意」「先不要」兩顆按鈕。
  - 面板底部一個開關「AI 幫我排任務」（只在 `aiMissions` 開時出現），切換即改 consent。
  - 今天的計畫：consent=yes 且今天還沒有 `source: ai` 的計畫 → 呼叫 client；成功存成 ai 計畫；失敗就用規則計畫（當天不再重試）。
- 面板：`source == ai` 時上方顯示 greeting，任務列顯示 reason，標題旁一個「AI 推薦」標籤（**圖示＋文字**）；`rule` 時不顯示這些。不放粗哥頭像。
- 字串：同意說明、按鈕、開關、`AI 推薦`；英文不含逗號；中文全形標點。
- 測試：開關關 → 從不呼叫 client、沒有同意與開關；開關開＋consent unset → 先出同意；按「先不要」→ 規則計畫、沒有 AI 標籤；consent yes＋fake client 回 ai → greeting 與「AI 推薦」出現；fake client 回 null → 規則計畫。client 用 provider 注入假實作。

Commit：`feat(missions): AI-written missions behind AI_MISSIONS with first-use consent`

---

## 完成條件

- [ ] 正式版（不加 `AI_MISSIONS`）：面板依資料排 3 個任務、遊戲真的玩過才算完成；沒有同意視窗、沒有 AI 標籤、不呼叫伺服器
- [ ] `flutter analyze lib test` 沒有新問題；`flutter test` 全過；`npm run test:missions` 全過
- [ ] 函式、migration 只在 repo，**沒有部署、沒有套用、沒有碰金鑰**
- [ ] 分支只在本地，不推
