# 行動力等級（A–E）接進步態分頁

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. TDD. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 步態分頁最上面加一張「行動力」卡：這週跟自己前幾週比的 A–E 主等級＋說明句＋各細項等級與小趨勢線。

**Base：** `feat/mobility-grade-app` 從 `feat/daily-gait`（PR SilverSole-Studio/silversole-app#12）的 `e86e4b1` 開。引擎原型 `lib/core/gait/mobility_grade.dart`＋`test/gait_mobility_grade_test.dart`（7 個測試）由「公司主線計畫」視窗寫好，已複製進來、尚未 commit。

## 使用者已決定（2026-10-31）

| 項目 | 決定 |
|---|---|
| 給誰看 | **現在就在 App 裡顯示 A–E**（家屬端還沒有，不等） |
| 位置 | 步態分頁最上面一張卡，週／4 週／12 週都顯示 |
| 主等級 | 字母＋顏色（A 綠、B 淺綠、C 中性、D 橘、E 紅），字母一定要有，不能只靠顏色 |
| 細項 | 每天步數、步頻、左右對稱、每步時間差異、雙腳支撐期，各自字母等級＋小趨勢線；算不出來的不放 |
| 名稱與用詞 | 叫「行動力」，只跟自己比；**不出現「風險、異常、安全、沒問題」**；A 只代表比平常進步 |
| 免責 | 卡片底部固定「本紀錄為健康促進與運動參與紀錄，非醫療診斷」 |
| 範例頁 | 步態功能關著（範例頁）時**不放**這張卡 |
| 不做 | E 推播家屬、家屬端、長輩同意、一季前長期對照、起身時間、走路穩定 |

## 引擎規則（原型已實作，不改）

週一到週日一週；當週穿滿 3 天才評、也才當基準；基準＝前面最多 8 個合格週的中位數，至少 2 週；分數＝變化 ÷ 有意義變化（步數 20%、步頻 5%、對稱 0.03、步幅變異 0.01、雙腳支撐 0.03），正的＝變好，夾 ±2；A ≥ 1、B ≥ 0.4、C > −0.4，其餘 D；≤ −1 且上一個日曆週也 ≤ −1 才 E；主等級＝至少 2 個細項分數的平均。

---

## 檔案

| 檔案 | 動作 |
|---|---|
| `lib/core/gait/mobility_grade.dart`、`test/gait_mobility_grade_test.dart` | 原型入庫；Task 1 小改 |
| `lib/core/gait/daily_gait.dart` | 加公開的 `meanDailyStrideCv`、`finiteOrNull`（從 `gait_real_snapshot.dart` 搬出來共用） |
| `lib/shared/models/gait_real_snapshot.dart` | 改用上面兩個公開函式（行為不變） |
| `lib/shared/models/mobility_card.dart` | 新增：卡片要顯示的內容（純 Dart） |
| `lib/shared/widgets/gait/gait_charts.dart` | `_Sparkline` 改成公開 `GaitSparkline`（行為不變） |
| `lib/shared/widgets/gait/mobility_card_view.dart` | 新增：卡片元件（兩個主題共用，用 colorScheme／AppTokens） |
| `lib/shared/providers/gait_providers.dart` | 加 `mobilityCardProvider` |
| `lib/shared/widgets/gait/gait_panel.dart`、`gait_panel_t2.dart` | 加選填參數 `mobility`，放在最上面（範例橫幅之後） |
| `lib/shared/pages/analytics_page.dart`、`theme_two/analytics_page_t2.dart` | 傳 `ref.watch(mobilityCardProvider)` |
| `assets/translations/strings.csv` | 新字串（尾端；英文不含逗號、中文全形標點） |
| `CLAUDE.md` | 管線狀態的 Gait 那條補一句行動力 |

---

### Task 1：引擎入庫，跟上步態分支的算法

1. 先把原型兩個檔原樣 commit：`feat(gait): weekly mobility grades against the wearer's own weeks`（訊息內文註明原型由「公司主線計畫」視窗撰寫）。跑 `flutter test test/gait_mobility_grade_test.dart` 確認 7 個過。
2. 把 `gait_real_snapshot.dart` 的私有 `_meanStrideCv`、`_finite` 搬到 `daily_gait.dart`，改名公開為 `double? meanDailyStrideCv(Iterable<DailyGait> days)`（每天自己的 strideCv 依 strides 加權平均，略過 null／非有限值，沒有就 null）與 `double? finiteOrNull(double? v)`；`gait_real_snapshot.dart` 改呼叫它們。`test/gait_real_snapshot_test.dart` 不改且要全過。
3. `mobility_grade.dart`：
   - `_weekValues` 的 `strideVariation` 改用 `meanDailyStrideCv(days)`；其他四項包 `finiteOrNull`，非有限值就不放進 map。
   - `WeekMobility` 加 `final Map<MobilityMetric, double> values;`（當週每個細項的值，不論有沒有評分），給趨勢線用。
   - 測試先寫：「每步時間差異不會因為兩天快慢不同而變大」——一週 3 天，每天自己的 CV 都是 0、但步幅分別 1000／1200 ms → 當週 `values[strideVariation] == 0`。另加一個：某天 stance 全 0（會產生 NaN）→ `gradeMobility` 不丟例外、該週沒有 symmetry 這項。

