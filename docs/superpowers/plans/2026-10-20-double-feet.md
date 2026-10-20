# 雙腳串接 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把只能連一隻鞋墊的 BLE 管線一般化成以 chip ID 為索引的多隻，讓第二隻鞋墊連上就自動成為另一隻腳，並以「踩一下左腳」指派腳別。

**Architecture:** 每隻鞋墊一個 `BleConnectionService` 實例（該類別的狀態本來就全是 instance 欄位），由 `SoleSessionRegistry` 以 `identityKey` 持有；telemetry 改成 `NotifierProvider.family` 依 `identityKey` 分流，`FootSide` 只是疊在上面的一層對應。既有 9 個單隻消費端透過 `primaryTelemetryProvider` 轉接，行為不變。

**Tech Stack:** Flutter、Riverpod v3.1.0（無 codegen）、freezed 3.2.3 + json_serializable、flutter_blue_plus 2.1.1、easy_localization + CSV、clock + fake_async（測試）

**Spec:** `docs/superpowers/specs/2026-10-20-double-feet-design.md`

## Global Constraints

- Flutter SDK 不在預設 PATH：每個 shell 先 `export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"`。
- `flutter analyze` 必須全綠（CI 跑 `--no-fatal-warnings --no-fatal-infos`）；`flutter test` 全綠。
- Riverpod **v3**：family Notifier 的參數走**建構子**，不是 `build(arg)` —— `final p = NotifierProvider.family<N, S, String>(N.new); class N extends Notifier<S> { N(this.arg); final String arg; @override S build() => …; }`。
- flutter_blue_plus **2.1.1**：每個 GATT 操作共用一把 `"global"` mutex，跨裝置序列化。`FlutterBluePlus.setOperationQueueMode` 在這版**不存在**，不可使用。因此任何多隻鞋墊的 connect / handshake 必須**依序 await**，不可並行。
- 同時連線上限常數 `maxSoles = 2`。
- 動過任何 freezed 模型後**必須**跑 `dart run build_runner build --delete-conflicting-outputs`，產生的 `*.freezed.dart` / `*.g.dart` 要一起 commit。
- 主題一律透過 `context.colorScheme` / `context.textTheme` / `context.tokens` 行內取用。**不可**用 `Theme.of(context).colorScheme`、不可宣告 `final cs = …` 區域變數、不可寫死 hex、不可寫 `TextStyle(fontFamily/fontWeight)` 鏈。
- 新字串一律進 `assets/translations/strings.csv`（欄位 `key,en,zh_TW`），用 `.tr()` 取用。
- `Row` / `Column` 的等距間隔用 `spacing:`，不要插 `SizedBox` 當墊片。
- Commit 用 conventional 前綴（`feat:` / `fix:` / `test:` / `docs:` / `refactor:`），訊息結尾加一行
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`
- easy_localization 的 widget test：`SharedPreferences.setMockInitialValues({})` 必填，而且**一個測試檔只能 mount 一次 `EasyLocalization`**（它保留全域狀態，第二次 mount 會永遠停在 loading）。
- 實機只有一隻鞋墊可測（另兩隻借給團隊成員），雙腳流程靠 Task 13 的 debug 假鞋墊手測。

## Review Focus

spec 隱含、但沒有任務的測試天然會碰到的五件事。每一行都已經指派到擁有該程式碼的任務，並在該任務裡補成一個步驟。

1. **連線中的鞋墊通常不廣播。**「掃描結果裡沒看到」絕不能當成要斷線的理由，否則每次掃描都會砍掉正在用的連線。→ Task 3 Step 1 的測試。
2. **校正時另一隻鞋墊完全沒有資料**（FSR 故障、尚未串流）。不能因為只有一隻有壓力就把它判成左腳 —— 兩隻都收滿基線前不准下判斷。→ Task 4 Step 1 的測試。
3. **已指派左腳的鞋墊被刪除或改指派。** 左腳熱力圖要回到空輪廓，不能停在舊資料。→ Task 6 Step 1 的測試。
4. **三隻鞋墊都配對**（使用者實際擁有 3 隻）。只能連兩隻，而且必須是已校正的那一對。→ Task 2 Step 1 的測試。
5. **一隻在線、一隻離線。** 通知不能把「任一隻在線」說成兩隻都在線。→ Task 7 Step 1 的測試。

## File Structure

新增 —— 實作：

| 檔案 | 責任 |
|---|---|
| `lib/shared/models/foot_side.dart` | `FootSide` enum（左/右）與其 i18n key |
| `lib/core/ble/sole_reconcile.dart` | 純函式：`maxSoles`、`identityKeyFor`、`reconcileSoleLinks` —— 掃完一輪後該連誰、該斷誰 |
| `lib/core/ble/sole_session_registry.dart` | `SoleLink`（單隻的 session 與 per-sole 狀態）＋ `SoleSessionRegistry`（identityKey → SoleLink） |
| `lib/core/ble/foot_side_calibration.dart` | `FootSideCalibrator` 純狀態機：從兩隻的即時壓力判斷哪隻被踩 |
| `lib/shared/providers/foot_telemetry_provider.dart` | `footTelemetryProvider(side)`、`primarySoleKeyProvider`、`primaryTelemetryProvider` |
| `lib/shared/providers/foot_side_calibration_provider.dart` | 何時該校正、跑校正、寫回腳別 |
| `lib/shared/pages/foot_side_calibration_modal.dart` | 「請用左腳踩一下」的 modal |
| `lib/core/ble/debug_fake_sole.dart` | `kDebugMode` 限定的假第二隻鞋墊 |

修改的檔案與理由寫在各任務的 **Files** 區塊。

> 這份計畫比 spec §12 的檔案清單多兩個檔：`lib/core/ble/sole_reconcile.dart`（spec 把這段邏輯留在編排層裡，拆出來才測得到）與 `lib/shared/models/device_view_data.dart`（`buildDeviceRows` 寫死了「一次只有一隻連線」）。合計約 32 個檔案，不是 spec 寫的 30。

---
### Task 1: 腳別模型、互斥指派、持久化

**Files:**
- Create: `lib/shared/models/foot_side.dart`
- Modify: `lib/shared/models/ble_paired_device_model.dart`（新增 `footSide` 欄位）
- Modify: `lib/core/data/save_service.dart`（新增純函式 `assignFootSide` 與 `setLocalFootSide`）
- Modify: `lib/shared/models/app_settings.dart`（新增 `soleFor` / `unassignedSoles`）
- Modify: `lib/shared/providers/settings_provider.dart`（新增 `setFootSide`）
- Test: `test/foot_side_assign_test.dart`

**Interfaces:**
- Consumes: 無（第一個任務）
- Produces:
  - `enum FootSide { left, right }`，欄位 `String labelKey`，getter `FootSide get other`
  - `BlePairedDevice.footSide` → `FootSide?`
  - `List<BlePairedDevice> assignFootSide(List<BlePairedDevice> list, String identityKey, FootSide? side)`
  - `Future<void> setLocalFootSide(String identityKey, FootSide? side)`
  - `BlePairedDevice? AppSettings.soleFor(FootSide side)`
  - `List<BlePairedDevice> AppSettings.unassignedSoles`
  - `Future<void> SettingsNotifier.setFootSide(String identityKey, FootSide? side)`

- [ ] **Step 1: 建立 `FootSide`**

```dart
// lib/shared/models/foot_side.dart
/// Which foot a sole is worn on.
///
/// The firmware has no left/right concept — every sole runs the same image and
/// is told apart only by its chip ID — so the side is assigned by the app and
/// stored on the paired entry. See
/// `docs/superpowers/specs/2026-10-20-double-feet-design.md`.
enum FootSide {
  left('left_foot'),
  right('right_foot');

  const FootSide(this.labelKey);

  /// Key in `strings.csv`.
  final String labelKey;

  /// The other foot — assigning one sole a side gives the other sole this.
  FootSide get other => this == FootSide.left ? FootSide.right : FootSide.left;
}
```

- [ ] **Step 2: 在 `BlePairedDevice` 加上 `footSide`**

在 `lib/shared/models/ble_paired_device_model.dart` 的 import 區加上：

```dart
import 'package:silversole/shared/models/foot_side.dart';
```

在 `const factory BlePairedDevice({...})` 的 `lastBatteryPercent` 之後、`isPreferred` 之前插入：

```dart
    /// Which foot this sole is worn on, or null until it has been assigned.
    /// The firmware reports nothing about this — see [FootSide].
    FootSide? footSide,
```

- [ ] **Step 3: 重新產生 freezed / json 程式碼**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
dart run build_runner build --delete-conflicting-outputs
```
Expected: 成功，`ble_paired_device_model.freezed.dart` 與 `.g.dart` 被更新（`footSide` 以 enum 名稱字串進出 JSON）。

- [ ] **Step 4: 寫會失敗的測試**

```dart
// test/foot_side_assign_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';

BlePairedDevice _sole(String id, {FootSide? side}) =>
    BlePairedDevice(remoteId: 'addr-$id', name: 'SilverSole', deviceId: id, footSide: side);

FootSide? _sideOf(List<BlePairedDevice> list, String id) =>
    list.firstWhere((d) => d.deviceId == id).footSide;

void main() {
  group('assignFootSide', () {
    test('assigns the side to the target sole', () {
      final out = assignFootSide([_sole('A'), _sole('B')], 'A', FootSide.left);
      expect(_sideOf(out, 'A'), FootSide.left);
      expect(_sideOf(out, 'B'), isNull);
    });

    test('one foot cannot have two soles: the previous holder is cleared', () {
      final out = assignFootSide(
        [_sole('A', side: FootSide.left), _sole('B')],
        'B',
        FootSide.left,
      );
      expect(_sideOf(out, 'A'), isNull);
      expect(_sideOf(out, 'B'), FootSide.left);
    });

    test('assigning one side leaves the other side alone', () {
      final out = assignFootSide(
        [_sole('A', side: FootSide.right), _sole('B')],
        'B',
        FootSide.left,
      );
      expect(_sideOf(out, 'A'), FootSide.right);
      expect(_sideOf(out, 'B'), FootSide.left);
    });

    test('null clears only the target', () {
      final out = assignFootSide(
        [_sole('A', side: FootSide.left), _sole('B', side: FootSide.right)],
        'A',
        null,
      );
      expect(_sideOf(out, 'A'), isNull);
      expect(_sideOf(out, 'B'), FootSide.right);
    });

    test('an unknown key changes nothing', () {
      final before = [_sole('A', side: FootSide.left)];
      expect(assignFootSide(before, 'NOPE', FootSide.right), before);
    });
  });

  group('AppSettings', () {
    test('soleFor finds the sole worn on a side, and nothing otherwise', () {
      // Imported here rather than at the top so this task's test file states
      // exactly what it exercises.
      final settings = _settingsWith([_sole('A', side: FootSide.right)]);
      expect(settings.soleFor(FootSide.right)?.deviceId, 'A');
      expect(settings.soleFor(FootSide.left), isNull);
    });

    test('unassignedSoles lists only the soles with no side yet', () {
      final settings = _settingsWith([
        _sole('A', side: FootSide.right),
        _sole('B'),
        _sole('C'),
      ]);
      expect(
        settings.unassignedSoles.map((d) => d.deviceId),
        ['B', 'C'],
      );
    });
  });
}
```

在檔案最上方的 import 之後加上這個 helper 與 import：

```dart
import 'package:silversole/shared/models/app_settings.dart';

AppSettings _settingsWith(List<BlePairedDevice> soles) =>
    AppSettings(pairedDevicesList: soles);
```

- [ ] **Step 5: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_side_assign_test.dart
```
Expected: FAIL —— `assignFootSide`、`soleFor`、`unassignedSoles` 都還不存在（編譯錯誤）。

- [ ] **Step 6: 實作 `assignFootSide` 與 `setLocalFootSide`**

在 `lib/core/data/save_service.dart` 的 `upsertPairedDevice` 之後加入（並在檔案頂端 import `foot_side.dart`）：

```dart
/// Marks the sole keyed [identityKey] as worn on [side], clearing that side
/// from every other entry — one foot cannot have two soles. A null [side]
/// only clears the target's own side.
List<BlePairedDevice> assignFootSide(
  List<BlePairedDevice> list,
  String identityKey,
  FootSide? side,
) => [
  for (final entry in list)
    if (entry.identityKey == identityKey)
      entry.copyWith(footSide: side)
    else if (side != null && entry.footSide == side)
      entry.copyWith(footSide: null)
    else
      entry,
];

Future<void> setLocalFootSide(String identityKey, FootSide? side) async {
  final list = await loadLocalPairedDevices() ?? [];
  await setLocalPairedDevices(assignFootSide(list, identityKey, side));
}
```

- [ ] **Step 7: 實作 `AppSettings` 的兩個 getter**

在 `lib/shared/models/app_settings.dart` 的 `preferredDevice` 之後加入（並 import `foot_side.dart`）：

```dart
  /// The sole worn on [side], or null when no sole is assigned to that foot.
  BlePairedDevice? soleFor(FootSide side) =>
      pairedDevicesList.firstWhereOrNull((d) => d.footSide == side);

  /// Paired soles with no foot side yet — what the calibration flow asks
  /// the wearer to sort out.
  List<BlePairedDevice> get unassignedSoles =>
      pairedDevicesList.where((d) => d.footSide == null).toList();
```

- [ ] **Step 8: 實作 `SettingsNotifier.setFootSide`**

在 `lib/shared/providers/settings_provider.dart` 的 `setPreferredDevice` 之後加入（並 import `foot_side.dart`）：

```dart
  /// Assigns [side] to the sole keyed [identityKey], clearing that side from
  /// any other sole — see [assignFootSide].
  Future<void> setFootSide(String identityKey, FootSide? side) async {
    await setLocalFootSide(identityKey, side);
    state = state.copyWith(
      pairedDevicesList: await loadLocalPairedDevices() ?? [],
    );
  }
```

- [ ] **Step 9: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_side_assign_test.dart && flutter analyze lib test
```
Expected: 測試 PASS，analyze 無 error。

- [ ] **Step 10: Commit**