Commit：`fix(gait): grade stride variation per day and skip non-finite values`

### Task 2：`MobilityCard`（卡片內容，純 Dart）

`lib/shared/models/mobility_card.dart`：

```dart
sealed class MobilityCard {}

/// Not enough weeks yet: how many qualifying weeks exist, out of how many needed.
class MobilityPending extends MobilityCard { final int weeksSoFar; final int weeksNeeded; }

class MobilityGraded extends MobilityCard {
  final String weekStart;          // gaitDateKey of the Monday shown
  final bool isCurrentWeek;
  final MobilityGrade grade;
  final List<MobilityChange> changes; // ≤ 2 items, for the explanation sentence
  final List<MobilityMetricRow> rows; // metrics that have a grade this week, in MobilityMetric order
}

class MobilityChange { final MobilityMetric metric; final bool better; }
class MobilityMetricRow { final MobilityMetric metric; final MobilityGrade grade; final List<double> trend; }

MobilityCard mobilityCard(List<WeekMobility> weeks, {required DateTime today});
```

規則：

- 顯示的週：**本週**（含 today 的那個週一起算）若有 `grade` 就用本週、`isCurrentWeek = true`；否則用最近一個有 `grade` 的週。
- 都沒有等級 → `MobilityPending(weeksSoFar: 穿滿 minWornDays 的週數, weeksNeeded: minBaselineWeeks + 1)`（要 2 週基準＋1 週被比較）。
- `changes`：主等級是 A／B → 取 `week.better` 前 2 個，`better: true`；D／E → 取 `week.worse` 前 2 個，`better: false`；C → 空。
- `rows[i].trend`：該細項在顯示週（含）以前、最多 8 個有這個值的週的 `values[metric]`，舊到新；不足 2 點就給空 list（元件不畫線）。

測試 `test/mobility_card_test.dart`：沒資料 → pending(0, 3)；兩個合格週 → pending(2, 3)；本週穿 3 天且有等級 → 顯示本週；本週只穿 1 天 → 顯示上一個有等級的週、isCurrentWeek false；A 週 changes 是 better 前 2 名；C 週 changes 空；趨勢最多 8 點、舊到新。可以用 `gait_mobility_grade_test.dart` 的 `_day` 寫法做測試資料（複製一份到新測試檔，或抽到 `test/helpers/`）。

Commit：`feat(gait): decide what the mobility card shows`

### Task 3：卡片元件

1. `gait_charts.dart`：`_Sparkline` 改名公開 `GaitSparkline`（建構子參數不變），檔內呼叫端跟著改。既有 gait panel 測試不改且要過。
2. `lib/shared/widgets/gait/mobility_card_view.dart`：`MobilityCardView({required MobilityCard card})`，key `MobilityCardView.cardKey`。
   - 標題「行動力」＋副標「跟自己前幾週比」。
   - `MobilityGraded`：
     - 週標籤：本週 →「本週（進行中）」；否則「{M/d} 那週」（M/d 為那個週一）。
     - 主等級：圓角方塊填等級色、裡面大字母（白字或 onColor），旁邊等級說明一句。
     - 說明句：`changes` 非空時「這週主要是{A}、{B}」，每個細項依 better 用對應片語（見字串表）；空的不顯示。
     - 細項列：每列「細項名＋字母小方塊（同色）＋`GaitSparkline`（trend 空就不畫）」。
   - `MobilityPending`：一句「每週至少穿 3 天、累積 2 週後開始跟自己比較，目前 {weeksSoFar} 週」，**不放字母、不放色塊**。
   - 最底下永遠一行免責（小字）。
   - 等級色：A `tokens.success`、B `Color.lerp(tokens.success, colorScheme.surface, 0.35)`、C `colorScheme.onSurfaceVariant`、D `tokens.dataOrange`、E `tokens.alert`。若吉祥物主題的 Theme 沒掛 `AppTokens`，改用 `AppPaletteT2` 對應色並在報告說明。
3. 字串（全部加在 CSV 尾端）：

| key | en | zh_TW |
|---|---|---|
| mobility_title | Mobility | 行動力 |
| mobility_subtitle | Compared with your own recent weeks | 跟自己前幾週比 |
| mobility_week_current | This week (in progress) | 本週（進行中） |
| mobility_week_of | Week of {} | {} 那週 |
| mobility_grade_a | Much better than usual | 比平常進步很多 |
| mobility_grade_b | A little better than usual | 比平常好一點 |
| mobility_grade_c | About the same as usual | 跟平常差不多 |
| mobility_grade_d | A little less than usual | 比平常少一點 |
| mobility_grade_e | Less than usual two weeks running | 連續兩週比平常少 |
| mobility_mainly | This week mainly: {} | 這週主要是{} |
| mobility_joiner | ` and ` | 、 |
| mobility_change_dailySteps_up / _down | more steps each day / fewer steps each day | 每天步數變多／每天步數變少 |
| mobility_change_cadence_up / _down | a quicker cadence / a slower cadence | 步頻變快／步頻變慢 |
| mobility_change_symmetry_up / _down | more even feet / a bigger gap between feet | 左右腳更平均／左右腳差距變大 |
| mobility_change_strideVariation_up / _down | a steadier rhythm / a less even rhythm | 節奏更穩／節奏比較不平均 |
| mobility_change_doubleSupport_up / _down | less time on both feet / more time on both feet | 雙腳同時著地的時間變短／變長 |
| mobility_metric_dailySteps … doubleSupport | 用既有 `gait_metric_daily_steps`、`gait_metric_cadence`、`gait_metric_symmetry`、`gait_metric_stride_cv`、`gait_metric_double_support` | 同左 |
| mobility_pending | Comparisons start after 2 weeks with at least 3 worn days each · {} so far | 每週至少穿 3 天、累積 2 週後開始跟自己比較，目前 {} 週 |
| mobility_disclaimer | This record is for health promotion and exercise participation and is not a medical diagnosis | 本紀錄為健康促進與運動參與紀錄，非醫療診斷 |

（`_up` = 變好方向，`_down` = 變差方向；「／」分開的是兩個 key 的值。`mobility_joiner` 英文值含前後空白，CSV 裡照寫即可，若 loader 會吃掉空白就改用 "and" 並在程式裡補空白，報告說明。）

**用詞紅線檢查：** 寫完後 `grep -n "風險\|異常\|安全\|沒問題\|risk\|abnormal\|safe" assets/translations/strings.csv | grep mobility_` 必須沒有結果。

測試 `test/mobility_card_view_test.dart`（用 `settleTranslations`）：graded A → 看得到字母「A」、說明「Much better than usual」、「This week mainly: more steps each day…」、免責；pending → 看得到 pending 句與免責、看不到任何單一字母等級；只有部分細項 → 只有那幾列。

Commit：`feat(gait): mobility card with grade letter and trend lines`

### Task 4：接上步態分頁

- `gait_providers.dart`：`mobilityCardProvider = Provider.autoDispose<MobilityCard?>`：步態功能關 → null；開 → `mobilityCard(gradeMobility(ref.watch(gaitHistoryProvider)), today: clock.now())`。
- 兩個 panel 加 `final MobilityCard? mobility;`（選填），非 null 時在範例橫幅之後、pending／hero 之前放 `MobilityCardView`（經典主題包在既有卡片樣式裡、吉祥物主題用 `MascotCard`，或讓 `MobilityCardView` 自己帶外框——擇一，兩個主題看起來要跟同頁其他卡一致）。
- 兩個分析頁傳 `mobility: ref.watch(mobilityCardProvider)`。
- 測試：`test/gait_panel_real_test.dart` 加一個案例——真資料模式、歷史只有今天一天 → 看得到行動力卡的 pending 句；開關關 → `gaitViewSnapshotProvider` 範例頁時看不到行動力卡（`find.byKey(MobilityCardView.cardKey)` findsNothing）。
- `CLAUDE.md` 管線狀態 Gait 那條尾端補：`gradeMobility` (`lib/core/gait/mobility_grade.dart`) turns the stored weeks into A–E grades against the wearer's own recent weeks, shown as the mobility card at the top of the gait tab.`

驗證：`flutter analyze lib test`（不應有新問題）＋全部 `flutter test`。

Commit：`feat(gait): show the mobility card at the top of the gait tab`

---

## 完成條件

- [ ] 步態功能開：步態分頁最上面有行動力卡；資料不夠時只有 pending 句與免責
- [ ] 步態功能關：範例頁跟現在一樣，沒有行動力卡
- [ ] 字串沒有紅線用詞；免責固定出現
- [ ] 全部測試通過；分支只在本地，不推