```bash
git add lib/shared/models/foot_side.dart lib/shared/models/ble_paired_device_model.dart lib/shared/models/ble_paired_device_model.freezed.dart lib/shared/models/ble_paired_device_model.g.dart lib/shared/models/app_settings.dart lib/shared/models/app_settings.freezed.dart lib/core/data/save_service.dart lib/shared/providers/settings_provider.dart test/foot_side_assign_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): remember which foot a sole is worn on

The firmware reports no side, so the app has to hold it. Assignment is
exclusive: giving one sole a foot takes it off whichever sole had it.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 2: `pickSoles` —— 一次挑出該連的那幾隻

**Files:**
- Modify: `lib/core/ble/sole_scanner.dart`（`pickSole` → `pickSoles`，`pickSole` 變薄包裝）
- Test: `test/sole_scanner_test.dart`（擴充，現有 `pickSole` 案例必須全部照過）

**Interfaces:**
- Consumes: Task 1 的 `FootSide`、`BlePairedDevice.footSide`
- Produces: `List<SoleCandidate> pickSoles(List<SoleCandidate> candidates, {required List<BlePairedDevice> paired, int max = 2})`

- [ ] **Step 1: 寫會失敗的測試**

在 `test/sole_scanner_test.dart` 的 `_paired` helper 加上腳別參數 —— 把現有的 helper 整個換成：

```dart
BlePairedDevice _paired(
  String remoteId, {
  String? deviceId,
  bool preferred = false,
  FootSide? side,
}) => BlePairedDevice(
  remoteId: remoteId,
  name: 'SilverSole',
  deviceId: deviceId,
  isPreferred: preferred,
  footSide: side,
);
```

並在頂端加 `import 'package:silversole/shared/models/foot_side.dart';`。

然後在 `group('pickSole', …)` 之後加入新的 group：

```dart
  group('pickSoles', () {
    test('returns the calibrated pair, left first', () {
      final picks = pickSoles(
        [_sole('r', -70, deviceId: 'R'), _sole('l', -80, deviceId: 'L')],
        paired: [
          _paired('r', deviceId: 'R', side: FootSide.right),
          _paired('l', deviceId: 'L', side: FootSide.left),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['L', 'R']);
    });

    // The wearer owns three soles; only two can be connected at once, and it
    // has to be the pair they calibrated — not whichever two shout loudest.
    test('with three paired soles the calibrated pair wins', () {
      final picks = pickSoles(
        [
          _sole('spare', -20, deviceId: 'SPARE'),
          _sole('r', -70, deviceId: 'R'),
          _sole('l', -80, deviceId: 'L'),
        ],
        paired: [
          _paired('spare', deviceId: 'SPARE'),
          _paired('r', deviceId: 'R', side: FootSide.right),
          _paired('l', deviceId: 'L', side: FootSide.left),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['L', 'R']);
    });

    test('max caps how many come back', () {
      final picks = pickSoles(
        [_sole('a', -40, deviceId: 'A'), _sole('b', -50, deviceId: 'B')],
        paired: [_paired('a', deviceId: 'A'), _paired('b', deviceId: 'B')],
        max: 1,
      );
      expect(picks.map((c) => c.deviceId), ['A']);
    });

    test('a sole never takes two places', () {
      // The same sole is both the left foot and the primary device.
      final picks = pickSoles(
        [_sole('l', -60, deviceId: 'L')],
        paired: [
          _paired('l', deviceId: 'L', side: FootSide.left, preferred: true),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['L']);
    });

    test('an unassigned paired sole fills the second slot', () {
      final picks = pickSoles(
        [_sole('r', -70, deviceId: 'R'), _sole('x', -50, deviceId: 'X')],
        paired: [
          _paired('r', deviceId: 'R', side: FootSide.right),
          _paired('x', deviceId: 'X'),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['R', 'X']);
    });

    test('nothing paired on the air means nothing to connect to', () {
      expect(
        pickSoles(
          [_sole('s', -30, deviceId: 'STRANGER')],
          paired: [_paired('m', deviceId: 'MINE')],
        ),
        isEmpty,
      );
    });
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_scanner_test.dart
```
Expected: FAIL —— `pickSoles` 未定義。

- [ ] **Step 3: 實作 `pickSoles`，把 `pickSole` 變成薄包裝**

把 `lib/core/ble/sole_scanner.dart` 裡整個 `pickSole` 函式（含其 doc comment）換成下面這段，並在頂端 import `foot_side.dart`：

```dart
/// Picks which soles to connect to, best first, at most [max].
///
/// In order:
///
/// 1. the calibrated pair — the soles with a foot side assigned, left first;
/// 2. the primary device, when it is on the air;
/// 3. any other paired sole, strongest signal first;
/// 4. as a last resort, a sole that cannot be identified — one advertising no
///    ID, or any sole while some entry in [paired] still has no ID on record
///    (a sole paired on old firmware looks like a stranger once it reports an
///    ID, and this is how auto-connect finds it again).
///
/// A sole never takes two places. A sole that reports an ID nobody paired is
/// someone else's and is never returned.
List<SoleCandidate> pickSoles(
  List<SoleCandidate> candidates, {
  required List<BlePairedDevice> paired,
  int max = 2,
}) {
  final picked = <SoleCandidate>[];
  final taken = <String>{};

  void take(SoleCandidate? candidate) {
    if (candidate == null || picked.length >= max) return;
    if (!taken.add(candidate.remoteId)) return;
    picked.add(candidate);
  }

  Iterable<SoleCandidate> byStrength(Iterable<SoleCandidate> pool) => pool
      .where((c) => !taken.contains(c.remoteId))
      .sorted((a, b) => b.rssi.compareTo(a.rssi));

  for (final side in FootSide.values) {
    final sole = paired.firstWhereOrNull((d) => d.footSide == side);
    if (sole == null) continue;
    take(candidates.firstWhereOrNull((c) => isSameSole(c, sole)));
  }

  final primary = paired.firstWhereOrNull((d) => d.isPreferred);
  if (primary != null) {
    take(candidates.firstWhereOrNull((c) => isSameSole(c, primary)));
  }

  for (final candidate in byStrength(
    candidates.where((c) => paired.any((d) => isSameSole(c, d))),
  )) {
    take(candidate);
  }

  final hasLegacyEntry = paired.any((d) => d.deviceId == null);
  for (final candidate in byStrength(
    candidates.where((c) => c.deviceId == null || hasLegacyEntry),
  )) {
    take(candidate);
  }

  return picked;
}

/// The one sole to connect to — [pickSoles] with a single slot.
SoleCandidate? pickSole(
  List<SoleCandidate> candidates, {
  required List<BlePairedDevice> paired,
}) => pickSoles(candidates, paired: paired, max: 1).firstOrNull;
```

- [ ] **Step 4: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_scanner_test.dart
```
Expected: PASS —— 新的 `pickSoles` group 以及**原有 10 個 `pickSole` 案例全部**通過。

- [ ] **Step 5: Commit**

```bash
git add lib/core/ble/sole_scanner.dart test/sole_scanner_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): pick every sole worth connecting to, not just one

pickSole kept the old single-sole answer by asking for one slot, so its
priority order and every one of its tests stand unchanged.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 3: `reconcileSoleLinks` —— 掃完一輪後該連誰、該斷誰

**Files:**
- Create: `lib/core/ble/sole_reconcile.dart`
- Test: `test/sole_reconcile_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `pickSoles`（型別 `SoleCandidate`）、`isSameSole`
- Produces:
  - `const int maxSoles = 2;`
  - `String identityKeyFor(SoleCandidate candidate, List<BlePairedDevice> paired)`
  - `class SoleReconciliation { List<SoleCandidate> attach; Set<String> detach; }`
  - `SoleReconciliation reconcileSoleLinks({required List<SoleCandidate> picks, required List<BlePairedDevice> paired, required Set<String> linkedKeys, int max = maxSoles})`

- [ ] **Step 1: 寫會失敗的測試**

```dart
// test/sole_reconcile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/sole_reconcile.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

SoleCandidate _sole(String remoteId, {String? deviceId, int rssi = -60}) =>
    SoleCandidate(
      remoteId: remoteId,
      name: 'SilverSole',
      rssi: rssi,
      deviceId: deviceId,
    );

BlePairedDevice _paired(String remoteId, {String? deviceId}) =>
    BlePairedDevice(remoteId: remoteId, name: 'SilverSole', deviceId: deviceId);

void main() {
  group('identityKeyFor', () {
    test('a known sole is keyed by its paired entry', () {
      expect(
        identityKeyFor(_sole('new-addr', deviceId: 'A'), [
          _paired('old-addr', deviceId: 'A'),
        ]),
        'A',
      );
    });

    test('an unknown sole is keyed by its own ID, else its address', () {
      expect(identityKeyFor(_sole('addr', deviceId: 'Z'), const []), 'Z');
      expect(identityKeyFor(_sole('addr'), const []), 'addr');
    });
  });

  group('reconcileSoleLinks', () {
    test('attaches the picks nothing is linked to yet', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('a', deviceId: 'A'), _sole('b', deviceId: 'B')],
        paired: [_paired('a', deviceId: 'A'), _paired('b', deviceId: 'B')],
        linkedKeys: const {},
      );
      expect(plan.attach.map((c) => c.deviceId), ['A', 'B']);
      expect(plan.detach, isEmpty);
    });

    test('a sole that already has a link is left alone', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('a', deviceId: 'A'), _sole('b', deviceId: 'B')],
        paired: [_paired('a', deviceId: 'A'), _paired('b', deviceId: 'B')],
        linkedKeys: const {'A'},
      );
      expect(plan.attach.map((c) => c.deviceId), ['B']);
      expect(plan.detach, isEmpty);
    });

    // A connected sole usually stops advertising, so a scan that cannot see it
    // says nothing about whether it is still there. Dropping it here would
    // tear down a working connection on every single search.
    test('a linked sole missing from the scan is NOT detached', () {
      final plan = reconcileSoleLinks(
        picks: const [],
        paired: [_paired('a', deviceId: 'A')],
        linkedKeys: const {'A'},
      );
      expect(plan.attach, isEmpty);
      expect(plan.detach, isEmpty);
    });

    test('a link whose sole is no longer paired is detached', () {
      final plan = reconcileSoleLinks(
        picks: const [],
        paired: [_paired('a', deviceId: 'A')],
        linkedKeys: const {'A', 'GONE'},
      );
      expect(plan.detach, {'GONE'});
    });

    test('the links already held count towards max', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('b', deviceId: 'B'), _sole('c', deviceId: 'C')],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('b', deviceId: 'B'),
          _paired('c', deviceId: 'C'),
        ],
        linkedKeys: const {'A'},
      );
      expect(plan.attach.map((c) => c.deviceId), ['B']);
    });

    test('a freed slot is reused in the same pass', () {
      // 'GONE' is unpaired, so its slot opens up for C right away.
      final plan = reconcileSoleLinks(
        picks: [_sole('c', deviceId: 'C')],
        paired: [_paired('a', deviceId: 'A'), _paired('c', deviceId: 'C')],
        linkedKeys: const {'A', 'GONE'},
      );
      expect(plan.detach, {'GONE'});
      expect(plan.attach.map((c) => c.deviceId), ['C']);
    });

    test('the same sole is never attached twice in one plan', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('a', deviceId: 'A'), _sole('a2', deviceId: 'A')],
        paired: [_paired('a', deviceId: 'A')],
        linkedKeys: const {},
      );
      expect(plan.attach.length, 1);
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_reconcile_test.dart
```
Expected: FAIL —— `lib/core/ble/sole_reconcile.dart` 不存在。

- [ ] **Step 3: 實作**

```dart
// lib/core/ble/sole_reconcile.dart
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// How many soles may be connected at once — one per foot.
const int maxSoles = 2;

/// The key a scanned sole's session is held under: its paired entry's
/// [BlePairedDevice.identityKey] when the sole is known, otherwise its own ID,
/// otherwise its address.
///
/// Deliberately the *stored* entry's key: when a sole paired on old firmware
/// first reports an ID its identityKey changes, and keying off the stored
/// entry keeps the session stable for this pass. The next search re-keys it.
String identityKeyFor(
  SoleCandidate candidate,
  List<BlePairedDevice> paired,
) {
  final known = paired.firstWhereOrNull((d) => isSameSole(candidate, d));
  return known?.identityKey ?? candidate.deviceId ?? candidate.remoteId;
}

/// What the search loop should do after one scan.
@immutable
class SoleReconciliation {
  const SoleReconciliation({required this.attach, required this.detach});

  /// Soles to start a session with, best first.
  final List<SoleCandidate> attach;

  /// identityKeys whose session should be torn down.
  final Set<String> detach;
}

/// Works out which soles to connect and which sessions to drop.
///
/// [picks] is what [pickSoles] returned, [paired] the stored entries and
/// [linkedKeys] the soles that already have a session.
///
/// A sole that already has a link is never re-attached — that would drop a
/// working connection. **Being absent from [picks] is never a reason to
/// detach**: a connected sole usually stops advertising, so a scan says
/// nothing about it. Only a sole that is no longer paired loses its session.
SoleReconciliation reconcileSoleLinks({
  required List<SoleCandidate> picks,
  required List<BlePairedDevice> paired,
  required Set<String> linkedKeys,
  int max = maxSoles,
}) {
  final pairedKeys = paired.map((d) => d.identityKey).toSet();
  final detach = linkedKeys.difference(pairedKeys);
  final keeping = linkedKeys.difference(detach);

  final attach = <SoleCandidate>[];
  final attaching = <String>{};
  for (final pick in picks) {
    if (keeping.length + attach.length >= max) break;
    final key = identityKeyFor(pick, paired);
    if (keeping.contains(key) || !attaching.add(key)) continue;
    attach.add(pick);
  }

  return SoleReconciliation(attach: attach, detach: detach);
}
```

- [ ] **Step 4: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_reconcile_test.dart && flutter analyze lib test
```
Expected: 全部 PASS，analyze 無 error。

- [ ] **Step 5: Commit**

```bash
git add lib/core/ble/sole_reconcile.dart test/sole_reconcile_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): work out which sole sessions to open and close

A connected sole usually stops advertising, so a scan that cannot see it
says nothing — only unpairing closes a session.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---
### Task 4: `FootSideCalibrator` —— 從壓力判斷哪隻被踩

**Files:**
- Create: `lib/core/ble/foot_side_calibration.dart`
- Test: `test/foot_side_calibration_test.dart`

**Interfaces:**
- Consumes: 無（純 Dart，不依賴前面的任務）
- Produces:
  - `class FootSideDecision { String? leftKey; bool ambiguous; }`，建構子 `FootSideDecision.left(String)` 與 `FootSideDecision.ambiguous()`
  - `class FootSideCalibrator`，方法 `FootSideDecision? add(String soleKey, int pressureSum, DateTime at)` 與 `void reset()`

- [ ] **Step 1: 寫會失敗的測試**

```dart
// test/foot_side_calibration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/foot_side_calibration.dart';

const _left = 'L';
const _right = 'R';
final _t0 = DateTime(2026, 10, 20, 9);

/// Feeds frames [from]..[from]+[count] to both soles at 50 Hz and returns the
/// first decision that came out, or null.
FootSideDecision? _frames(
  FootSideCalibrator calibrator, {
  required int from,
  required int count,
  required int left,
  required int right,
}) {
  FootSideDecision? decision;
  for (var i = from; i < from + count; i++) {
    final at = _t0.add(Duration(milliseconds: 20 * i));
    decision ??= calibrator.add(_left, left, at);
    decision ??= calibrator.add(_right, right, at);
  }
  return decision;
}

void main() {
  test('both soles resting decides nothing', () {
    final calibrator = FootSideCalibrator();
    expect(
      _frames(calibrator, from: 0, count: 200, left: 40, right: 40),
      isNull,
    );
  });

  test('the sole that was stepped on is the left foot', () {
    final calibrator = FootSideCalibrator();
    // A second of standing still fills the baselines.
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30, // 600 ms — past the 200 ms arbitration window
      left: 2000,
      right: 40,
    );
    expect(decision?.ambiguous, isFalse);
    expect(decision?.leftKey, _left);
  });

  test('stepping on the other sole makes that one the left foot', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30,
      left: 40,
      right: 2000,
    );
    expect(decision?.leftKey, _right);
  });

  test('a step both soles felt equally is ambiguous', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30,
      left: 2000,
      right: 2000,
    );
    expect(decision?.ambiguous, isTrue);
    expect(decision?.leftKey, isNull);
  });

  test('a clearly harder step still wins when both soles move', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30,
      left: 2000,
      right: 440, // delta 400 — over the trigger, far under 80% of 1960
    );
    expect(decision?.leftKey, _left);
  });

  test('one noisy sample is not a step', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    _frames(calibrator, from: 50, count: 1, left: 2000, right: 40);
    expect(
      _frames(calibrator, from: 51, count: 30, left: 40, right: 40),
      isNull,
    );
  });

  // The other sole may be connected but silent — a dead FSR, or notifications
  // that have not started yet. Calling the only sole that reports pressure the
  // left foot would be a coin flip dressed up as a measurement.
  test('a sole that reports nothing at all blocks any decision', () {
    final calibrator = FootSideCalibrator();
    for (var i = 0; i < 50; i++) {
      calibrator.add(_left, 40, _t0.add(Duration(milliseconds: 20 * i)));
    }
    FootSideDecision? decision;
    for (var i = 50; i < 120; i++) {
      decision ??= calibrator.add(
        _left,
        2000,
        _t0.add(Duration(milliseconds: 20 * i)),
      );
    }
    expect(decision, isNull);
  });

  test('a step during baseline collection is absorbed, not trusted', () {
    final calibrator = FootSideCalibrator();
    // Pressed from the very first sample: the baseline ends up high, so the
    // same reading is no longer a step.
    final decision = _frames(
      calibrator,
      from: 0,
      count: 200,
      left: 2000,
      right: 40,
    );
    expect(decision, isNull);
  });

  test('reset starts over', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    expect(
      _frames(calibrator, from: 50, count: 30, left: 2000, right: 40)?.leftKey,
      _left,
    );
    calibrator.reset();
    expect(
      _frames(calibrator, from: 80, count: 10, left: 2000, right: 40),
      isNull,
    );
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_side_calibration_test.dart
```
Expected: FAIL —— `lib/core/ble/foot_side_calibration.dart` 不存在。

- [ ] **Step 3: 實作**

```dart
// lib/core/ble/foot_side_calibration.dart
import 'package:flutter/foundation.dart';

/// What a calibration run concluded.
@immutable
class FootSideDecision {
  /// The wearer stepped on the sole keyed [leftKey], so that is the left foot
  /// and the other sole is the right one.
  const FootSideDecision.left(String this.leftKey) : ambiguous = false;

  /// Both soles answered about equally hard, so which foot moved cannot be
  /// told from this step. The wearer is asked to try again.
  const FootSideDecision.ambiguous() : leftKey = null, ambiguous = true;

  /// Null exactly when [ambiguous].
  final String? leftKey;
  final bool ambiguous;
}

/// Decides which of two soles the wearer stepped on, from their live pressure.
///
/// The firmware reports no foot side, so this is how a sole learns it is the
/// left one: the wearer is asked to step on their left foot, and whichever
/// sole's FSRs answer is it.
///
/// Pure Dart, driven entirely by the samples handed to [add] — no BLE, no
/// timers, no clock of its own — so it is tested by feeding it frames. The
/// 15 s "nothing happened" timeout belongs to the UI, not here.
class FootSideCalibrator {
  FootSideCalibrator({
    this.requiredSoles = 2,
    this.baselineSamples = 50,
    this.triggerDelta = 300,
    this.holdSamples = 3,
    this.arbitration = const Duration(milliseconds: 200),
    this.ambiguityRatio = 0.2,
  });

  /// How many soles must be reporting before any decision is allowed. A sole
  /// that is connected but silent (a dead FSR, notifications not started yet)
  /// must not hand the verdict to the only sole that does report.
  final int requiredSoles;

  /// Resting samples collected per sole before it can trigger — at 50 Hz,
  /// about a second of standing still.
  final int baselineSamples;

  /// How far above its own baseline a sole's total pressure must rise to count
  /// as stepped on.
  final int triggerDelta;

  /// Consecutive samples over [triggerDelta] required, so one noisy sample is
  /// not a step.
  final int holdSamples;

  /// How long to keep watching after the first sole triggers. Without it the
  /// verdict would go to whichever sole's packet arrived first, which is radio
  /// timing, not the wearer's foot.
  final Duration arbitration;

  /// The runner-up counts as "just as hard" within this fraction of the
  /// winner's peak, which makes the step ambiguous.
  final double ambiguityRatio;

  final _soles = <String, _SoleTrack>{};
  DateTime? _arbitrationEnds;
  FootSideDecision? _decision;

  /// Feeds one sample, where [pressureSum] is that sole's sensors added up.
  ///
  /// Returns the decision as soon as there is one, and the same decision on
  /// every later call until [reset].
  FootSideDecision? add(String soleKey, int pressureSum, DateTime at) {
    final decided = _decision;
    if (decided != null) return decided;

    final track = _soles.putIfAbsent(soleKey, _SoleTrack.new);
    track.add(
      pressureSum,
      baselineSamples: baselineSamples,
      triggerDelta: triggerDelta,
      holdSamples: holdSamples,
    );

    final ready =
        _soles.length >= requiredSoles &&
        _soles.values.every((t) => t.hasBaseline);
    if (!ready) return null;

    if (track.stepped && _arbitrationEnds == null) {
      _arbitrationEnds = at.add(arbitration);
    }
    final ends = _arbitrationEnds;
    if (ends == null || at.isBefore(ends)) return null;
    return _decision = _decide();
  }

  /// Compares the peaks each sole reached. Peaks are tracked from the moment
  /// its baseline settled rather than only inside the arbitration window —
  /// during a resting baseline there is nothing to peak at, so the two agree,
  /// and tracking throughout means a slow press is not missed.
  FootSideDecision _decide() {
    final ranked = _soles.entries.toList()
      ..sort((a, b) => b.value.peak.compareTo(a.value.peak));
    final winner = ranked.first;
    final runnerUp = ranked.length > 1 ? ranked[1] : null;
    if (runnerUp != null &&
        runnerUp.value.peak >= winner.value.peak * (1 - ambiguityRatio)) {
      return const FootSideDecision.ambiguous();
    }
    return FootSideDecision.left(winner.key);
  }

  /// Forgets every baseline and verdict — the "try again" button.
  void reset() {
    _soles.clear();
    _arbitrationEnds = null;
    _decision = null;
  }
}

/// One sole's running baseline, peak and trigger streak.
class _SoleTrack {
  final _resting = <int>[];
  double? _baseline;
  int _over = 0;

  /// The highest reading above baseline seen so far.
  int peak = 0;
  bool stepped = false;

  bool get hasBaseline => _baseline != null;

  void add(
    int sum, {
    required int baselineSamples,
    required int triggerDelta,
    required int holdSamples,
  }) {
    final baseline = _baseline;
    if (baseline == null) {
      _resting.add(sum);
      if (_resting.length < baselineSamples) return;
      _baseline = _resting.reduce((a, b) => a + b) / _resting.length;
      return;
    }
    final delta = (sum - baseline).round();
    if (delta > peak) peak = delta;
    if (delta >= triggerDelta) {
      _over++;
      if (_over >= holdSamples) stepped = true;
    } else {
      _over = 0;
    }
  }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_side_calibration_test.dart && flutter analyze lib test
```
Expected: 9 個測試全 PASS，analyze 無 error。

- [ ] **Step 5: Commit**

```bash
git add lib/core/ble/foot_side_calibration.dart test/foot_side_calibration_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): tell the soles apart by which one is stepped on

The firmware says nothing about sides, so the wearer does: step on the
left foot and whichever sole's FSRs answer is the left one. A silent sole
blocks the verdict rather than handing it to the only one reporting.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 5: `SoleSessionRegistry` —— 一隻鞋墊一個 session

**Files:**
- Create: `lib/core/ble/sole_session_registry.dart`
- Modify: `lib/shared/providers/ble_connection_provider.dart`（新增 `soleSessionsProvider`，**保留**既有的 `bleConnectProvider` 讓編排層還能編譯，Task 8 才移除）
- Test: `test/sole_session_registry_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `BlePairedDevice`（已有 `footSide`）
- Produces:
  - `class SoleLink { BleConnectionService service; BlePairedDevice device; Timer? watchdog; int imuFailCount; bool get isConnected; void cancelWatchdog(); }`
  - `class SoleSessionRegistry` —— `link(String, BlePairedDevice)`、`lookup(String)`、`links`、`keys`、`connectedCount`、`anyConnected`、`detach(String)`、`detachAll()`
  - `final soleSessionsProvider = Provider<SoleSessionRegistry>(…)`

- [ ] **Step 1: 寫會失敗的測試**

```dart
// test/sole_session_registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// Stands in for a real session so the registry is tested without BLE.
/// `BleConnectionService` keeps every bit of its state per instance, so
/// subclassing it is enough.
class _FakeService extends BleConnectionService {
  bool connected = false;
  var detaches = 0;

  @override
  bool get isConnected => connected;

  @override
  Future<void> detach() async => detaches++;
}

BlePairedDevice _sole(String id, {String name = 'SilverSole'}) =>
    BlePairedDevice(remoteId: 'addr-$id', name: name, deviceId: id);

void main() {
  test('a key gets one session, reused on every later link()', () {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final first = registry.link('A', _sole('A'));
    final again = registry.link('A', _sole('A', name: 'Renamed'));

    expect(again, same(first));
    expect(again.service, same(first.service));
    // The stored device is refreshed; the live connection is not disturbed.
    expect(again.device.name, 'Renamed');
    expect(registry.keys, {'A'});
  });

  test('two soles get two independent sessions', () {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final a = registry.link('A', _sole('A'));
    final b = registry.link('B', _sole('B'));

    expect(a.service, isNot(same(b.service)));
    expect(registry.keys, {'A', 'B'});
    expect(registry.links.length, 2);
  });

  test('connectedCount and anyConnected follow the services', () {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final a = registry.link('A', _sole('A'));
    registry.link('B', _sole('B'));

    expect(registry.anyConnected, isFalse);
    expect(registry.connectedCount, 0);

    (a.service as _FakeService).connected = true;
    expect(registry.anyConnected, isTrue);
    expect(registry.connectedCount, 1);
  });

  test('detach drops the session and tears the link down', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final a = registry.link('A', _sole('A'));
    final service = a.service as _FakeService;

    await registry.detach('A');
    expect(service.detaches, 1);
    expect(registry.lookup('A'), isNull);
    expect(registry.keys, isEmpty);
  });

  test('detaching an unknown key is harmless', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    await registry.detach('NOPE');
    expect(registry.keys, isEmpty);
  });

  test('detachAll clears everything', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    registry.link('A', _sole('A'));
    registry.link('B', _sole('B'));

    await registry.detachAll();
    expect(registry.keys, isEmpty);
    expect(registry.links, isEmpty);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_session_registry_test.dart
```
Expected: FAIL —— `lib/core/ble/sole_session_registry.dart` 不存在。

- [ ] **Step 3: 實作 registry**

```dart
// lib/core/ble/sole_session_registry.dart
import 'dart:async';

import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// One sole's live session plus the per-sole state the orchestrator keeps
/// alongside it.
class SoleLink {
  SoleLink({required this.service, required this.device});

  final BleConnectionService service;

  /// The sole as the last handshake saw it. The orchestrator refreshes this
  /// (a fresh battery level, an ID a legacy entry just picked up).
  BlePairedDevice device;

  /// Re-scans when this session never connects, or does not come back after a
  /// link loss — the "give up on this MAC" path, per sole.
  Timer? watchdog;

  /// Throttles the IMU parse-failure log: a wire-format mismatch fails on
  /// every packet and would otherwise spam ~20 lines/s.
  int imuFailCount = 0;

  bool get isConnected => service.isConnected;

  void cancelWatchdog() {
    watchdog?.cancel();
    watchdog = null;
  }
}

/// Every live sole session, keyed by [BlePairedDevice.identityKey].
///
/// [BleConnectionService] already keeps all of its state per instance, so one
/// instance per sole is all two feet need; this owns those instances and their
/// lifetimes. [createService] exists so tests can stand in a fake.
class SoleSessionRegistry {
  SoleSessionRegistry({BleConnectionService Function()? createService})
    : _createService = createService ?? BleConnectionService.new;

  final BleConnectionService Function() _createService;
  final _links = <String, SoleLink>{};

  Iterable<SoleLink> get links => _links.values;

  Set<String> get keys => _links.keys.toSet();

  int get connectedCount => _links.values.where((l) => l.isConnected).length;

  bool get anyConnected => _links.values.any((l) => l.isConnected);

  SoleLink? lookup(String identityKey) => _links[identityKey];

  /// The link for [identityKey], created on first use. An existing link keeps
  /// its service — and therefore its connection — and only takes the fresher
  /// [device].
  SoleLink link(String identityKey, BlePairedDevice device) {
    final existing = _links[identityKey];
    if (existing != null) {
      existing.device = device;
      return existing;
    }
    return _links[identityKey] = SoleLink(
      service: _createService(),
      device: device,
    );
  }

  Future<void> detach(String identityKey) async {
    final link = _links.remove(identityKey);
    if (link == null) return;
    link.cancelWatchdog();
    await link.service.detach();
  }

  Future<void> detachAll() async {
    for (final key in keys) {
      await detach(key);
    }
  }
}
```

- [ ] **Step 4: 加上 provider**

把 `lib/shared/providers/ble_connection_provider.dart` 整份換成：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';

/// Every live sole session, one per foot. Base-timestamp sync is part of each
/// connection's own handshake, so there is nothing to drive from here.
final soleSessionsProvider = Provider<SoleSessionRegistry>(
  (_) => SoleSessionRegistry(),
);

/// The single live sole session.
///
/// Superseded by [soleSessionsProvider] and removed once the foreground
/// controller stops using it.
final bleConnectProvider = Provider<BleConnectionService>(
  (_) => BleConnectionService(),
);
```

- [ ] **Step 4b（修正，優先於 Step 3 的程式碼）：`SoleSessionRegistry` 必須能 re-key**

這一條來自 Task 3 的 review finding，是 Task 5 的硬契約。

一隻用 pre-ID 韌體配對的鞋墊，紀錄裡沒有 `deviceId`，所以 session 會以**位址**當 key 建立。等 handshake 讀到 chip ID 之後，那筆配對紀錄的 `identityKey` 變成那個 ID —— 但 registry 還把 session 掛在舊的位址 key 上。下一輪 `reconcileSoleLinks` 算 `linkedKeys.difference(pairedKeys)` 就會把舊 key 當成「已解除配對」，**砍掉一條正在用的連線**。這個情境單腳碰不到（搜尋迴圈滿額時提早 return），正好只在雙腳而且只連上一隻時踩到 —— 也就是「找第二腳的時候把第一腳砍掉」。

`reconcileSoleLinks` 刻意不處理這件事（keying 的歸屬在 registry，不在純決策函式），所以修在這裡。在 `SoleSessionRegistry` 裡，`detach` 之前加入：

```dart
  /// Moves a live session from [oldKey] to [newKey], keeping its service — and
  /// so its connection — intact.
  ///
  /// A sole paired on pre-ID firmware is filed under its address; the moment
  /// its handshake reports a chip ID its paired entry is keyed by that ID
  /// instead, and a session still filed under the address reads as "no longer
  /// paired" to `reconcileSoleLinks`, which would tear down a working link.
  Future<void> rekey(String oldKey, String newKey) async {
    if (oldKey == newKey) return;
    final link = _links.remove(oldKey);
    if (link == null) return;
    if (!_links.containsKey(newKey)) {
      _links[newKey] = link;
      return;
    }
    // Something is already filed under the new key — the same sole reached
    // twice. Keep that one and retire the misfiled session rather than leave
    // two links to one foot.
    link.cancelWatchdog();
    await link.service.detach();
  }
```

並在 `test/sole_session_registry_test.dart` 補三個案例：

```dart
  test('re-keying moves the session and keeps the live service', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final link = registry.link('addr', _sole('addr'));
    final service = link.service;

    await registry.rekey('addr', 'ID');

    expect(registry.lookup('addr'), isNull);
    expect(registry.lookup('ID'), same(link));
    // The connection must survive: a re-key is bookkeeping, not a reconnect.
    expect(registry.lookup('ID')!.service, same(service));
    expect((service as _FakeService).detaches, 0);
    expect(registry.keys, {'ID'});
  });

  test('re-keying onto an occupied key retires the misfiled session', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final stale = registry.link('addr', _sole('addr'));
    final live = registry.link('ID', _sole('ID'));

    await registry.rekey('addr', 'ID');

    expect(registry.keys, {'ID'});
    expect(registry.lookup('ID'), same(live));
    expect((stale.service as _FakeService).detaches, 1);
    expect((live.service as _FakeService).detaches, 0);
  });

  test('re-keying an unknown or unchanged key is harmless', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final link = registry.link('A', _sole('A'));

    await registry.rekey('NOPE', 'X');
    await registry.rekey('A', 'A');

    expect(registry.keys, {'A'});
    expect(registry.lookup('A'), same(link));
    expect((link.service as _FakeService).detaches, 0);
  });
```

- [ ] **Step 5: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_session_registry_test.dart && flutter analyze lib test
```
Expected: **9** 個測試全 PASS（原本 6 個 + Step 4b 的 3 個），analyze 無 error（舊的 `bleConnectProvider` 還在，編排層照舊編譯）。

- [ ] **Step 6: Commit**

```bash
git add lib/core/ble/sole_session_registry.dart lib/shared/providers/ble_connection_provider.dart test/sole_session_registry_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): hold one sole session per chip ID

BleConnectionService already kept every field per instance, so two feet
need an owner for two instances rather than a rewrite of the service.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---
### Task 6: Telemetry 依鞋墊分流

這是兩個核心任務的第一個。`liveTelemetryProvider` 變成 family，所有既有的單隻消費端改走 `primaryTelemetryProvider`，因此行為不變。

**Files:**
- Modify: `lib/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart`（改成 family，新增 `latestTelemetryAtProvider`）
- Create: `lib/shared/providers/foot_telemetry_provider.dart`
- Modify: `lib/shared/providers/telemetry_process_providers/telemetry_view_provider.dart`（轉發 primary）
- Modify: `lib/shared/providers/telemetry_process_providers/device_online_provider.dart`（改吃 `latestTelemetryAtProvider`）
- Modify: `lib/shared/pages/analytics_detail_page.dart:83`、`lib/shared/pages/theme_two/analytics_detail_page_t2.dart:36`（`liveTelemetryProvider` → `telemetryViewProvider`）
- Modify: `lib/shared/pages/record_session_mixin.dart:38`（telemetry notifier 需要 key）
- Modify: `lib/shared/providers/firmware_update_provider.dart`（`_preflight` 讀該隻鞋墊自己的電量）
- Test: `test/foot_telemetry_provider_test.dart`（新）
- Test: `test/device_online_provider_test.dart:34`、`test/battery_chart_gap_test.dart:48`、`test/firmware_update_provider_test.dart:212`（既有，必須修）

**Interfaces:**
- Consumes: Task 1 的 `FootSide`、`AppSettings.soleFor`
- Produces:
  - `liveTelemetryProvider` → `NotifierProvider.family<LiveTelemetryNotifier, LiveTelemetryState, String>`，key 是 `identityKey`
  - `LiveTelemetryNotifier(String soleKey)`
  - `final latestTelemetryAtProvider = NotifierProvider<LatestTelemetryAtNotifier, DateTime?>(…)`，方法 `void mark(DateTime)`
  - `final footSoleKeyProvider = Provider.family<String?, FootSide>(…)`
  - `final footTelemetryProvider = Provider.family<LiveTelemetryState, FootSide>(…)`
  - `final primarySoleKeyProvider = Provider<String?>(…)`
  - `final primaryTelemetryProvider = Provider<LiveTelemetryState>(…)`

- [ ] **Step 1: 寫會失敗的測試**

```dart
// test/foot_telemetry_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

/// Settings a test can drive directly, skipping the shared_preferences load.
class _Settings extends SettingsNotifier {
  _Settings(this._initial);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  void swap(AppSettings next) => state = next;
}

BlePairedDevice _sole(String id, {FootSide? side, bool preferred = false}) =>
    BlePairedDevice(
      remoteId: 'addr-$id',
      name: 'SilverSole',
      deviceId: id,
      footSide: side,
      isPreferred: preferred,
    );

ImuNotifyDataModel _imu(int pressure) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: [pressure, pressure, pressure],
  batteryPercent: 90,
  isCharging: false,
);

ProviderContainer _boot(List<BlePairedDevice> paired) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        () => _Settings(AppSettings(pairedDevicesList: paired)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

_Settings _settingsOf(ProviderContainer container) =>
    container.read(settingsProvider.notifier) as _Settings;

void main() {
  test('a foot with no sole assigned reads empty telemetry', () {
    final container = _boot([_sole('A')]);
    expect(container.read(footTelemetryProvider(FootSide.left)).recentImu, isEmpty);
    expect(container.read(footSoleKeyProvider(FootSide.left)), isNull);
  });

  test('telemetry reaches only the foot its sole is assigned to', () {
    final container = _boot([
      _sole('L', side: FootSide.left),
      _sole('R', side: FootSide.right),
    ]);

    container.read(liveTelemetryProvider('L').notifier).updateImuNotifyData(_imu(700));

    expect(
      container.read(footTelemetryProvider(FootSide.left)).recentImu.last.pressure,
      [700, 700, 700],
    );
    expect(container.read(footTelemetryProvider(FootSide.right)).recentImu, isEmpty);
  });

  test('the primary sole is the right foot when one is assigned', () {
    final container = _boot([
      _sole('L', side: FootSide.left, preferred: true),
      _sole('R', side: FootSide.right),
    ]);
    expect(container.read(primarySoleKeyProvider), 'R');
  });

  test('with no side assigned the primary sole is the preferred device', () {
    final container = _boot([
      _sole('A'),
      _sole('B', preferred: true),
    ]);
    expect(container.read(primarySoleKeyProvider), 'B');
  });

  test('with neither, the first paired sole is primary', () {
    final container = _boot([_sole('A'), _sole('B')]);
    expect(container.read(primarySoleKeyProvider), 'A');
  });

  test('nothing paired means no primary and empty telemetry', () {
    final container = _boot(const []);
    expect(container.read(primarySoleKeyProvider), isNull);
    expect(container.read(primaryTelemetryProvider).recentImu, isEmpty);
  });

  // Unpair (or re-assign) the left sole and the left foot has to go back to a
  // bare outline. Leaving the last reading on screen would show the wearer
  // pressure from a sole that is no longer theirs.
  test('losing the left sole empties the left foot again', () {
    final container = _boot([
      _sole('L', side: FootSide.left),
      _sole('R', side: FootSide.right),
    ]);
    container.read(liveTelemetryProvider('L').notifier).updateImuNotifyData(_imu(700));
    expect(container.read(footTelemetryProvider(FootSide.left)).recentImu, isNotEmpty);

    _settingsOf(container).swap(
      AppSettings(pairedDevicesList: [_sole('R', side: FootSide.right)]),
    );

    expect(container.read(footTelemetryProvider(FootSide.left)).recentImu, isEmpty);
  });

  test('the newest stamp across soles is what latestTelemetryAt reports', () {
    final container = _boot([
      _sole('L', side: FootSide.left),
      _sole('R', side: FootSide.right),
    ]);
    expect(container.read(latestTelemetryAtProvider), isNull);

    container.read(liveTelemetryProvider('R').notifier).updateImuNotifyData(_imu(1));
    final first = container.read(latestTelemetryAtProvider);
    expect(first, isNotNull);

    container.read(liveTelemetryProvider('L').notifier).updateImuNotifyData(_imu(2));
    expect(
      container.read(latestTelemetryAtProvider)!.isBefore(first!),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_telemetry_provider_test.dart
```
Expected: FAIL —— `foot_telemetry_provider.dart` 不存在，`liveTelemetryProvider` 還不是 family。

- [ ] **Step 3: 把 `live_telemetry_notifier.dart` 改成 family**

整份換成：

```dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/utils/imu_moving_average_filter.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';

/// Live telemetry from **one** sole, keyed by its identityKey.
///
/// One instance per sole: two feet stream at 50 Hz each and neither may
/// overwrite the other's window. Screens that mean "the sole" rather than a
/// named foot read `telemetryViewProvider`, which follows the primary sole.
class LiveTelemetryNotifier extends Notifier<LiveTelemetryState> {
  LiveTelemetryNotifier(this.soleKey);

  /// The sole this window belongs to.
  final String soleKey;

  /// Smooths incoming live samples before they are stored. Owns its own raw
  /// history, so it must not be recreated per sample — which is also why each
  /// sole needs its own notifier rather than a shared one.
  final _imuFilter = ImuMovingAverageFilter();

  @override
  LiveTelemetryState build() {
    unawaited(_load());
    return const LiveTelemetryState();
  }

  Future<void> _load() async {}

  void updateImuNotifyData(ImuNotifyDataModel data) {
    final next = [...state.recentImu, _imuFilter.apply(data)];
    final trimmed = next.length > 100 ? next.sublist(next.length - 100) : next;
    state = state.copyWith(
      recentImu: trimmed,
      source: TelemetrySource.bleLive,
      updatedAt: _stamp(),
      errorMessage: null,
    );
  }

  void updateRecordImuNotifyData(RecordImuNotifyDataModel data) {
    final next = [...state.record, data];
    // final trimmed = next.length > max ? next.sublist(next.length - max) : next;
    state = state.copyWith(
      record: next,
      source: TelemetrySource.bleLive,
      updatedAt: _stamp(),
      errorMessage: null,
    );
  }

  void clearRecordImuNotifyData() {
    state = state.copyWith(record: []);
  }

  /// Stamps now, and tells [latestTelemetryAtProvider] — which is what "the
  /// wearable is online" reads once there can be two soles.
  DateTime _stamp() {
    final now = clock.now();
    ref.read(latestTelemetryAtProvider.notifier).mark(now);
    return now;
  }
}

final liveTelemetryProvider =
    NotifierProvider.family<LiveTelemetryNotifier, LiveTelemetryState, String>(
      LiveTelemetryNotifier.new,
    );

/// The newest moment **any** sole reported live telemetry.
///
/// Written by [LiveTelemetryNotifier] rather than derived from the paired
/// list: it must not wait for settings to load, and Riverpod gives no way to
/// enumerate a family's live instances. Only ever moves forward.
class LatestTelemetryAtNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void mark(DateTime at) {
    final current = state;
    if (current == null || at.isAfter(current)) state = at;
  }
}

final latestTelemetryAtProvider =
    NotifierProvider<LatestTelemetryAtNotifier, DateTime?>(
      LatestTelemetryAtNotifier.new,
    );
```

- [ ] **Step 4: 建立 `foot_telemetry_provider.dart`**

```dart
// lib/shared/providers/foot_telemetry_provider.dart
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

/// What a foot with no sole on it reads — never a stale window from a sole
/// that has been unpaired or re-assigned.
const _noTelemetry = LiveTelemetryState();

/// The identityKey of the sole worn on [side], or null while that foot has
/// none — which is every foot until the wearer has calibrated.
final footSoleKeyProvider = Provider.family<String?, FootSide>(
  (ref, side) =>
      ref.watch(settingsProvider.select((s) => s.soleFor(side)?.identityKey)),
);

/// Live telemetry from the sole on [side]; empty while that foot has no sole.
final footTelemetryProvider = Provider.family<LiveTelemetryState, FootSide>((
  ref,
  side,
) {
  final key = ref.watch(footSoleKeyProvider(side));
  return key == null ? _noTelemetry : ref.watch(liveTelemetryProvider(key));
});

/// The sole the single-sole UI means: the right foot when one is assigned,
/// else the primary device, else the first paired sole. Null when nothing is
/// paired.
final primarySoleKeyProvider = Provider<String?>(
  (ref) => ref.watch(
    settingsProvider.select(
      (s) =>
          s.soleFor(FootSide.right)?.identityKey ??
          s.preferredDevice?.identityKey ??
          s.pairedDevicesList.firstOrNull?.identityKey,
    ),
  ),
);

/// Live telemetry from the primary sole — what every screen written before
/// two feet existed reads, through `telemetryViewProvider`.
final primaryTelemetryProvider = Provider<LiveTelemetryState>((ref) {
  final key = ref.watch(primarySoleKeyProvider);
  return key == null ? _noTelemetry : ref.watch(liveTelemetryProvider(key));
});
```

- [ ] **Step 5: 讓 `telemetryViewProvider` 轉發 primary**

把 `lib/shared/providers/telemetry_process_providers/telemetry_view_provider.dart` 整份換成：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';

/// Live telemetry for screens that mean "the sole" rather than a named foot.
/// Follows the primary sole — see [primarySoleKeyProvider].
final telemetryViewProvider = Provider<LiveTelemetryState>(
  (ref) => ref.watch(primaryTelemetryProvider),
);
```

- [ ] **Step 6: 讓 `deviceOnlineProvider` 看所有鞋墊**

在 `lib/shared/providers/telemetry_process_providers/device_online_provider.dart` 裡：

1. 把類別 doc comment 的第一段換成：

```dart
/// Whether **any** sole is currently "online" — i.e. live telemetry arrived
/// from one of them within [TelemetryFacade.onlineWindow]. With two feet the
/// wearable is online while either one is reporting; a per-foot answer comes
/// from `footTelemetryProvider`.
```

2. 把 `build()` 裡的這兩行

```dart
    ref.listen(
      liveTelemetryProvider.select((s) => s.updatedAt),
      (_, next) => _reschedule(next),
    );
    final updatedAt = ref.read(liveTelemetryProvider).updatedAt;
```

換成

```dart
    ref.listen(latestTelemetryAtProvider, (_, next) => _reschedule(next));
    final updatedAt = ref.read(latestTelemetryAtProvider);
```

- [ ] **Step 7: 修好其餘 4 個 lib 呼叫點**

1. `lib/shared/pages/analytics_detail_page.dart:83` 與
   `lib/shared/pages/theme_two/analytics_detail_page_t2.dart:36` —— 兩處都把

```dart
    final recordList = ref.watch(liveTelemetryProvider).record;
```

   換成

```dart
    final recordList = ref.watch(telemetryViewProvider).record;
```

   並把 import `telemetry_process_providers/live_telemetry_notifier.dart` 換成
   `telemetry_process_providers/telemetry_view_provider.dart`。

2. `lib/shared/pages/record_session_mixin.dart` —— `startRecord` 裡的

```dart
    final telemetryNotifier = ref.read(liveTelemetryProvider.notifier);
    telemetryNotifier.clearRecordImuNotifyData();
```

   換成

```dart
    // Recording follows the primary sole; the other foot keeps its own
    // window untouched.
    final soleKey = ref.read(primarySoleKeyProvider);
    if (soleKey != null) {
      ref.read(liveTelemetryProvider(soleKey).notifier)
          .clearRecordImuNotifyData();
    }
```

   並加上 `import 'package:silversole/shared/providers/foot_telemetry_provider.dart';`。

3. `lib/shared/providers/firmware_update_provider.dart` 的 `_preflight` —— 把

```dart
    final battery = ref
        .read(liveTelemetryProvider)
        .recentImu
```

   換成

```dart
    // This sole's own battery, not whichever foot happens to be primary.
    final battery = ref
        .read(liveTelemetryProvider(sole.device.identityKey))
        .recentImu
```

4. `lib/shared/providers/ble_foreground_controller.dart` —— 這一關**必須**順手改這裡，
   否則整個專案編不過（family 化讓它的 5 處用法全部失效）。Task 8 會整份改寫這個檔案，
   所以這裡只做能編譯的最小改動，仍沿用它現有的單一 `boundDevice`：

   - 刪掉第 49 行的 `final live = ref.read(liveTelemetryProvider.notifier);`
   - `onImu` 裡的 `live.updateImuNotifyData(data);` 換成

```dart
      final soleKey = boundDevice?.identityKey;
      if (soleKey == null) return;
      ref
          .read(liveTelemetryProvider(soleKey).notifier)
          .updateImuNotifyData(data);
```

   - `onRecordImu` 裡的 `live.updateRecordImuNotifyData(` 換成

```dart
      final soleKey = boundDevice?.identityKey;
      if (soleKey == null) return;
      ref
          .read(liveTelemetryProvider(soleKey).notifier)
          .updateRecordImuNotifyData(
```

   - `syncNotification` 裡的 `final telemetry = ref.read(liveTelemetryProvider);` 換成

```dart
    final telemetry = ref.read(liveTelemetryProvider(sole.identityKey));
```

   - **刪掉**這個 listener 整段：

```dart
  ref.listen(
    liveTelemetryProvider.select((s) => s.recentImu.lastOrNull?.batteryPercent),
    (_, _) => syncNotification(),
  );
```

     電量變化會經由 `rememberBattery` 寫進 settings，而底下那個
     `settingsProvider.select((s) => s.pairedDevicesList)` 的 listener 已經會接到 ——
     而且原本這個 listener 每秒會被叫 50 次。Task 8 的設計也不再有它。

- [ ] **Step 8: 修好 3 個既有測試**

1. `test/device_online_provider_test.dart:34` —— 把

```dart
        final live = container.read(liveTelemetryProvider.notifier);
```

   換成

```dart
        final live = container.read(liveTelemetryProvider('A').notifier);
```

2. `test/firmware_update_provider_test.dart:212` —— 把

```dart
          .read(liveTelemetryProvider.notifier)
```

   換成（`_sole.device.deviceId` 是 `'ID'`，所以它的 identityKey 就是 `'ID'`）

```dart
          .read(liveTelemetryProvider('ID').notifier)
```

3. `test/battery_chart_gap_test.dart` —— 圖表讀的是 `telemetryViewProvider`，它現在會跟著 primary 鞋墊，所以容器必須先有一隻配對的鞋墊。在 import 之後加入：

```dart
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// One paired sole, so `telemetryViewProvider` has a primary to follow.
class _OneSolePaired extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(
    pairedDevicesList: [
      BlePairedDevice(remoteId: 'addr', name: 'SilverSole', deviceId: 'A'),
    ],
  );
}
```

   並把 `_renderedSpots` 裡的

```dart
  final container = ProviderContainer();
  addTearDown(container.dispose);
  seed(container.read(liveTelemetryProvider.notifier));
```

   換成

```dart
  final container = ProviderContainer(
    overrides: [settingsProvider.overrideWith(_OneSolePaired.new)],
  );
  addTearDown(container.dispose);
  seed(container.read(liveTelemetryProvider('A').notifier));
```

- [ ] **Step 9: 跑整套測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter analyze lib test && flutter test
```
Expected: analyze 無 error；`flutter test` **全綠** —— 新的 `foot_telemetry_provider_test.dart` 以及既有的 `device_online_provider_test`、`battery_chart_gap_test`、`firmware_update_provider_test`、`analytics_pressure_demo_test`、`pressure_visualization_page_test`、`foot_check_session_page_test` 都要過。

- [ ] **Step 10: Commit**

```bash
git add lib/shared/providers/telemetry_process_providers/ lib/shared/providers/foot_telemetry_provider.dart lib/shared/pages/analytics_detail_page.dart lib/shared/pages/theme_two/analytics_detail_page_t2.dart lib/shared/pages/record_session_mixin.dart lib/shared/providers/firmware_update_provider.dart test/foot_telemetry_provider_test.dart test/device_online_provider_test.dart test/battery_chart_gap_test.dart test/firmware_update_provider_test.dart
git commit -m "$(cat <<'MSG'
feat(telemetry): keep one live window per sole, mapped to a foot

Two feet stream at 50 Hz each, so neither may overwrite the other's
window. Screens written before two feet existed read the primary sole
through telemetryViewProvider and behave exactly as they did.

A foot whose sole is unpaired or re-assigned reads empty rather than
keeping the last window on screen.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 7: 通知文案講兩隻鞋墊

**Files:**
- Modify: `lib/core/ble/sole_notification_text.dart`
- Modify: `lib/shared/providers/ble_foreground_controller.dart`（只改呼叫點，傳單元素清單；真正的多隻在 Task 8）
- Test: `test/sole_notification_text_test.dart`（擴充；現有 4 個斷言必須逐字不變）

**Interfaces:**
- Consumes: Task 1 的 `FootSide`
- Produces:
  - `class SoleNotice { String name; String label; bool online; DateTime? lastSeen; BatteryDisplay battery; }`
  - `({String title, String text}) soleNotificationText(List<SoleNotice> soles)`

- [ ] **Step 1: 寫會失敗的測試**

在 `test/sole_notification_text_test.dart` 現有的 `at(...)` helper 之後、第一個 `expect` 之前，插入第二個 helper：

```dart
    SoleNotice notice({
      required String label,
      required bool online,
      DateTime? lastSeen,
      int? live,
      int? lastKnown,
    }) => SoleNotice(
      name: 'SilverSole',
      label: label,
      online: online,
      lastSeen: lastSeen,
      battery: BatteryDisplay.resolve(live: live, lastKnown: lastKnown),
    );
```

把現有的 `at(...)` helper 內部的呼叫改成單元素清單：

```dart
    ({String title, String text}) at({
      required bool online,
      DateTime? lastSeen,
      int? live,
      int? lastKnown,
    }) => withClock(
      Clock.fixed(now),
      () => soleNotificationText([
        SoleNotice(
          name: 'Left sole',
          label: 'Left foot',
          online: online,
          lastSeen: lastSeen,
          battery: BatteryDisplay.resolve(live: live, lastKnown: lastKnown),
        ),
      ]),
    );
```

然後在既有的 4 個斷言之後加上雙隻的案例：

```dart
    // Two soles: one line, one part per foot.
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          notice(label: 'Left foot', online: true, live: 85),
          notice(label: 'Right foot', online: true, live: 92),
        ]),
      ),
      (title: 'SilverSole', text: 'Left foot 85% · Right foot 92%'),
    );

    // One foot offline must read as offline — not as "the wearable is online".
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          notice(label: 'Left foot', online: true, live: 85),
          notice(label: 'Right foot', online: false, lastKnown: 40),
        ]),
      ).text,
      'Left foot 85% · Right foot Offline',
    );

    // A sole that never reported a level says its status instead of a dash.
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          notice(label: 'Left foot', online: true),
          notice(label: 'Right foot', online: true, live: 92),
        ]),
      ).text,
      'Left foot Online · Right foot 92%',
    );

    // Different names keep both, since the title is all the wearer sees.
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          SoleNotice(
            name: 'Left sole',
            label: 'Left foot',
            online: true,
            lastSeen: now,
            battery: BatteryDisplay.resolve(live: 85),
          ),
          SoleNotice(
            name: 'Right sole',
            label: 'Right foot',
            online: true,
            lastSeen: now,
            battery: BatteryDisplay.resolve(live: 92),
          ),
        ]),
      ).title,
      'Left sole / Right sole',
    );

    // No soles at all: nothing to say.
    expect(soleNotificationText(const []), (title: 'Silver Sole', text: ''));
```

並在檔案頂端加 `import 'package:silversole/shared/models/foot_side.dart';`（`SoleNotice` 的 doc comment 引用它）。

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_notification_text_test.dart
```
Expected: FAIL —— `SoleNotice` 未定義，`soleNotificationText` 還是舊的具名參數簽章。

- [ ] **Step 3: 改寫 `sole_notification_text.dart`**

整份換成：

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/core/utils/relative_time.dart';

/// One sole's part of the BLE foreground service's ongoing notification.
class SoleNotice {
  const SoleNotice({
    required this.name,
    required this.label,
    required this.online,
    required this.lastSeen,
    required this.battery,
  });

  final String name;

  /// How to tell this sole apart when there are two: the foot it is worn on
  /// (see `FootSide.labelKey`), or its ID suffix before a side is assigned.
  /// Unused with a single sole, where the status reads in full.
  final String label;

  final bool online;
  final DateTime? lastSeen;
  final BatteryDisplay battery;
}

/// What the BLE foreground service's ongoing notification says, worded like
/// the home device card so the two never disagree.
///
/// With **one** sole (the only case before two feet existed, and still the
/// case whenever only one is connected):
///
/// - title: the sole's name
/// - text: `Online` or `Last connected: 5 min ago`, then the battery level
///   when one is known (live, else the last one the sole reported — see
///   [BatteryDisplay]); a sole that never reported one shows no battery.
///
/// With **two**, a notification line has no room for two "last connected"
/// phrases, so each foot is reduced to its label plus the one fact that
/// matters: its battery, or that it is offline.
({String title, String text}) soleNotificationText(List<SoleNotice> soles) {
  if (soles.isEmpty) return (title: 'Silver Sole', text: '');

  String status(SoleNotice sole) => sole.online
      ? 'online'.tr()
      : sole.lastSeen != null
      ? 'last_connected'.tr(args: [formatTimeAgo(sole.lastSeen!)])
      : 'offline'.tr();

  if (soles.length == 1) {
    final sole = soles.single;
    final text = sole.battery.percent == null
        ? status(sole)
        : '${status(sole)} · ${'battery'.tr()} ${sole.battery.label}';
    return (title: sole.name, text: text);
  }

  final names = soles.map((s) => s.name).toSet();
  final title = names.length == 1 ? names.single : names.join(' / ');
  final text = soles
      .map(
        (s) => s.online && s.battery.percent != null
            ? '${s.label} ${s.battery.label}'
            : '${s.label} ${status(s)}',
      )
      .join(' · ');
  return (title: title, text: text);
}
```

> `@immutable` 來自 `package:flutter/foundation.dart`；若 analyze 提示 import 未使用，就把 `SoleNotice` 標上 `@immutable` 而不是刪掉 import。

- [ ] **Step 4: 修好 `ble_foreground_controller.dart` 的呼叫點**

把 `syncNotification()` 裡的

```dart
    final content = soleNotificationText(
      soleName: sole.name,
      online: online,
      lastSeen: telemetry.updatedAt ?? sole.lastConnectedAt,
      battery: BatteryDisplay.resolve(
        live: online ? telemetry.recentImu.lastOrNull?.batteryPercent : null,
        lastKnown: bound?.lastBatteryPercent ?? sole.lastBatteryPercent,
      ),
    );
```

換成

```dart
    // One sole for now; Task 8 turns this into one notice per linked sole.
    final content = soleNotificationText([
      SoleNotice(
        name: sole.name,
        label: sole.footSide?.labelKey.tr() ?? sole.name,
        online: online,
        lastSeen: telemetry.updatedAt ?? sole.lastConnectedAt,
        battery: BatteryDisplay.resolve(
          live: online ? telemetry.recentImu.lastOrNull?.batteryPercent : null,
          lastKnown: bound?.lastBatteryPercent ?? sole.lastBatteryPercent,
        ),
      ),
    ]);
```

- [ ] **Step 5: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/sole_notification_text_test.dart && flutter analyze lib test
```
Expected: PASS —— 原有 4 個單隻斷言逐字不變，加上 5 個新斷言。

- [ ] **Step 6: Commit**

```bash
git add lib/core/ble/sole_notification_text.dart lib/shared/providers/ble_foreground_controller.dart test/sole_notification_text_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): let the service notification speak for both feet

A notification line has no room for two "last connected" phrases, so each
foot is reduced to its label plus its battery — or plainly Offline, which
is the one thing "either sole is online" must never hide.

With one sole the wording is unchanged, down to the byte.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---
### Task 8: 編排層同時帶兩隻鞋墊

第二個核心任務。`bleForegroundControlProvider` 從單一 `boundDevice` 改成 `SoleSessionRegistry` 裡的多個 `SoleLink`。

**Files:**
- Modify: `lib/shared/providers/connected_sole_provider.dart`（改成 map，另外導出 primary）
- Modify: `lib/shared/providers/ble_foreground_controller.dart`（整份改寫）
- Modify: `lib/shared/providers/ble_connection_provider.dart`（移除 `bleConnectProvider`）
- Modify: `lib/shared/pages/record_session_mixin.dart`（改用 registry 寫 record characteristic）
- Test: `test/connected_sole_provider_test.dart`（改寫成 map API）

**Interfaces:**
- Consumes: Task 3 的 `reconcileSoleLinks` / `identityKeyFor` / `maxSoles`、Task 5 的 `soleSessionsProvider` / `SoleLink`、Task 6 的 `liveTelemetryProvider(key)` / `primarySoleKeyProvider`、Task 7 的 `SoleNotice`
- Produces:
  - `final connectedSolesProvider = NotifierProvider<ConnectedSolesNotifier, Map<String, ConnectedSole>>(…)`，方法 `set(String, ConnectedSole)` / `clear(String)` / `clearAll()`
  - `final connectedSoleProvider = Provider<ConnectedSole?>(…)` —— primary 那隻，簽章與今天相同
  - `bleForegroundControlProvider` 仍回傳 `SoleConnectionController`，介面在 Task 9 才變

- [ ] **Step 1: 改寫 `connected_sole_provider.dart` 的測試**

把 `test/connected_sole_provider_test.dart` 整份換成：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

const _left = ConnectedSole(
  device: BlePairedDevice(remoteId: 'l', name: 'SilverSole', deviceId: 'L'),
  dfuSupported: true,
);
const _right = ConnectedSole(
  device: BlePairedDevice(remoteId: 'r', name: 'SilverSole', deviceId: 'R'),
  dfuSupported: true,
);

/// Settings whose primary sole is 'R'.
class _PrimaryIsRight extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(
    pairedDevicesList: [
      BlePairedDevice(remoteId: 'l', name: 'SilverSole', deviceId: 'L'),
      BlePairedDevice(
        remoteId: 'r',
        name: 'SilverSole',
        deviceId: 'R',
        isPreferred: true,
      ),
    ],
  );
}

void main() {
  test(
    'clearing nothing is not a write, so a provider may do it while it builds',
    () {
      // The BLE foreground controller clears connected soles from a
      // fireImmediately listener while it is still building (the paired list
      // is empty until settings load). Riverpod forbids a provider modifying
      // another during its build, so a clear with nothing to clear must not
      // touch state.
      final clearsWhileBuilding = Provider<void>((ref) {
        ref.read(connectedSolesProvider.notifier).clear('L');
        ref.read(connectedSolesProvider.notifier).clearAll();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(clearsWhileBuilding);
      expect(container.read(connectedSolesProvider), isEmpty);
    },
  );

  test('each sole is tracked on its own and cleared on its own', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(connectedSolesProvider.notifier);

    notifier.set('L', _left);
    notifier.set('R', _right);
    expect(container.read(connectedSolesProvider).keys, {'L', 'R'});

    // One foot dropping its link must not take the other down with it.
    notifier.clear('L');
    expect(container.read(connectedSolesProvider).keys, {'R'});

    notifier.clearAll();
    expect(container.read(connectedSolesProvider), isEmpty);
  });

  test('connectedSoleProvider follows the primary sole', () {
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_PrimaryIsRight.new)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(connectedSolesProvider.notifier);

    expect(container.read(connectedSoleProvider), isNull);

    notifier.set('L', _left);
    // Only the other foot is connected, so that is what the single-sole UI
    // has to talk about rather than showing nothing.
    expect(container.read(connectedSoleProvider), _left);

    notifier.set('R', _right);
    expect(container.read(connectedSoleProvider), _right);
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/connected_sole_provider_test.dart
```
Expected: FAIL —— `connectedSolesProvider` 不存在。

- [ ] **Step 3: 改寫 `connected_sole_provider.dart`**

整份換成：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';

/// Every sole this app is connected to right now, keyed by identityKey.
///
/// Set by the BLE foreground controller on each sole's handshake and cleared
/// on that sole's link loss — one foot dropping never clears the other.
class ConnectedSolesNotifier extends Notifier<Map<String, ConnectedSole>> {
  @override
  Map<String, ConnectedSole> build() => const {};

  void set(String identityKey, ConnectedSole sole) =>
      state = {...state, identityKey: sole};

  /// A no-op when nothing is recorded for [identityKey]. The foreground
  /// controller clears from a `fireImmediately` listener while it is still
  /// building, and Riverpod forbids a provider writing another during its
  /// build — so only write when there is something to drop.
  void clear(String identityKey) {
    if (!state.containsKey(identityKey)) return;
    state = {...state}..remove(identityKey);
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = const {};
  }
}

final connectedSolesProvider =
    NotifierProvider<ConnectedSolesNotifier, Map<String, ConnectedSole>>(
      ConnectedSolesNotifier.new,
    );

/// The connected sole the single-sole UI means — the firmware card, the status
/// card, an update. The primary sole when it is connected (see
/// [primarySoleKeyProvider]), otherwise whichever sole is, so a screen never
/// goes blank just because the other foot is the one on the air.
final connectedSoleProvider = Provider<ConnectedSole?>((ref) {
  final soles = ref.watch(connectedSolesProvider);
  if (soles.isEmpty) return null;
  final key = ref.watch(primarySoleKeyProvider);
  return soles[key] ?? soles.values.first;
});
```

- [ ] **Step 4: 改寫 `ble_foreground_controller.dart`**

整份換成下面的內容。與今天的差異集中在：per-sole 狀態搬進 `SoleLink`、每個 handler 多一個 `key`、搜尋迴圈一次處理多隻（**依序 await**，因為 fbp 2.1.1 的 global mutex）、watchdog 每隻一個。

```dart
import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/ble/pressure_channel_fix.dart';
import 'package:silversole/core/ble/sole_notification_text.dart';
import 'package:silversole/core/ble/sole_reconcile.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/device_status_model.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/device_status_ingest_provider.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';
import 'package:silversole/shared/providers/sole_connection_controller.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

import 'settings_provider.dart';

/// Lets an OTA wait for a rebooting sole without it being mistaken for the
/// last advertisements of the old firmware on its way down.
const _reacquireSettle = Duration(seconds: 3);

/// A found sole still needs to connect and handshake, however little of the
/// reacquire timeout is left.
const _minHandshakeWait = Duration(seconds: 20);

final bleForegroundControlProvider = Provider<SoleConnectionController>((ref) {
  // Check platform
  if (defaultTargetPlatform != TargetPlatform.android) {
    return const NoSoleConnection();
  }
  final registry = ref.read(soleSessionsProvider);
  final deviceStatusIngestService = ref.read(deviceStatusIngestProvider);
  final settings = ref.read(settingsProvider.notifier);
  final connectedSoles = ref.read(connectedSolesProvider.notifier);

  final scanner = SoleScanner();

  // Re-arms the search: nothing advertising, a permission refused, arming a
  // session failing, or still being short of a foot. Reconnecting to a sole
  // we already found is that session's own backoff loop — do not add a second
  // one here.
  Timer? retryTimer;
  var searching = false;
  var searchAttempt = 0;

  // An OTA owns the link between hold() and release(): nothing may search,
  // swap soles or chase a reboot meanwhile.
  var held = false;
  // Completed by onReady while reacquire() waits for the rebooted sole, for
  // the remoteId it is waiting on — so a different sole's onReady (a stray
  // search that slipped in before hold() landed) cannot complete it.
  ({String remoteId, Completer<SoleSessionInfo?> completer})? readyWaiter;

  String toHex(List<int> v) =>
      v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  // Persists a sole's battery level so it can be shown greyed out while that
  // sole is offline. The IMU stream repeats the same level at 50 Hz, so only a
  // change is written; the link carries it so onReady's write keeps it.
  void rememberBattery(SoleLink link, int percent) {
    if (!percent.isValidBatteryPercent) return;
    if (link.device.lastBatteryPercent == percent) return;
    link.device = link.device.copyWith(lastBatteryPercent: percent);
    unawaited(settings.setLastBatteryPercent(link.device.identityKey, percent));
  }

  // The service's notification names the sole(s) and says what the home card
  // says. Pushed only when the text changes, since telemetry ticks at 50 Hz
  // per foot.
  String? notified;
  void syncNotification() {
    final current = ref.read(settingsProvider);
    final facade = ref.read(telemetryFacadeProvider);

    SoleNotice noticeFor(BlePairedDevice sole, {int? liveBattery}) {
      final telemetry = ref.read(liveTelemetryProvider(sole.identityKey));
      final online = facade.checkDeviceOnline(telemetry.updatedAt);
      return SoleNotice(
        name: sole.name,
        // Before a side is assigned the ID suffix is all that tells two
        // identical "SilverSole"s apart.
        label: sole.footSide?.labelKey.tr() ??
            (sole.shortId == null ? sole.name : '••••${sole.shortId}'),
        online: online,
        lastSeen: telemetry.updatedAt ?? sole.lastConnectedAt,
        battery: BatteryDisplay.resolve(
          live: online
              ? liveBattery ?? telemetry.recentImu.lastOrNull?.batteryPercent
              : null,
          lastKnown: sole.lastBatteryPercent,
        ),
      );
    }

    final notices = <SoleNotice>[];
    for (final link in registry.links) {
      // The stored entry carries a rename; the link's copy the freshest
      // battery.
      final stored = current.pairedDevicesList.firstWhereOrNull(
        (d) => d.identityKey == link.device.identityKey,
      );
      notices.add(
        noticeFor(
          stored ?? link.device,
          liveBattery: link.device.lastBatteryPercent,
        ),
      );
    }
    if (notices.isEmpty) {
      // Nothing linked yet: name the primary entry so the service's ongoing
      // notification is not blank while the first search runs.
      final sole =
          current.preferredDevice ?? current.pairedDevicesList.firstOrNull;
      if (sole == null) return;
      notices.add(noticeFor(sole));
    }

    final content = soleNotificationText(notices);
    final key = '${content.title}\n${content.text}';
    if (key == notified) return;
    notified = key;
    unawaited(
      updateBleNotification(
        title: content.title,
        text: content.text,
      ).catchError((Object e) => debugPrint('notification update: $e')),
    );
  }

  void onImu(String soleKey, List<int> value) {
    final link = registry.lookup(soleKey);
    if (link == null) return;
    try {
      final data = link.service.parseImuNotify(value);
      ref.read(liveTelemetryProvider(soleKey).notifier).updateImuNotifyData(data);
      rememberBattery(link, data.batteryPercent);
    } catch (e) {
      // Always report the first failure, then throttle: a format mismatch
      // fails on every packet and would spam ~20 lines/s per foot.
      link.imuFailCount++;
      if (link.imuFailCount == 1 || link.imuFailCount % 20 == 0) {
        debugPrint(
          'parse notify FAILED $soleKey #${link.imuFailCount} '
          'len=${value.length} hex=[${toHex(value)}] err=$e',
        );
      }
    }
  }

  void onRecordImu(String soleKey, List<int> value) {
    final link = registry.lookup(soleKey);
    if (link == null) return;
    try {
      final json = link.service.parseJsonNotify(value);
      final data = RecordImuNotifyDataModel.fromJson(json);
      ref
          .read(liveTelemetryProvider(soleKey).notifier)
          .updateRecordImuNotifyData(
            data.copyWith(pressure: fixPressureChannels(data.pressure)),
          );
      debugPrint('record notify $soleKey: $data');
    } catch (e) {
      debugPrint('parse record notify failed: $e');
    }
  }

  void onFallDetect(String soleKey, List<int> value) {
    try {
      if (utf8.decode(value) != '1') return;
      final deviceId = registry.lookup(soleKey)?.device.deviceId;
      if (deviceId == null) return;
      ref
          .read(fallEventBusProvider)
          .emit(
            FallDetectEvent(
              timestamp: DateTime.now(),
              deviceId: deviceId,
              detect: true,
            ),
          );
    } catch (e) {
      debugPrint('parse fall detect failed: $e');
    }
  }

  bool isDeviceStatusTimestampValid(
    int timestampMs, {
    Duration tolerance = const Duration(minutes: 10),
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffMs = (timestampMs - nowMs).abs();
    debugPrint('device status diffMs=$diffMs');
    return diffMs <= tolerance.inMilliseconds;
  }

  Future<void> onDeviceStatus(String soleKey, List<int> value) async {
    final link = registry.lookup(soleKey);
    if (link == null) return;
    try {
      final payload = link.service.parseJsonNotify(value);
      final status = DeviceStatusModel.fromJson(payload);
      if (!isDeviceStatusTimestampValid(status.timestamp)) {
        debugPrint('device status timestamp invalid: ${status.timestamp}');
        return;
      }
      rememberBattery(link, status.body.batteryPercent);
      final result = await deviceStatusIngestService.ingestDeviceStatus(
        device: link.device,
        payload: status,
      );

      switch (result) {
        case Error():
          throw result.error;
        case Ok():
          break;
      }
    } catch (e) {
      debugPrint('device status ingest failed: $e');
    }
  }

  Future<bool> ensureConnectPermission() async {
    final stats = await Permission.bluetoothConnect.request();
    return stats.isGranted;
  }

  /// Mirrors the pairing sheet's request. This only ever runs once the user has
  /// paired a sole by hand, so both prompts have already been seen by then.
  Future<bool> ensureScanPermission() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    return statuses[Permission.bluetoothScan]?.isGranted ?? false;
  }

  // The service's ongoing notification is what tells the wearer BLE keeps
  // running in the background (and what Play's foreground-service review looks
  // for). Android 13+ hides it until this is granted — the service itself runs
  // either way, so a refusal only costs the notification and never blocks the
  // connection. Asked once per launch, not on every search retry.
  var notificationAsked = false;
  Future<void> ensureNotificationPermission() async {
    if (notificationAsked) return;
    notificationAsked = true;
    await Permission.notification.request();
  }

  // searchAndAttach and the timers below call each other, and Dart has no
  // forward references for local functions — so one of them has to be a
  // variable.
  late final Future<void> Function({bool force}) searchAndAttach;

  /// 15, 30, then 60 s between searches, so a sole that is simply switched off
  /// does not keep a low-latency scan running every 15 s all day. Reset once a
  /// session is ready.
  void scheduleSearch() {
    const delays = [15, 30, 60];
    retryTimer?.cancel();
    final seconds =
        delays[searchAttempt < delays.length
            ? searchAttempt
            : delays.length - 1];
    searchAttempt++;
    debugPrint('sole search again in ${seconds}s');
    retryTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(searchAndAttach()),
    );
  }

  /// Gives this sole's own fast reconnect a window to bring the same MAC back.
  /// When it cannot, the sole has most likely rebooted — it advertises a
  /// different MAC then, and only a fresh scan can find it.
  void armWatchdog(
    SoleLink link, [
    Duration delay = const Duration(seconds: 30),
  ]) {
    link.cancelWatchdog();
    link.watchdog = Timer(delay, () {
      if (link.isConnected) return;
      debugPrint('sole ${link.device.identityKey} did not connect — searching');
      unawaited(searchAndAttach());
    });
  }

  void onReady(String soleKey, SoleCandidate pick, SoleSessionInfo info) {
    final link = registry.lookup(soleKey);
    if (link == null) return;
    final deviceId = info.deviceId;
    // Connected and handshaked: this sole's watchdog has nothing to rescue and
    // the next search starts from the short delay again.
    link.cancelWatchdog();
    searchAttempt = 0;
    // The Serial Number read and the advertisement carry the same ID; a
    // mismatch means one of them is being parsed wrong.
    if (deviceId != null && pick.deviceId != null && deviceId != pick.deviceId) {
      debugPrint(
        'device ID mismatch: advertised ${pick.deviceId}, read $deviceId',
      );
    }
    // Persist the moment we (re)connected so the status card can show a real
    // "last connected" time. The settings listener ignores timestamp changes,
    // so this does not restart the search.
    final updated = link.device.copyWith(
      deviceId: deviceId ?? link.device.deviceId,
      lastConnectedAt: DateTime.now(),
    );
    link.device = updated;
    syncNotification();
    unawaited(settings.addOrUpdatePairedDevice(updated));
    connectedSoles.set(
      soleKey,
      ConnectedSole(
        device: updated,
        firmwareVersion: info.firmwareVersion,
        dfuSupported: info.dfuSupported,
      ),
    );
    final waiter = readyWaiter;
    if (waiter != null &&
        waiter.remoteId == pick.remoteId &&
        !waiter.completer.isCompleted) {
      waiter.completer.complete(info);
    }
    debugPrint(
      'sole session ready: $soleKey deviceId=${updated.deviceId} '
      'firmware=${info.firmwareVersion}',
    );
  }

  /// Connects to [pick] with the app's handlers, reusing its paired entry.
  /// False when the session could not even be armed.
  Future<bool> attachTo(
    SoleCandidate pick,
    List<BlePairedDevice> paired,
  ) async {
    // Reuse the stored entry for this sole, so its name, foot side and primary
    // flag survive; it only moves to the address the sole is on now, and picks
    // up the advertised ID if it was paired before the firmware sent one.
    final known = paired.firstWhereOrNull((d) => isSameSole(pick, d));
    final device =
        known?.copyWith(
          remoteId: pick.remoteId,
          deviceId: pick.deviceId ?? known.deviceId,
        ) ??
        BlePairedDevice(
          remoteId: pick.remoteId,
          name: pick.name,
          deviceId: pick.deviceId,
          lastRssi: pick.rssi,
        );
    final soleKey = identityKeyFor(pick, paired);
    final link = registry.link(soleKey, device);
    syncNotification();

    // attach()'s own detach() cancels this session's old listener before the
    // new link comes up, so onDisconnected never fires for it — without this,
    // a re-attach would leave a stale entry in connectedSolesProvider until
    // the new handshake overwrote it.
    connectedSoles.clear(soleKey);

    final result = await link.service.attach(
      device,
      handlers: BleSessionHandlers(
        onImu: (value) => onImu(soleKey, value),
        onRecordImu: (value) => onRecordImu(soleKey, value),
        onFallDetect: (value) => onFallDetect(soleKey, value),
        onDeviceStatus: (value) => unawaited(onDeviceStatus(soleKey, value)),
        onReady: (info) => onReady(soleKey, pick, info),
        onDisconnected: (reason) {
          debugPrint('sole $soleKey disconnected: $reason');
          connectedSoles.clear(soleKey);
          // During an update the reboot is expected, and reacquire() — not the
          // watchdog — brings the sole back.
          if (!held) armWatchdog(link);
        },
      ),
    );

    if (result case Error(:final error)) {
      debugPrint('sole attach failed: $error');
      return false;
    }
    debugPrint('sole session attached: $soleKey');
    return true;
  }

  /// Finds the paired soles that are actually advertising and connects to
  /// them — up to [maxSoles], one per foot.
  ///
  /// Soles are recognised by the chip ID in their advertisement, so a sole is
  /// found again whatever address it comes back on; firmware too old to send
  /// the ID falls back to the address, which is what [pickSoles] spells out.
  /// [force] is the manual primary-device pick asking us to look even though
  /// every slot is already filled.
  searchAndAttach = ({bool force = false}) async {
    // An update owns the link until it releases it.
    if (searching || held) return;

    final current = ref.read(settingsProvider);
    final desired =
        current.pairedDevicesList.length < maxSoles
        ? current.pairedDevicesList.length
        : maxSoles;
    if (!force && desired > 0 && registry.connectedCount >= desired) return;

    searching = true;
    retryTimer?.cancel();
    try {
      // Never reach for a stranger's sole: auto-connect starts only once the
      // user has paired one by hand.
      if (current.pairedDevicesList.isEmpty) {
        await registry.detachAll();
        connectedSoles.clearAll();
        await stopBleService();
        return;
      }

      if (!await ensureConnectPermission() || !await ensureScanPermission()) {
        debugPrint('ble permission denied');
        scheduleSearch();
        return;
      }

      await ensureNotificationPermission();
      await startBleService();
      syncNotification();

      final plan = reconcileSoleLinks(
        picks: pickSoles(
          await scanner.scan(),
          paired: current.pairedDevicesList,
          max: desired,
        ),
        paired: current.pairedDevicesList,
        linkedKeys: registry.keys,
        max: desired,
      );

      for (final soleKey in plan.detach) {
        await registry.detach(soleKey);
        connectedSoles.clear(soleKey);
      }

      // An update may have taken the link while this search was scanning.
      if (held) return;

      if (plan.attach.isEmpty && registry.keys.isEmpty) {
        debugPrint('no paired sole advertising');
        scheduleSearch();
        return;
      }

      // One at a time: fbp 2.1.1 runs every GATT operation behind a single
      // global mutex, so two handshakes at once only queue up anyway — and
      // interleaving them would make a failure much harder to read.
      for (final pick in plan.attach) {
        if (held) return;
        if (await attachTo(pick, current.pairedDevicesList)) {
          final link = registry.lookup(
            identityKeyFor(pick, current.pairedDevicesList),
          );
          if (!held && link != null) armWatchdog(link);
        }
      }

      // Still short of a foot (the other sole is switched off, out of range,
      // or not paired yet): keep looking on the backoff. A sole that was just
      // attached counts as found even though its link is still coming up —
      // its own watchdog covers a handshake that never completes.
      if (registry.keys.length < desired) scheduleSearch();
    } finally {
      searching = false;
    }
  };

  /// Brings [target] back after it rebooted into new firmware and returns its
  /// fresh session, or null when it does not show up within [timeout].
  ///
  /// Never throws: the caller (an update stuck in its rebooting phase) treats
  /// null as "could not confirm the sole came back" either way.
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target,
    Duration timeout,
  ) async {
    try {
      final deadline = clock.now().add(timeout);
      // This sole's own reconnect would chase the address it had before it
      // rebooted. The other foot's session is left alone.
      await registry.detach(target.identityKey);
      connectedSoles.clear(target.identityKey);
      await Future<void>.delayed(_reacquireSettle);

      final paired = ref.read(settingsProvider).pairedDevicesList;
      final seen = await scanner.watch(
        timeout: deadline.difference(clock.now()),
        stopWhen: (c) => isReacquireTarget(c, target),
      );
      final match = matchReacquireTarget(
        target: target,
        seen: seen,
        paired: paired,
      );
      if (match == null) {
        debugPrint('updated sole not found among ${seen.length} soles');
        return null;
      }

      final completer = Completer<SoleSessionInfo?>();
      // Keyed by remoteId so a stray search's onReady for a different sole
      // cannot complete this waiter.
      readyWaiter = (remoteId: match.candidate.remoteId, completer: completer);
      try {
        if (!await attachTo(match.candidate, paired)) return null;
        final left = deadline.difference(clock.now());
        final info = await completer.future.timeout(
          left > _minHandshakeWait ? left : _minHandshakeWait,
          onTimeout: () => null,
        );
        return info == null ? null : ReacquiredSole(info, match.confidence);
      } finally {
        readyWaiter = null;
      }
    } catch (e) {
      debugPrint('reacquire failed: $e');
      return null;
    }
  }

  // What the notification shows moves on its own: the online flag, a rename,
  // and the battery — which lands in the paired list via rememberBattery, so
  // that listener covers it. Deliberately *not* a listener on live telemetry:
  // that fires 50 times a second per foot.
  ref.listen(deviceOnlineProvider, (_, _) => syncNotification());
  ref.listen(
    settingsProvider.select((s) => s.pairedDevicesList),
    (_, _) => syncNotification(),
  );
  // Keeps "last connected: N min ago" current while everything is offline.
  final notificationTicker = Timer.periodic(
    const Duration(seconds: 30),
    (_) => syncNotification(),
  );
  ref.onDispose(notificationTicker.cancel);

  // The primary-device pick and "is anything paired at all" are the only
  // settings that change what we should be connected to. Every reconnect
  // rewrites the paired entry's timestamp, which this selector ignores on
  // purpose — otherwise each reconnect would kick off another search. A
  // calibration only labels soles that are already connected, so it is not
  // here either.
  ref.listen<
    ({String? preferredKey, String? preferredAddress, int pairedCount})
  >(
    settingsProvider.select(
      (s) => (
        preferredKey: s.preferredDevice?.identityKey,
        preferredAddress: s.preferredDevice?.remoteId,
        pairedCount: s.pairedDevicesList.length,
      ),
    ),
    (prev, next) {
      if (next.pairedCount == 0) {
        retryTimer?.cancel();
        connectedSoles.clearAll();
        unawaited(
          registry.detachAll().whenComplete(() => stopBleService()),
        );
        return;
      }
      // A manual pick goes looking even while every slot is filled; anything
      // else only searches when a foot is missing. A pick changes both the
      // identity and the address. A connected sole changes only one of them,
      // and that must not force a reconnect: on a new address its identity
      // stays the same, and when an old entry picks up its ID its address
      // stays the same.
      final picked =
          prev?.preferredKey != next.preferredKey &&
          prev?.preferredAddress != next.preferredAddress;
      unawaited(searchAndAttach(force: picked));
    },
    fireImmediately: true,
  );

  return _ForegroundSoleConnection(
    onHold: () {
      held = true;
      retryTimer?.cancel();
      for (final link in registry.links) {
        link.cancelWatchdog();
      }
    },
    onRelease: () {
      if (!held) return;
      held = false;
      unawaited(searchAndAttach());
    },
    onDfuLink: () {
      // The single-sole OTA talks to the sole connectedSoleProvider names.
      final soleKey = ref.read(primarySoleKeyProvider);
      final link = soleKey == null ? null : registry.lookup(soleKey);
      return (link ?? registry.links.firstOrNull)?.service.dfuLink();
    },
    onReacquire: reacquire,
  );
});

class _ForegroundSoleConnection implements SoleConnectionController {
  _ForegroundSoleConnection({
    required this.onHold,
    required this.onRelease,
    required this.onDfuLink,
    required this.onReacquire,
  });

  final void Function() onHold;
  final void Function() onRelease;
  final DfuLink? Function() onDfuLink;
  final Future<ReacquiredSole?> Function(BlePairedDevice, Duration) onReacquire;

  @override
  void hold() => onHold();

  @override
  void release() => onRelease();

  @override
  DfuLink? dfuLink() => onDfuLink();

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) => onReacquire(target, timeout);
}
```

- [ ] **Step 4b（修正，優先於 Step 4 的檔案內容）：handler 捕 `SoleLink` 而不是 key 字串，且 `onReady` 要 re-key**

同樣來自 Task 3 的 review finding。Step 4 的檔案把 `soleKey` **字串**捕進每個 handler 的 closure，而每個 handler 開頭又做 `registry.lookup(soleKey)`。一旦 Task 5 的 `rekey` 發生（legacy 紀錄拿到 chip ID），`registry.lookup(soleKey)` 就會回 null，**那隻腳的 telemetry 會整個停掉，而且不會有任何錯誤訊息**。

改成捕 `SoleLink` 物件本身 —— 它在 re-key 前後都是同一個實例。

1. 四個 notify handler 的第一個參數從 `String soleKey` 改成 `SoleLink link`，刪掉開頭的 `registry.lookup(soleKey)` 與 null 檢查（link 已經在手上），telemetry 的 key 一律**動態取用** `link.device.identityKey`，不要先存成區域變數：

```dart
  void onImu(SoleLink link, List<int> value) {
    try {
      final data = link.service.parseImuNotify(value);
      ref
          .read(liveTelemetryProvider(link.device.identityKey).notifier)
          .updateImuNotifyData(data);
      rememberBattery(link, data.batteryPercent);
    } catch (e) {
      // Always report the first failure, then throttle: a format mismatch
      // fails on every packet and would spam ~20 lines/s per foot.
      link.imuFailCount++;
      if (link.imuFailCount == 1 || link.imuFailCount % 20 == 0) {
        debugPrint(
          'parse notify FAILED ${link.device.identityKey} '
          '#${link.imuFailCount} len=${value.length} '
          'hex=[${toHex(value)}] err=$e',
        );
      }
    }
  }
```

   `onRecordImu` 同樣改（telemetry key 用 `link.device.identityKey`）；`onFallDetect` 直接用 `link.device.deviceId`；`onDeviceStatus` 直接用 `link.device`。

2. `onReady` 的簽章改成 `onReady(SoleLink link, String soleKey, SoleCandidate pick, SoleSessionInfo info)` —— 它需要知道這條 session 是以哪個 key 建的。刪掉它開頭的 `registry.lookup` 與 null 檢查。在 `link.device = updated;` 之後、`connectedSoles.set(...)` 之前插入：

```dart
    // A sole paired on pre-ID firmware is filed under its address. Now that it
    // has reported a chip ID its paired entry is keyed by that ID, so the
    // session has to move with it — otherwise the next reconcile reads the old
    // key as unpaired and tears this working link down. The handlers hold this
    // link rather than its key, so they keep working across the move.
    final liveKey = updated.identityKey;
    if (liveKey != soleKey) {
      connectedSoles.clear(soleKey);
      unawaited(registry.rekey(soleKey, liveKey));
    }
```

   然後把後面 `connectedSoles.set(soleKey, ConnectedSole(...))` 的 key 改成 `liveKey`，debugPrint 也用 `liveKey`。

3. `attachTo` 裡的 handler 綁定改成：

```dart
        onImu: (value) => onImu(link, value),
        onRecordImu: (value) => onRecordImu(link, value),
        onFallDetect: (value) => onFallDetect(link, value),
        onDeviceStatus: (value) => unawaited(onDeviceStatus(link, value)),
        onReady: (info) => onReady(link, soleKey, pick, info),
        onDisconnected: (reason) {
          debugPrint('sole ${link.device.identityKey} disconnected: $reason');
          connectedSoles.clear(link.device.identityKey);
          // During an update the reboot is expected, and reacquire() — not the
          // watchdog — brings the sole back.
          if (!held) armWatchdog(link);
        },
```

4. `syncNotification` 讀 telemetry 用的是 stored entry 的 key，不受影響 —— 確認一下就好，不用改。

5. **釘住 `rekey` 的同步性質**（來自 Task 5 的 review finding）。上面第 2 點用 `unawaited(registry.rekey(...))` 呼叫，然後**立刻**用新 key 讀 registry —— 這只有在 `rekey` 的 map 變更發生在它第一個 `await` 之前才成立。目前的實作確實如此（唯一的 `await` 在 occupied-key 分支，而 `remove` / 插入都在它之前），但沒有任何測試釘住它，所以有人日後在方法前面加一個 `await` 就會無聲破壞 Task 8。

   在 `test/sole_session_registry_test.dart` 補一個案例：**不要 await** 就呼叫 `registry.rekey('addr', 'ID')`，然後同一個同步區塊裡立刻 `expect(registry.lookup('ID'), same(link))` 與 `expect(registry.lookup('addr'), isNull)`。並在 `sole_session_registry.dart` 的 `rekey` doc comment 補一句，說明 map 變更刻意同步完成，因為編排層是 fire-and-forget 呼叫它之後馬上讀新 key。

- [ ] **Step 5: 讓 record 改走 registry，並移除 `bleConnectProvider`**

在 `lib/shared/pages/record_session_mixin.dart`：

1. 把 import `ble_connection_provider.dart` 保留（`soleSessionsProvider` 在同一檔），確認已 import `foot_telemetry_provider.dart` 與 `package:silversole/core/ble/sole_session_registry.dart`。
2. 在 `mixin` 開頭、`isRecordingNow` 之後加入：

```dart
  /// The primary sole's live session, or null when nothing is connected.
  /// Recording is a single-sole feature — the other foot keeps streaming.
  SoleLink? get primaryLink {
    final soleKey = ref.read(primarySoleKeyProvider);
    return soleKey == null
        ? null
        : ref.read(soleSessionsProvider).lookup(soleKey);
  }
```

3. `startRecord` / `stopRecord` / `isRecording` 三處的

```dart
    final ble = ref.read(bleConnectProvider);
```

   各自換成

```dart
    final ble = primaryLink?.service;
    if (ble == null) {
      showErrorSnakeBar('not_binding'.tr());
      return; // isRecording 裡改成 `return false;`
    }
```

4. 把 `lib/shared/providers/ble_connection_provider.dart` 裡的 `bleConnectProvider` 連同 doc comment 與 `ble_connection_service.dart` 的 import 一起刪除，只留 `soleSessionsProvider`。

5. **讓錄製的 key 對齊**（來自 Task 6 的 review finding）。`startRecord` 現在清掉的是 **primary** 那隻的 record 視窗，而編排層把 record notify 寫進**該條 link 自己**的 key。兩者今天同一隻，但一旦不同（例如 primary 被改成另一腳），錄製圖會永遠空白而且不會有錯誤。

   既然這一步已經把 `primaryLink` 取出來了，就用**同一條 link 的 key** 做清除與讀取，不要分別去問 `primarySoleKeyProvider`：

```dart
    final ble = primaryLink;
    if (ble == null) {
      showErrorSnakeBar('not_binding'.tr());
      return;
    }
    // Same link the record notifies land on, so the chart cannot end up
    // reading a window nothing is writing to.
    ref
        .read(liveTelemetryProvider(ble.device.identityKey).notifier)
        .clearRecordImuNotifyData();
```

   `primaryLink` 的回傳型別因此要是 `SoleLink?`（不是 `BleConnectionService?`），呼叫 BLE 的地方改成 `ble.service.writeBool(...)` / `ble.service.readString(...)`。

- [ ] **Step 6: 跑整套測試與靜態分析**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter analyze lib test && flutter test
```
Expected: analyze 無 error（特別確認沒有殘留的 `bleConnectProvider` 參照）；`flutter test` 全綠。

- [ ] **Step 7: Commit**

```bash
git add lib/shared/providers/connected_sole_provider.dart lib/shared/providers/ble_foreground_controller.dart lib/shared/providers/ble_connection_provider.dart lib/shared/pages/record_session_mixin.dart test/connected_sole_provider_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): keep a session per foot instead of one for the sole

The search loop now reconciles what is linked against what is paired and
advertising, up to one sole per foot, and attaches them one at a time —
fbp 2.1.1 serialises every GATT operation behind a single global mutex,
so parallel handshakes only queue anyway.

Per-sole state (the bound device, the watchdog, the parse-failure count)
moved onto SoleLink, so one foot dropping its link no longer disturbs the
other.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---
### Task 9: OTA 指名要更新哪一隻鞋墊

**Files:**
- Modify: `lib/shared/providers/sole_connection_controller.dart`（`hold`/`dfuLink` 帶 identityKey）
- Modify: `lib/shared/providers/ble_foreground_controller.dart`（實作新介面，hold 時 detach 另一隻）
- Modify: `lib/shared/providers/firmware_update_provider.dart`（傳 key）
- Test: `test/firmware_update_provider_test.dart`（`_FakeConnection` 改簽章 + 新增一個斷言）

**Interfaces:**
- Consumes: Task 8 的 registry 式編排層
- Produces: `void hold(String identityKey)`、`DfuLink? dfuLink(String identityKey)`

- [ ] **Step 1: 寫會失敗的測試**

在 `test/firmware_update_provider_test.dart` 的 `_FakeConnection` 裡：

1. 把 `var holds = 0;` 換成

```dart
  var holds = 0;

  /// The sole the update said it was taking the link for.
  String? heldKey;

  /// The sole the update asked for a DFU link to.
  String? linkedKey;
```

2. 把 `hold` 與 `dfuLink` 換成

```dart
  @override
  void hold(String identityKey) {
    holds++;
    heldKey = identityKey;
  }

  @override
  DfuLink? dfuLink(String identityKey) {
    linkedKey = identityKey;
    onDfuLink?.call();
    return sole;
  }
```

3. 在檔案最後的 `main()` 裡加一個測試（`_sole.device.identityKey` 是 `'ID'`）：

```dart
  test('an update names the sole it is taking the link for', () {
    final sole = FakeDfuSole();
    final connection = _FakeConnection(sole);
    _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(connection.heldKey, 'ID');
    expect(connection.linkedKey, 'ID');
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/firmware_update_provider_test.dart
```
Expected: FAIL —— `_FakeConnection` 的 `hold`/`dfuLink` 與介面簽章不符（`@override` 錯誤）。

- [ ] **Step 3: 改 `SoleConnectionController` 介面**

在 `lib/shared/providers/sole_connection_controller.dart` 裡，把 `hold` 與 `dfuLink` 的宣告與 doc comment 換成：

```dart
  /// Stops searching and every watchdog until [release], and tears down every
  /// session **except** [identityKey]'s. A manual primary-device pick is
  /// ignored meanwhile.
  ///
  /// Dropping the other foot is deliberate: flutter_blue_plus 2.1.1 runs every
  /// GATT operation behind a single global mutex, so the other sole's
  /// handshake would contend with this transfer's page writes — and a page
  /// write that stalls is exactly what drops the link.
  void hold(String identityKey);
```

```dart
  /// The sole keyed [identityKey]'s DFU link, or null when that sole is not
  /// connected or its firmware has no DFU service.
  DfuLink? dfuLink(String identityKey);
```

並把 `NoSoleConnection` 的兩個實作換成：

```dart
  @override
  void hold(String identityKey) {}
```

```dart
  @override
  DfuLink? dfuLink(String identityKey) => null;
```

- [ ] **Step 4: 讓編排層實作新介面**

在 `lib/shared/providers/ble_foreground_controller.dart`：

1. 把回傳的 `onHold` 換成

```dart
    onHold: (soleKey) {
      held = true;
      retryTimer?.cancel();
      for (final link in registry.links) {
        link.cancelWatchdog();
      }
      // The other foot's handshake would contend with this transfer's page
      // writes for fbp's one global GATT mutex. release() goes and gets it
      // back.
      for (final otherKey in registry.keys) {
        if (otherKey == soleKey) continue;
        debugPrint('ota holds the link — dropping $otherKey meanwhile');
        unawaited(registry.detach(otherKey));
        connectedSoles.clear(otherKey);
      }
    },
```

2. 把 `onDfuLink` 換成

```dart
    onDfuLink: (soleKey) => registry.lookup(soleKey)?.service.dfuLink(),
```

3. 把 `_ForegroundSoleConnection` 的兩個欄位與兩個方法換成

```dart
  final void Function(String identityKey) onHold;
```

```dart
  final DfuLink? Function(String identityKey) onDfuLink;
```

```dart
  @override
  void hold(String identityKey) => onHold(identityKey);
```

```dart
  @override
  DfuLink? dfuLink(String identityKey) => onDfuLink(identityKey);
```

4. 既然 `onDfuLink` 不再需要 primary，確認 `primarySoleKeyProvider` 的 import 仍被 `syncNotification` 以外的程式用到；若 analyze 報未使用就移除該 import。

- [ ] **Step 5: 讓更新流程傳 key**

在 `lib/shared/providers/firmware_update_provider.dart` 的 `_install` 裡：

把

```dart
    final link = connection.dfuLink();
```

換成

```dart
    final link = connection.dfuLink(sole.device.identityKey);
```

把

```dart
    connection.hold();
```

換成

```dart
    connection.hold(sole.device.identityKey);
```

- [ ] **Step 6: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/firmware_update_provider_test.dart && flutter analyze lib test
```
Expected: 原有的更新測試全過，加上新的 `heldKey`/`linkedKey` 斷言。

- [ ] **Step 7: Commit**

```bash
git add lib/shared/providers/sole_connection_controller.dart lib/shared/providers/ble_foreground_controller.dart lib/shared/providers/firmware_update_provider.dart test/firmware_update_provider_test.dart
git commit -m "$(cat <<'MSG'
fix(ota): name the sole an update is for, and drop the other foot

fbp 2.1.1 runs every GATT operation behind one global mutex, so the other
sole's handshake contends with the transfer's page writes — and a stalled
page write is what drops the link. hold() now takes the sole being
updated and tears the other session down until release().

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 10: 裝置清單每隻各自 online 與電量

今天 `DeviceRow` 的 doc comment 寫著「the app holds one BLE connection at a time, so at most one row is online」。現在不成立了。

**Files:**
- Modify: `lib/shared/models/device_view_data.dart`（`buildDeviceRows` 改簽章，新增 `SoleLiveFacts`）
- Modify: `lib/shared/pages/devices_page.dart:156-161`、`lib/shared/pages/theme_two/devices_page_t2.dart:32-37`（呼叫點）
- Test: `test/battery_level_test.dart`（`buildDeviceRows battery` group 改寫）

**Interfaces:**
- Consumes: Task 6 的 `liveTelemetryProvider(key)`
- Produces:
  - `class SoleLiveFacts { bool online; int? batteryPercent; }`，含 `const SoleLiveFacts.offline()`
  - `List<DeviceRow> buildDeviceRows({required List<BlePairedDevice> devices, required SoleLiveFacts Function(String identityKey) liveFor})`

- [ ] **Step 1: 改寫測試**

把 `test/battery_level_test.dart` 裡整個 `group('buildDeviceRows battery', …)` 換成：

```dart
  group('buildDeviceRows battery', () {
    // No deviceId, so each sole's identityKey is its address.
    const left = BlePairedDevice(
      remoteId: 'A',
      name: 'a',
      lastBatteryPercent: 40,
    );
    const right = BlePairedDevice(
      remoteId: 'B',
      name: 'b',
      lastBatteryPercent: 90,
    );

    SoleLiveFacts Function(String) facts(Map<String, SoleLiveFacts> by) =>
        (key) => by[key] ?? const SoleLiveFacts.offline();

    test('a stale live sample is not shown as live while offline', () {
      final rows = buildDeviceRows(
        devices: [left, right],
        liveFor: facts({
          'A': const SoleLiveFacts(online: false, batteryPercent: 75),
        }),
      );
      expect(rows[0].battery.label, '40%');
      expect(rows[0].battery.isLive, isFalse);
      expect(rows[1].battery.label, '90%');
      expect(rows[1].battery.isLive, isFalse);
    });

    test('a streaming sole shows its live level', () {
      final rows = buildDeviceRows(
        devices: [left, right],
        liveFor: facts({
          'A': const SoleLiveFacts(online: true, batteryPercent: 75),
        }),
      );
      expect(rows[0].battery.label, '75%');
      expect(rows[0].battery.isLive, isTrue);
      expect(rows[1].battery.isLive, isFalse);
    });

    // Both feet can stream at once now, so both rows can be live at once.
    test('two streaming soles each show their own level', () {
      final rows = buildDeviceRows(
        devices: [left, right],
        liveFor: facts({
          'A': const SoleLiveFacts(online: true, batteryPercent: 75),
          'B': const SoleLiveFacts(online: true, batteryPercent: 61),
        }),
      );
      expect(rows[0].online, isTrue);
      expect(rows[0].battery.label, '75%');
      expect(rows[1].online, isTrue);
      expect(rows[1].battery.label, '61%');
      expect(rows[1].battery.isLive, isTrue);
    });

    test('an online sole with no valid reading keeps its remembered level', () {
      final rows = buildDeviceRows(
        devices: [left],
        liveFor: facts({'A': const SoleLiveFacts(online: true)}),
      );
      expect(rows[0].online, isTrue);
      expect(rows[0].battery.label, '40%');
      expect(rows[0].battery.isLive, isFalse);
    });
  });
```

並確認檔案頂端 import 了 `package:silversole/shared/models/device_view_data.dart` 與 `package:silversole/shared/models/ble_paired_device_model.dart`。

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/battery_level_test.dart
```
Expected: FAIL —— `SoleLiveFacts` 不存在、`buildDeviceRows` 還是舊簽章。

- [ ] **Step 3: 改寫 `device_view_data.dart`**

整份換成：

```dart
import 'package:flutter/foundation.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// What one sole is reporting right now.
@immutable
class SoleLiveFacts {
  const SoleLiveFacts({required this.online, this.batteryPercent});

  /// A sole that is not streaming at all.
  const SoleLiveFacts.offline() : online = false, batteryPercent = null;

  /// True while this sole's own telemetry is fresh.
  final bool online;

  /// The level it last reported on the live stream, if any.
  final int? batteryPercent;
}

/// A paired device plus the live facts for that sole.
class DeviceRow {
  const DeviceRow({
    required this.device,
    required this.online,
    required this.battery,
  });

  final BlePairedDevice device;

  /// True while this sole's own telemetry is fresh. With one sole per foot,
  /// more than one row can be online at a time.
  final bool online;

  /// Live for a sole that is streaming a valid reading; every other row shows
  /// the level remembered from that sole's last session.
  final BatteryDisplay battery;
}

/// Derives the devices panel's rows.
///
/// [liveFor] answers, per sole identityKey, whether that sole is streaming and
/// what it last reported — [SoleLiveFacts.offline] for a sole that is not.
List<DeviceRow> buildDeviceRows({
  required List<BlePairedDevice> devices,
  required SoleLiveFacts Function(String identityKey) liveFor,
}) {
  final rows = <DeviceRow>[];
  for (final device in devices) {
    final live = liveFor(device.identityKey);
    rows.add(
      DeviceRow(
        device: device,
        online: live.online,
        battery: BatteryDisplay.resolve(
          live: live.online ? live.batteryPercent : null,
          lastKnown: device.lastBatteryPercent,
        ),
      ),
    );
  }
  return rows;
}
```

- [ ] **Step 4: 改兩個呼叫點**

`lib/shared/pages/devices_page.dart` 的 `build` 裡，把

```dart
    final recent = ref.watch(telemetryViewProvider).recentImu;
    final rows = buildDeviceRows(
      devices: settings.pairedDevicesList,
      preferred: settings.preferredDevice,
      online: ref.watch(deviceOnlineProvider),
      liveBatteryPercent: recent.isEmpty ? null : recent.last.batteryPercent,
    );
```

換成

```dart
    // Watched so the rows re-evaluate when the last sole goes quiet: that
    // flip is driven by a timer, and no telemetry event announces silence.
    ref.watch(deviceOnlineProvider);
    final facade = ref.watch(telemetryFacadeProvider);
    final rows = buildDeviceRows(
      devices: settings.pairedDevicesList,
      liveFor: (key) {
        final telemetry = ref.watch(liveTelemetryProvider(key));
        return SoleLiveFacts(
          online: facade.checkDeviceOnline(telemetry.updatedAt),
          batteryPercent: telemetry.recentImu.lastOrNull?.batteryPercent,
        );
      },
    );
```

import 調整：移除 `telemetry_view_provider.dart`（若該檔其他地方不再用到），加入

```dart
import 'package:collection/collection.dart';
import 'package:silversole/shared/models/device_view_data.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';
```

`lib/shared/pages/theme_two/devices_page_t2.dart:32-37` 做**完全相同**的替換（同樣的 import 調整）。

- [ ] **Step 5: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/battery_level_test.dart && flutter analyze lib test && flutter test
```
Expected: 全綠。

- [ ] **Step 6: Commit**

```bash
git add lib/shared/models/device_view_data.dart lib/shared/pages/devices_page.dart lib/shared/pages/theme_two/devices_page_t2.dart test/battery_level_test.dart
git commit -m "$(cat <<'MSG'
feat(devices): give every row its own sole's status and battery

The list assumed one connection at a time, so only the primary row could
ever read online. With a sole per foot both rows can be live at once.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 11: 熱力圖接上真實的左腳

**Files:**
- Modify: `lib/shared/providers/foot_telemetry_provider.dart`（新增 `rightFootTelemetryProvider`）
- Modify: `lib/shared/widgets/pressure_demo_scope.dart`（改讀依腳別的 telemetry）
- Modify: `lib/shared/widgets/foot_pressure_heatmap.dart`（修正 doc comment）
- Modify: `lib/shared/widgets/pressure_readouts.dart`（修正 doc comment）
- Test: `test/foot_telemetry_provider_test.dart`（擴充）、`test/analytics_pressure_demo_test.dart`（擴充）

**Interfaces:**
- Consumes: Task 6 的 `footSoleKeyProvider` / `footTelemetryProvider` / `primarySoleKeyProvider`
- Produces: `final rightFootTelemetryProvider = Provider<LiveTelemetryState>(…)`

- [ ] **Step 1: 寫會失敗的測試**

在 `test/foot_telemetry_provider_test.dart` 的 `main()` 最後加入：

```dart
  group('rightFootTelemetryProvider', () {
    test('uses the sole assigned to the right foot', () {
      final container = _boot([
        _sole('L', side: FootSide.left),
        _sole('R', side: FootSide.right),
      ]);
      container.read(liveTelemetryProvider('R').notifier).updateImuNotifyData(_imu(500));
      expect(
        container.read(rightFootTelemetryProvider).recentImu.last.pressure,
        [500, 500, 500],
      );
    });

    // One uncalibrated sole has always drawn the right foot, and still must:
    // this is the single-sole case the whole app shipped with.
    test('an uncalibrated single sole still draws the right foot', () {
      final container = _boot([_sole('A')]);
      container.read(liveTelemetryProvider('A').notifier).updateImuNotifyData(_imu(300));
      expect(
        container.read(rightFootTelemetryProvider).recentImu.last.pressure,
        [300, 300, 300],
      );
    });

    // The left sole's data must never be drawn on the right foot just because
    // it happens to be the only one paired.
    test('a lone left sole leaves the right foot empty', () {
      final container = _boot([
        _sole('L', side: FootSide.left),
      ]);
      container.read(liveTelemetryProvider('L').notifier).updateImuNotifyData(_imu(300));
      expect(container.read(rightFootTelemetryProvider).recentImu, isEmpty);
      expect(
        container.read(footTelemetryProvider(FootSide.left)).recentImu,
        isNotEmpty,
      );
    });
  });
```

在 `test/analytics_pressure_demo_test.dart` 的最後一個 testWidgets 之後加入一個新的（**同一檔只能 mount 一次 `EasyLocalization`**，所以沿用既有的 `_pumpAnalytics`，它每次都重新建立 widget 樹但 `EasyLocalization.ensureInitialized()` 已經呼叫過，照既有測試的寫法即可）：

```dart
  testWidgets('a left sole feeds the left foot instead of a dash', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();

    final settings = _Settings(
      const AppSettings(
        pairedDevicesList: [
          BlePairedDevice(
            remoteId: 'l',
            name: 'SilverSole',
            deviceId: 'L',
            footSide: FootSide.left,
          ),
          BlePairedDevice(
            remoteId: 'r',
            name: 'SilverSole',
            deviceId: 'R',
            footSide: FootSide.right,
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(() => settings)],
    );
    addTearDown(container.dispose);
    container.read(liveTelemetryProvider('L').notifier).updateImuNotifyData(
      _imu(const [11, 22, 33]),
    );
    container.read(liveTelemetryProvider('R').notifier).updateImuNotifyData(
      _imu(const [44, 55, 66]),
    );

    await tester.runAsync(
      () => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
            path: 'assets/translations/strings.csv',
            assetLoader: CsvAssetLoader(),
            fallbackLocale: const Locale('en'),
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appTheme(Brightness.light),
                home: Scaffold(
                  body: PressureDemoScope(
                    builder: (context, reading, header) => Column(
                      children: [
                        header,
                        Text('p=${reading.right}'),
                        Text('left=${reading.left}'),
                        Text('has=${reading.hasData}'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('p=[44, 55, 66]'), findsOneWidget);
    expect(find.text('left=[11, 22, 33]'), findsOneWidget);
    expect(find.text('has=true'), findsOneWidget);
  });
```

並在該檔頂端加入所需 import 與兩個 helper：

```dart
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

/// Settings a test can hand straight in, skipping the shared_preferences load.
class _Settings extends SettingsNotifier {
  _Settings(this._initial);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}

ImuNotifyDataModel _imu(List<int> pressure) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: pressure,
  batteryPercent: 90,
  isCharging: false,
);
```

> 這些壓力值會先經過 `ImuMovingAverageFilter`。若它平滑了壓力通道導致上面的斷言對不上，就把斷言改成讀 filter 後的實際值 —— 先跑一次測試看印出的實際字串，再把期望值填成那個值，並在測試裡加一行註解說明是 filter 後的值。

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_telemetry_provider_test.dart test/analytics_pressure_demo_test.dart
```
Expected: FAIL —— `rightFootTelemetryProvider` 不存在；`PressureDemoScope` 還在讀 `telemetryViewProvider`，左腳仍是 null。

- [ ] **Step 3: 新增 `rightFootTelemetryProvider`**

在 `lib/shared/providers/foot_telemetry_provider.dart` 最後加入：

```dart
/// What to draw on the right foot.
///
/// The sole assigned to it; or — before anyone has calibrated — whichever sole
/// is primary, as long as it is not the one already assigned to the left foot.
/// A single uncalibrated sole has drawn the right foot since the app shipped
/// and still does, while the left sole's readings never leak onto the right
/// foot just because it is the only sole paired.
final rightFootTelemetryProvider = Provider<LiveTelemetryState>((ref) {
  final assigned = ref.watch(footSoleKeyProvider(FootSide.right));
  if (assigned != null) return ref.watch(liveTelemetryProvider(assigned));

  final leftKey = ref.watch(footSoleKeyProvider(FootSide.left));
  final fallback = ref.watch(primarySoleKeyProvider);
  if (fallback == null || fallback == leftKey) return _noTelemetry;
  return ref.watch(liveTelemetryProvider(fallback));
});
```

- [ ] **Step 4: 讓 `PressureDemoScope` 讀依腳別的 telemetry**

在 `lib/shared/widgets/pressure_demo_scope.dart`：

1. import 把 `telemetry_process_providers/telemetry_view_provider.dart` 換成

```dart
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';
```

2. 把 `build` 開頭的

```dart
    final imu = ref.watch(telemetryViewProvider).recentImu;
    final clip = _clip;
    final left = clip?.left;
```

   換成

```dart
    final rightImu = ref.watch(rightFootTelemetryProvider).recentImu;
    final leftImu = ref.watch(footTelemetryProvider(FootSide.left)).recentImu;
    final clip = _clip;
    final clipLeft = clip?.left;
```

3. 把 `PressureReading(...)` 換成

```dart
      PressureReading(
        right:
            clip?.right[_frame] ??
            (rightImu.isNotEmpty
                ? rightImu.last.pressure
                : const <int>[0, 0, 0]),
        // A sample clip overrides both feet; otherwise the left foot is live
        // only once a sole is assigned to it. Same frame index — the parser
        // already put both feet on one timeline.
        left:
            clipLeft?[_frame] ??
            (leftImu.isNotEmpty ? leftImu.last.pressure : null),
        hasData: clip != null || rightImu.isNotEmpty || leftImu.isNotEmpty,
      ),
```

4. 把 `PressureReading.left` 的 doc comment 換成

```dart
  /// Null whenever nothing is feeding the left foot — no sample clip playing
  /// and no sole assigned to that foot.
```

- [ ] **Step 5: 修掉兩處過期的 doc comment**

1. `lib/shared/widgets/foot_pressure_heatmap.dart` —— 類別 doc comment 的

```dart
/// The sole only ever reports a right foot, so [leftPressure] is null in
/// practice; a left foot without data is drawn as a bare mirrored outline. The
```

   換成

```dart
/// [leftPressure] is null until a sole is assigned to the left foot; a foot
/// without data is drawn as a bare mirrored outline. The
```

   以及 `leftPressure` 欄位的

```dart
  /// Latest left-foot readings, or null when there is no left-foot source at
  /// all — which is every real and sample recording today.
```

   換成

```dart
  /// Latest left-foot readings, or null when nothing is feeding that foot —
  /// no sole assigned to it and no sample clip playing.
```

2. `lib/shared/widgets/pressure_readouts.dart` —— 類別 doc comment 的

```dart
/// A foot with no source reads `--` rather than 0, so an unwired left foot is
/// never mistaken for one measuring nothing.
```

   換成

```dart
/// A foot with no source reads `--` rather than 0, so a foot with no sole on
/// it is never mistaken for one measuring nothing.
```

- [ ] **Step 5b: 補掉 Task 6 留下的三個測試缺口**

這三項來自 Task 6 的 review，都落在這一關會碰到的檔案上。

1. **`latestTelemetryAt` 的「只前進」性質目前沒被釘住。** `test/foot_telemetry_provider_test.dart` 裡那個 `the newest stamp across soles…` 案例用的是真實時鐘，而真實時鐘本來就單調遞增，所以「後寫者覆蓋」的實作也會過 —— 它無法分辨「取各 sole 的最大值」和「最後一個寫入者勝」。用 `clock` 套件的 `withClock` 重寫：讓第二隻鞋墊在**較早**的時間戳寫入，然後斷言 `latestTelemetryAtProvider` 的值**沒有退回去**。

2. **沒有任何雙腳的 `deviceOnlineProvider` 測試。** Step 6 的核心行為改變（「任一隻在線即在線」）目前只用單一個 key `'A'` 跑過。在 `test/device_online_provider_test.dart` 補一個 `fakeAsync` 案例：兩隻鞋墊都餵資料 → 在線；只讓其中一隻繼續餵，另一隻靜默超過 `TelemetryFacade.onlineWindow` → **仍然在線**；兩隻都靜默超過視窗 → 離線。沿用該檔現有的 `fakeAsync` + `_sample()` 寫法。

3. **格式。** `dart format --output=none --set-exit-if-changed test/foot_telemetry_provider_test.dart` 目前會回報需要變更。在這一關結束前對你碰過的測試檔跑一次 `dart format`。

- [ ] **Step 6: 跑整套測試**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter analyze lib test && flutter test
```
Expected: 全綠。特別確認 `analytics_pressure_demo_test` 原有的三個測試（走路樣本、mascot 樣本、閒置時 `left=null`）仍然過 —— 沒有配對鞋墊時左腳本來就該是 null。

- [ ] **Step 7: Commit**

```bash
git add lib/shared/providers/foot_telemetry_provider.dart lib/shared/widgets/pressure_demo_scope.dart lib/shared/widgets/foot_pressure_heatmap.dart lib/shared/widgets/pressure_readouts.dart test/foot_telemetry_provider_test.dart test/analytics_pressure_demo_test.dart
git commit -m "$(cat <<'MSG'
feat(analytics): draw the left foot from the sole worn on it

The heat map has taken a leftPressure since it was written; until now
nothing but a canned clip could supply one.

A lone left sole leaves the right foot empty rather than drawing its
readings on the wrong side, while a single uncalibrated sole keeps
drawing the right foot exactly as it always has.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---
### Task 12: 「踩一下左腳」校正流程

**Files:**
- Create: `lib/shared/providers/foot_side_calibration_provider.dart`
- Create: `lib/shared/pages/foot_side_calibration_modal.dart`
- Modify: `lib/app.dart`（包進 `builder:`）
- Modify: `assets/translations/strings.csv`
- Test: `test/foot_side_calibration_overlay_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `setFootSide` / `assignFootSide`、Task 3 的 `maxSoles`、Task 4 的 `FootSideCalibrator`、Task 6 的 `liveTelemetryProvider(key)`、Task 8 的 `connectedSolesProvider`
- Produces:
  - `final connectedPairedSolesProvider = Provider<List<BlePairedDevice>>(…)`
  - `final needsFootSideCalibrationProvider = Provider<bool>(…)`
  - `class FootSideCalibrationOverlay extends ConsumerStatefulWidget { Widget child; }`

- [ ] **Step 1: 加入 i18n 字串**

在 `assets/translations/strings.csv` 最後加上（**不要**在值裡出現逗號，CSV 是用逗號分欄的）：

```
foot_side_calibration_title,Which sole is which?,分辨左右腳
foot_side_calibration_hint,Stand still for a moment. Then press down with your left foot.,先站著別動一下。然後用左腳用力踩一下。
foot_side_calibration_prompt,Step on your left foot,請用左腳踩一下
foot_side_calibration_ambiguous,Both soles answered. Try again and press only your left foot.,兩隻鞋墊都有反應。請只用左腳再踩一次。
foot_side_calibration_timeout,No pressure detected. Choose the left sole by hand.,沒有偵測到壓力。請手動指定左腳。
foot_side_this_is_left,This is my left,這隻是左腳
foot_side_retry,Try again,重試
foot_side_later,Later,稍後再說
foot_side_unassigned,Not assigned,未指定
set_left_foot,Set as left foot,設為左腳
set_right_foot,Set as right foot,設為右腳
debug_add_fake_sole,Add a fake second sole,加入假的第二隻鞋墊
debug_remove_fake_sole,Remove the fake sole,移除假鞋墊
debug_fake_sole_stomp,Stomp,踩一下
```

- [ ] **Step 2: 寫會失敗的測試**

```dart
// test/foot_side_calibration_overlay_test.dart
import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/pages/foot_side_calibration_modal.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

const _left = BlePairedDevice(
  remoteId: 'l',
  name: 'SilverSole',
  deviceId: '00000000000000AA',
);
const _right = BlePairedDevice(
  remoteId: 'r',
  name: 'SilverSole',
  deviceId: '00000000000000BB',
);

/// Settings that assign in memory, so the test never touches
/// shared_preferences. [assignFootSide] is the same pure function the real
/// notifier persists through.
class _Settings extends SettingsNotifier {
  @override
  AppSettings build() =>
      const AppSettings(pairedDevicesList: [_left, _right]);

  @override
  Future<void> setFootSide(String identityKey, FootSide? side) async {
    state = state.copyWith(
      pairedDevicesList: assignFootSide(
        state.pairedDevicesList,
        identityKey,
        side,
      ),
    );
  }
}

ImuNotifyDataModel _imu(int load) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 1000,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: [load, load, load],
  batteryPercent: 80,
  isCharging: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One EasyLocalization mount per file: it keeps global state, so a second
  // mount never leaves its loading state.
  testWidgets('stepping on a sole makes it the left foot', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);

    // Both feet connected, neither with a side yet.
    container.read(connectedSolesProvider.notifier)
      ..set(_left.identityKey, const ConnectedSole(device: _left, dfuSupported: false))
      ..set(_right.identityKey, const ConnectedSole(device: _right, dfuSupported: false));

    await tester.runAsync(
      () => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
            path: 'assets/translations/strings.csv',
            assetLoader: CsvAssetLoader(),
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appTheme(Brightness.light),
                home: const FootSideCalibrationOverlay(
                  child: Scaffold(body: SizedBox()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // It asks, unprompted, as soon as the second foot is on.
    expect(find.text('Step on your left foot'), findsOneWidget);

    // 50 Hz frames with a fake clock, because the calibrator arbitrates on
    // sample timestamps rather than on arrival order.
    var now = DateTime(2026, 10, 20, 9);
    void frame({required int left, required int right}) {
      now = now.add(const Duration(milliseconds: 20));
      withClock(Clock(() => now), () {
        container
            .read(liveTelemetryProvider(_left.identityKey).notifier)
            .updateImuNotifyData(_imu(left));
        container
            .read(liveTelemetryProvider(_right.identityKey).notifier)
            .updateImuNotifyData(_imu(right));
      });
    }

    // A second of standing still fills both baselines.
    for (var i = 0; i < 60; i++) {
      frame(left: 0, right: 0);
    }
    // Then a step on the left sole, well past the arbitration window.
    for (var i = 0; i < 40; i++) {
      frame(left: 2000, right: 0);
    }
    await tester.pumpAndSettle();

    final paired = container.read(settingsProvider).pairedDevicesList;
    expect(
      paired.firstWhere((d) => d.identityKey == _left.identityKey).footSide,
      FootSide.left,
    );
    expect(
      paired.firstWhere((d) => d.identityKey == _right.identityKey).footSide,
      FootSide.right,
    );

    // Answered, so the overlay gets out of the way.
    expect(find.text('Step on your left foot'), findsNothing);
  });
}
```

- [ ] **Step 3: 跑測試確認失敗**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_side_calibration_overlay_test.dart
```
Expected: FAIL —— `foot_side_calibration_modal.dart` 不存在。

- [ ] **Step 4: 建立「何時該校正」的 provider**

```dart
// lib/shared/providers/foot_side_calibration_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/sole_reconcile.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// The connected soles, in paired order — what a calibration is about.
final connectedPairedSolesProvider = Provider<List<BlePairedDevice>>((ref) {
  final connected = ref.watch(connectedSolesProvider);
  if (connected.isEmpty) return const [];
  return ref
      .watch(settingsProvider)
      .pairedDevicesList
      .where((d) => connected.containsKey(d.identityKey))
      .toList();
});

/// Whether the wearer still has to say which sole is which.
///
/// True once both feet are connected and either sole has no side yet. A single
/// sole is never asked: there is nothing to compare it against, and the app
/// has always drawn one sole as the right foot.
final needsFootSideCalibrationProvider = Provider<bool>((ref) {
  final soles = ref.watch(connectedPairedSolesProvider);
  return soles.length >= maxSoles && soles.any((d) => d.footSide == null);
});
```

- [ ] **Step 5: 建立校正 overlay**

```dart
// lib/shared/pages/foot_side_calibration_modal.dart
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/foot_side_calibration.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/providers/foot_side_calibration_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

/// How long to wait for a step before offering to pick the sides by hand. A
/// dead FSR must never trap the wearer in here.
const _calibrationTimeout = Duration(seconds: 15);

/// Reading mapped to a full bar: three sensors at the heat map's own scale.
const _fullScale = 4096 * 3;

/// Asks the wearer which sole is which, as soon as both feet are connected.
///
/// Wrapped around the whole app like `FallDemoOverlay` rather than pushed as a
/// route: the question is about the hardware, not about wherever the wearer
/// happens to be, and an overlay needs no navigator context.
///
/// Stays up until the sides are assigned or the wearer puts it off; "later"
/// comes back the next time a different pair of soles connects.
class FootSideCalibrationOverlay extends ConsumerStatefulWidget {
  const FootSideCalibrationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FootSideCalibrationOverlay> createState() =>
      _FootSideCalibrationOverlayState();
}

class _FootSideCalibrationOverlayState
    extends ConsumerState<FootSideCalibrationOverlay> {
  /// The pair the wearer put off answering for.
  String? _dismissedPair;

  @override
  Widget build(BuildContext context) {
    final soles = ref.watch(connectedPairedSolesProvider);
    final needed = ref.watch(needsFootSideCalibrationProvider);
    final pair = soles.map((s) => s.identityKey).join('+');

    return Stack(
      children: [
        widget.child,
        if (needed && _dismissedPair != pair)
          _CalibrationPanel(
            // A different pair gets a fresh panel, and therefore fresh
            // baselines and subscriptions.
            key: ValueKey(pair),
            soles: soles,
            onDismiss: () => setState(() => _dismissedPair = pair),
          ),
      ],
    );
  }
}

class _CalibrationPanel extends ConsumerStatefulWidget {
  const _CalibrationPanel({
    super.key,
    required this.soles,
    required this.onDismiss,
  });

  /// The connected soles — two of them, by [needsFootSideCalibrationProvider].
  final List<BlePairedDevice> soles;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_CalibrationPanel> createState() => _CalibrationPanelState();
}

class _CalibrationPanelState extends ConsumerState<_CalibrationPanel> {
  final _calibrator = FootSideCalibrator();
  final _subs = <ProviderSubscription<LiveTelemetryState>>[];

  /// Latest pressure sum per sole, for the live bars.
  final _sums = <String, int>{};

  Timer? _timeout;
  var _ambiguous = false;
  var _timedOut = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    // listenManual rather than ref.listen in build: one subscription per sole
    // key, created once. The panel's ValueKey means a different pair rebuilds
    // this State from scratch instead of swapping keys underneath it.
    for (final sole in widget.soles) {
      final soleKey = sole.identityKey;
      _subs.add(
        ref.listenManual(liveTelemetryProvider(soleKey), (_, next) {
          final sample = next.recentImu.lastOrNull;
          final at = next.updatedAt;
          if (sample == null || at == null) return;
          _feed(soleKey, sample.pressure.fold<int>(0, (a, b) => a + b), at);
        }),
      );
    }
    _armTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    for (final sub in _subs) {
      sub.close();
    }
    super.dispose();
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(_calibrationTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  void _feed(String soleKey, int sum, DateTime at) {
    if (_saving || !mounted) return;
    setState(() => _sums[soleKey] = sum);
    final decision = _calibrator.add(soleKey, sum, at);
    if (decision == null) return;
    if (decision.ambiguous) {
      setState(() => _ambiguous = true);
      _restart();
      return;
    }
    unawaited(_assign(decision.leftKey!));
  }

  /// Measures again from scratch — the "try again" button, and what an
  /// ambiguous step does on its own.
  void _restart() {
    _calibrator.reset();
    _sums.clear();
    _armTimeout();
    setState(() => _timedOut = false);
  }

  /// Writes both sides at once: the sole that was stepped on is the left foot,
  /// so the other one is the right. The panel disappears on its own when
  /// [needsFootSideCalibrationProvider] goes false.
  Future<void> _assign(String leftKey) async {
    if (_saving) return;
    setState(() => _saving = true);
    final settings = ref.read(settingsProvider.notifier);
    await settings.setFootSide(leftKey, FootSide.left);
    for (final sole in widget.soles) {
      if (sole.identityKey == leftKey) continue;
      await settings.setFootSide(sole.identityKey, FootSide.right);
    }
  }

  String _label(BlePairedDevice sole) =>
      sole.shortId == null ? sole.name : '••••${sole.shortId}';

  @override
  Widget build(BuildContext context) {
    final message = _timedOut
        ? 'foot_side_calibration_timeout'.tr()
        : _ambiguous
        ? 'foot_side_calibration_ambiguous'.tr()
        : 'foot_side_calibration_hint'.tr();

    return Material(
      color: context.colorScheme.scrim.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.base,
                  children: [
                    Text(
                      'foot_side_calibration_title'.tr(),
                      style: context.textTheme.titleLarge,
                    ),
                    Text(message, style: context.textTheme.bodyMedium),
                    if (!_timedOut)
                      Text(
                        'foot_side_calibration_prompt'.tr(),
                        style: context.textTheme.headlineSmall,
                      ),
                    for (final sole in widget.soles)
                      _SolePressureRow(
                        label: _label(sole),
                        value: ((_sums[sole.identityKey] ?? 0) / _fullScale)
                            .clamp(0.0, 1.0),
                        // Offered only once the wait timed out, so the usual
                        // path stays "step on it".
                        onPickLeft: _timedOut
                            ? () => unawaited(_assign(sole.identityKey))
                            : null,
                      ),
                    Row(
                      spacing: AppSpacing.sm,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onDismiss,
                            child: Text('foot_side_later'.tr()),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: _restart,
                            child: Text('foot_side_retry'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One sole's live pressure, plus the by-hand escape once the wait timed out.
class _SolePressureRow extends StatelessWidget {
  const _SolePressureRow({
    required this.label,
    required this.value,
    required this.onPickLeft,
  });

  final String label;
  final double value;
  final VoidCallback? onPickLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.textTheme.labelLarge)),
            if (onPickLeft != null)
              TextButton(
                onPressed: onPickLeft,
                child: Text('foot_side_this_is_left'.tr()),
              ),
          ],
        ),
        LinearProgressIndicator(
          year2023: false, // ignore: deprecated_member_use
          value: value,
          minHeight: 10,
          borderRadius: BorderRadius.circular(999),
          stopIndicatorRadius: 0,
          trackGap: 4,
          backgroundColor: context.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(context.tokens.dataOrange),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: 掛進 `app.dart`**

把 `builder:` 換成

```dart
      // Both wrap every page in either theme: the calibration question is
      // about the hardware and the fall panel has to cover everything.
      builder: (context, child) => FootSideCalibrationOverlay(
        child: FallDemoOverlay(child: child ?? const SizedBox.shrink()),
      ),
```

並 import `package:silversole/shared/pages/foot_side_calibration_modal.dart`。

- [ ] **Step 7: 跑測試確認通過**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter test test/foot_side_calibration_overlay_test.dart && flutter analyze lib test && flutter test
```
Expected: 全綠。

- [ ] **Step 8: Commit**

```bash
git add lib/shared/providers/foot_side_calibration_provider.dart lib/shared/pages/foot_side_calibration_modal.dart lib/app.dart assets/translations/strings.csv test/foot_side_calibration_overlay_test.dart
git commit -m "$(cat <<'MSG'
feat(ble): ask the wearer to step on their left foot

Two identical soles connect and nothing in the firmware says which foot
either is on, so the wearer settles it with one step. Whichever sole's
FSRs answer is the left one and the other becomes the right.

A 15 s wait then offers to pick by hand, and "later" puts it off, so a
dead FSR never traps anyone in here.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 13: 裝置頁顯示腳別、手動指派，以及 debug 假鞋墊

**Files:**
- Create: `lib/core/ble/debug_fake_sole.dart`
- Modify: `lib/shared/pages/devices_page.dart`（腳別徽章、popup 選單兩項、debug 卡片）
- Modify: `lib/shared/pages/theme_two/devices_page_t2.dart`（腳別徽章）
- Test: 無新單測 —— 這一關的驗收是 `flutter analyze` + `flutter test` 全綠，加上實機手測（見 Step 5）

**Interfaces:**
- Consumes: Task 1 的 `setFootSide` / `FootSide`、Task 8 的 `connectedSolesProvider`、Task 6 的 `liveTelemetryProvider(key)`
- Produces: `class DebugFakeSole`（`start()` / `stop()` / `stomp()` / `isRunning`）、`final debugFakeSoleProvider`

- [ ] **Step 1: 在裝置列顯示腳別**

`lib/shared/pages/devices_page.dart` 裡那段顯示 `••••$shortId` 的 `Row`，在 `shortId` 之後加一個腳別徽章：

```dart
                  if (device.footSide case final side?)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.secondaryContainer,
                        borderRadius: AppRadius.pillShape,
                      ),
                      child: Text(
                        side.labelKey.tr(),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
```

> `AppRadius.pillShape` 若是 `ShapeBorder` 而不是 `BorderRadius`，就改用 `BorderRadius.circular(999)`；先看 `lib/core/theme/app_radius.dart` 怎麼宣告的。

`lib/shared/pages/theme_two/devices_page_t2.dart` 的對應位置做相同的加法（該檔的裝置列若樣式不同，就沿用它自己的徽章寫法，顏色仍走 `context.colorScheme`）。

- [ ] **Step 2: 加入手動指派的選單項**

同一檔 `buildMaterialPopupMenu` 的 `raw:` 清單裡，在 `set_primary_device_title` 之後插入兩項：

```dart
            ListTileData.normal(
              title: 'set_left_foot'.tr(),
              icon: LucideIcons.footprints,
              enable: device.footSide != FootSide.left,
              onClick: () => setFootSide(device, FootSide.left),
            ),
            ListTileData.normal(
              title: 'set_right_foot'.tr(),
              icon: LucideIcons.footprints,
              enable: device.footSide != FootSide.right,
              onClick: () => setFootSide(device, FootSide.right),
            ),
```

並把 `onSetPreferred` 旁邊加一個 `onSetFootSide` 參數一路傳下來（與 `onRename` / `onDelete` 完全相同的做法），在 `_DevicesPageState` 裡實作：

```dart
  /// Assigning a foot takes it off whichever sole had it — see
  /// [assignFootSide].
  Future<void> setFootSide(BlePairedDevice device, FootSide side) async {
    await ref
        .read(settingsProvider.notifier)
        .setFootSide(device.identityKey, side);
    showMessage(side.labelKey.tr());
  }
```

> `LucideIcons.footprints` 若不存在就用 `LucideIcons.move`；以 `flutter analyze` 的結果為準。

- [ ] **Step 3: 建立 debug 假鞋墊**

```dart
// lib/core/ble/debug_fake_sole.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

/// A second sole for development, where only one real one is in hand.
///
/// Fakes nothing about BLE. It registers a paired entry, reports itself
/// connected and pushes synthetic samples into that sole's telemetry — the
/// very providers a real session writes to — so the two-foot pipeline and the
/// calibration overlay can be exercised on a phone with one real sole.
///
/// Resting by default, because a sole that is always under load would decide
/// the calibration by itself. [stomp] is the step.
///
/// Debug builds only: nothing in release code refers to this.
class DebugFakeSole {
  DebugFakeSole(this._ref);

  /// 16 hex characters, like a real chip ID, and obviously not one.
  static const identityKey = 'FACEFACEFACEFACE';

  static const device = BlePairedDevice(
    remoteId: 'FA:CE:00:00:00:01',
    name: 'SilverSole (fake)',
    deviceId: identityKey,
  );

  /// 50 Hz, the rate the firmware streams at.
  static const _interval = Duration(milliseconds: 20);

  /// 20 frames at 50 Hz — a 400 ms step.
  static const _stompFrames = 20;

  final Ref _ref;
  final _random = math.Random(7);
  Timer? _ticker;
  var _pressing = 0;

  bool get isRunning => _ticker != null;

  /// Pairs the fake sole, reports it connected and starts its stream.
  Future<void> start() async {
    if (_ticker != null) return;
    await _ref.read(settingsProvider.notifier).addOrUpdatePairedDevice(device);
    _ref
        .read(connectedSolesProvider.notifier)
        .set(
          identityKey,
          const ConnectedSole(device: device, dfuSupported: false),
        );
    _ticker = Timer.periodic(_interval, (_) => _push());
  }

  /// Stops the stream and forgets the pairing.
  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _pressing = 0;
    _ref.read(connectedSolesProvider.notifier).clear(identityKey);
    await _ref.read(settingsProvider.notifier).removePairedDevice(device);
  }

  /// One 400 ms pressure spike — the step the calibration is waiting for.
  void stomp() => _pressing = _stompFrames;

  void _push() {
    if (_pressing > 0) _pressing--;
    final noise = _random.nextInt(30);
    final load = _pressing > 0 ? 1800 + _random.nextInt(400) : 0;
    _ref
        .read(liveTelemetryProvider(identityKey).notifier)
        .updateImuNotifyData(
          ImuNotifyDataModel(
            ax: 0,
            ay: 0,
            az: 1000,
            gx: 0,
            gy: 0,
            gz: 0,
            pitch: 0,
            roll: 0,
            pressure: [load + noise, load + noise, noise],
            batteryPercent: 77,
            isCharging: false,
          ),
        );
  }
}

final debugFakeSoleProvider = Provider<DebugFakeSole>((ref) {
  final fake = DebugFakeSole(ref);
  ref.onDispose(() => fake.stop());
  return fake;
});
```

- [ ] **Step 4: 在裝置頁加上 debug 卡片**

在 `lib/shared/pages/devices_page.dart` 的 `Column` 子項裡，`_FirmwareCard()` 之後加上：

```dart
              if (kDebugMode) const _DebugFakeSoleCard(),
```

並在該檔最後加入：

```dart
/// Debug-only handle on the fake second sole — the only way to exercise two
/// feet with one sole in hand.
class _DebugFakeSoleCard extends ConsumerStatefulWidget {
  const _DebugFakeSoleCard();

  @override
  ConsumerState<_DebugFakeSoleCard> createState() => _DebugFakeSoleCardState();
}

class _DebugFakeSoleCardState extends ConsumerState<_DebugFakeSoleCard> {
  @override
  Widget build(BuildContext context) {
    final fake = ref.watch(debugFakeSoleProvider);
    return SectionCard(
      title: 'debug_add_fake_sole'.tr(),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () async {
                fake.isRunning ? await fake.stop() : await fake.start();
                if (context.mounted) setState(() {});
              },
              child: Text(
                fake.isRunning
                    ? 'debug_remove_fake_sole'.tr()
                    : 'debug_add_fake_sole'.tr(),
              ),
            ),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: fake.isRunning ? fake.stomp : null,
              child: Text('debug_fake_sole_stomp'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
```

> `SectionCard` 的具名參數以 `lib/shared/widgets/section_card.dart` 的實際簽章為準（可能是 `title:` + `child:`，也可能需要 `onTap:`）。

- [ ] **Step 5: 跑測試，然後實機手測**

Run:
```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter analyze lib test && flutter test
```
Expected: 全綠。

接著在 Android 實機上（接著唯一那隻真鞋墊）用 debug build 走一遍：

1. `flutter run` → 裝置頁 → 真鞋墊連上、顯示 online。
2. 按「加入假的第二隻鞋墊」→ 校正面板應自動跳出，兩條壓力條都在動（真鞋墊那條會跟著腳動）。
3. 按「踩一下」→ 假鞋墊被判成左腳，真鞋墊自動成為右腳，面板消失，裝置列出現「左腳 / 右腳」徽章。
4. 分析頁 → 足壓分佈 → 兩腳都有資料，不再是 `--`。
5. 通知列應顯示 `左腳 77% · 右腳 <真實電量>`。
6. 按「移除假鞋墊」→ 回到單腳，左腳回到空輪廓。
7. 用選單手動把真鞋墊改成左腳 → 假鞋墊的左腳標記應被清掉（互斥）。

- [ ] **Step 6: Commit**

```bash
git add lib/core/ble/debug_fake_sole.dart lib/shared/pages/devices_page.dart lib/shared/pages/theme_two/devices_page_t2.dart assets/translations/strings.csv
git commit -m "$(cat <<'MSG'
feat(devices): show each sole's foot, and fake a second one in debug

Only one sole is in hand right now, so the two-foot pipeline and the
calibration overlay would otherwise be untestable by hand. The fake sole
fakes no BLE: it writes to the same telemetry providers a real session
does, and rests until told to stomp.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

### Task 14: 更新 CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`（「The BLE → telemetry pipeline」一節）

**Interfaces:**
- Consumes: 全部
- Produces: 無程式碼

- [ ] **Step 0: 修掉 Layering 段落裡已不存在的 provider**（來自 Task 8 的 concern）

`CLAUDE.md` 第 36 行的 Layering 說明還拿 `bleConnectProvider` 當例子：

```
E.g. `soleProvider → SilverSoleService(supabase)`, `bleConnectProvider → BleConnectionService()`.
```

Task 8 已經刪掉 `bleConnectProvider`（`lib` 與 `test` 裡都沒有殘留了），所以這個例子現在指向一個不存在的東西。改成現在的形狀：`soleSessionsProvider → SoleSessionRegistry()`，並說明它持有每隻鞋墊一個 `BleConnectionService` 實例。

這一行在 Layering 段落而不是 pipeline 段落，所以如果只改 pipeline 就會留下來。

- [ ] **Step 1: 改寫第 2 點「Connection orchestration」**

把 `BleConnectionService` 「owns the single live session」那段改寫，說明：
- `bleForegroundControlProvider` 現在維護 `SoleSessionRegistry` 裡**每隻鞋墊一個** `BleConnectionService`，上限 `maxSoles = 2`（`lib/core/ble/sole_reconcile.dart`）。
- `pickSoles()` 回傳排序後的清單，第一優先是**已指派腳別的那一對**；`reconcileSoleLinks()` 決定要連誰、要斷誰，並且**掃描看不到一隻已連線的鞋墊不是斷線的理由**（連線中的鞋墊通常不廣播）。
- attach 是**依序**的：fbp 2.1.1 的每個 GATT 操作共用一把 `"global"` mutex，`setOperationQueueMode` 在該版還不存在。
- watchdog 改成每隻一個，掛在 `SoleLink` 上。

- [ ] **Step 2: 改寫第 4 點「Live telemetry」**

說明 `liveTelemetryProvider` 是以 `identityKey` 為 key 的 family；`footTelemetryProvider(side)` 做腳別對應；`primaryTelemetryProvider` 是單隻 UI 的轉接層，`telemetryViewProvider` 轉發它，所以所有在雙腳之前寫的畫面行為不變；`deviceOnlineProvider` 現在是「任一隻在線」，吃 `latestTelemetryAtProvider`。

- [ ] **Step 3: 新增一點「Foot sides」**

在第 1 點「Sole identity」之後插入一段：韌體完全沒有左右腳概念（已在韌體 repo 全文搜尋確認），所以腳別由 App 指派並存在 `BlePairedDevice.footSide`；指派是**互斥**的（`assignFootSide`）；兩隻都連上且有未指派時，`FootSideCalibrationOverlay` 會自動跳出要求「踩一下左腳」，由 `FootSideCalibrator`（純狀態機，`lib/core/ble/foot_side_calibration.dart`）判定；一隻沉默的鞋墊會**阻止**判定而不是把答案交給唯一有讀數的那隻。

- [ ] **Step 4: 更新第 7 點 OTA**

補上：`hold(identityKey)` 期間會**主動 detach 另一隻鞋墊**，因為 OTA 的 page write 與另一隻的 handshake 搶同一把 global mutex；`dfuLink(identityKey)` 指名目標；兩腳都要更新就跑兩次，不做並行 OTA。

- [ ] **Step 5: 更新「Pipeline implementation status」**

把 Live IMU 那一條改成雙腳：兩隻各自 notify → 各自的 `LiveTelemetryNotifier` → `footTelemetryProvider` → 熱力圖兩腳都是真實資料。Record 那條補一句「仍只跟 primary 那隻」。

- [ ] **Step 6: 確認 CLAUDE.md 沒有被其他 session 同時改動**

Run:
```bash
git diff --stat CLAUDE.md
git log --oneline -3 -- CLAUDE.md
```
Expected: 只有自己這次的改動。若出現別的 session 的 hunk，只 stage 自己的段落。

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'MSG'
docs: describe the two-foot sole pipeline

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
)"
```

---

## 收尾

全部 14 關做完後：

```bash
export PATH="$HOME/Documents/Myself_Folder/_Other/flutter/bin:$PATH"
flutter analyze                     # CI 用 --no-fatal-warnings --no-fatal-infos
flutter test
flutter build apk --debug
```

然後按 Task 13 Step 5 的七步在實機上走一遍。真正的雙腳實機驗收要等借出的兩隻鞋墊回來，或請持有的團隊成員跑一次。
