# 全天步態計算 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 從每隻鞋墊未平均的 3 點壓力切出每一步，只累積連續走路的段落，存成每日統計，讓步態頁在功能開關打開時顯示使用者自己的數字。

**Architecture:** `lib/core/gait/` 放純 Dart 的管線：`StepDetector`（一隻腳一個，自適應門檻）→ `BoutFilter`（連續落地 5 次才放行）→ `GaitTracker`（管多隻鞋墊、算步數／雙腳支撐期、依日期累積 `DailyGait`）。`gaitTrackingProvider` 從既有的 `soleSampleBusProvider`（原始、未平均的樣本）收資料，每 5 分鐘和 App 進背景時把增量併進 `gaitHistoryProvider`（shared_preferences，保留 90 天）。步態頁的兩個主題改成吃一份 `GaitSnapshot`：開關關著時是原本的範例，開著時由 `realGaitSnapshot()` 從歷史算出來。

**Tech Stack:** Flutter、Riverpod 3、shared_preferences、clock、fake_async、easy_localization（CSV）。

**設計文件：** `docs/superpowers/specs/2026-10-31-daily-gait-design.md`

---

## 檔案結構

新增：

| 檔案 | 負責 |
|---|---|
| `lib/core/gait/gait_config.dart` | 所有門檻的初始值，集中一處好校正 |
| `lib/core/gait/step_detector.dart` | `Contact`、`StepDetector`：原始壓力 → 一次一次的著地 |
| `lib/core/gait/bout_filter.dart` | `BoutContact`、`BoutFilter`：只放行走路段落裡的著地 |
| `lib/core/gait/daily_gait.dart` | `GaitFoot`、`FootGaitStats`、`DailyGait`、`gaitDateKey`：每日統計與指標公式、JSON |
| `lib/core/gait/gait_tracker.dart` | `GaitTracker`：多隻鞋墊、步數規則、雙腳支撐期、跨日 |
| `lib/core/gait/gait_history.dart` | 歷史合併、90 天修剪、編碼解碼 |
| `lib/core/gait/gait_recording.dart` | 原始資料錄製格式與重播 |
| `lib/shared/providers/gait_providers.dart` | 開關、歷史、背景追蹤、跌倒次數、步態頁要顯示的 snapshot |
| `lib/shared/models/gait_real_snapshot.dart` | `realGaitSnapshot()`：歷史 → 步態頁內容 |
| `lib/shared/widgets/gait/gait_raw_record_button.dart` | debug 版的「錄原始資料」按鈕 |
| `tool/gait_replay.dart` | 命令列重播錄製檔 |
| `test/helpers/gait_signal.dart` | 測試用的合成壓力波形 |
| `test/gait_*_test.dart` | 各模組測試 |

修改：

| 檔案 | 改什麼 |
|---|---|
| `lib/constants.dart` | 加 `Constants.realGait` |
| `lib/core/data/save_service.dart` | 加 `LocalSavableKey.gaitHistory` |
| `lib/app.dart` | watch `gaitTrackingProvider`、`fallCountSinceOpenProvider` |
| `lib/shared/models/gait_analysis_data.dart` | `GaitSnapshot` 一般化（分期可空、單位／主題可換、等待天數）、`speedSeries` 改名 `series`、新增三個 `GaitTopic` |
| `lib/shared/widgets/gait/gait_panel.dart`、`gait_panel_t2.dart` | 吃 `snapshot` 而不是 `scale`；橫幅、分期、門檻、跌倒副標都改成有才顯示；加等待卡 |
| `lib/shared/pages/analytics_page.dart`、`theme_two/analytics_page_t2.dart` | 改成 Consumer，從 `gaitViewSnapshotProvider` 拿資料；debug 版放錄製按鈕 |
| `assets/translations/strings.csv` | 新字串 |
| `test/gait_panel_test.dart`、`test/gait_panel_t2_test.dart`、`test/gait_analysis_data_test.dart` | 跟著介面改 |
| `CLAUDE.md` | 管線狀態補一條 gait |

---

### Task 0：準備 worktree

**Files:** 無程式變更

> 本計畫每個 `git commit` 的訊息結尾都要加一行空行和 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。下面的指令為了好讀省略了。分支只在本地，**不推、不開 PR**，等使用者指示。

- [ ] **Step 1：補 `.env`**（不進版控，CI 會自己生；本機測試與建置需要）

```bash
cp C:/Users/Admin/dev/silversole-app/.env C:/Users/Admin/dev/silversole-app-gait/.env
```

- [ ] **Step 2：抓套件、跑一次全部測試當基準**

```bash
cd C:/Users/Admin/dev/silversole-app-gait && flutter pub get && flutter test
```

Expected：全部 PASS。有失敗先記下來，別在本計畫裡修。

---

### Task 1：合成波形工具＋`StepDetector`

**Files:**
- Create: `test/helpers/gait_signal.dart`
- Create: `lib/core/gait/gait_config.dart`
- Create: `lib/core/gait/step_detector.dart`
- Test: `test/gait_step_detector_test.dart`

- [ ] **Step 1：寫測試用波形工具**

`test/helpers/gait_signal.dart`：

```dart
import 'dart:math' as math;

/// One raw sample as the sample bus carries it: phone time and
/// `[hallux, little toe, heel]`.
typedef RawSample = ({DateTime t, List<int> pressure});

/// A foot-down span a synthetic signal is built around, from the signal's
/// origin.
typedef PlannedContact = ({Duration start, Duration end});

/// Evenly spaced contacts: one every [stride], each [stance] long.
List<PlannedContact> walkContacts({
  required int count,
  Duration first = const Duration(seconds: 1),
  Duration stride = const Duration(milliseconds: 1100),
  Duration stance = const Duration(milliseconds: 650),
}) => [
  for (var i = 0; i < count; i++)
    (start: first + stride * i, end: first + stride * i + stance),
];

/// Raw samples for one foot: [baseline] in the air, ramping over [ramp] to
/// [peak] while a planned contact holds it down, plus ±[noise] and up to
/// ±half a sample period of timing [jitter] (0 → 1).
List<RawSample> footSignal({
  required DateTime origin,
  required Duration length,
  List<PlannedContact> contacts = const [],
  int hz = 50,
  int baseline = 40,
  int peak = 3000,
  Duration ramp = const Duration(milliseconds: 40),
  int noise = 30,
  double jitter = 0,
  int seed = 1,
}) {
  final random = math.Random(seed);
  final periodUs = 1000000 ~/ hz;
  return [
    for (var us = 0; us <= length.inMicroseconds; us += periodUs)
      _sample(
        origin,
        Duration(
          microseconds: math.max(
            0,
            us + (jitter * periodUs * (random.nextDouble() - 0.5)).round(),
          ),
        ),
        _load(Duration(microseconds: us), contacts, baseline, peak, ramp) +
            random.nextInt(2 * noise + 1) -
            noise,
      ),
  ];
}

/// Raw samples swinging between [low] and [high] once per [period] — a wearer
/// standing and shifting weight from foot to foot.
List<RawSample> sineSignal({
  required DateTime origin,
  required Duration length,
  required Duration period,
  required int low,
  required int high,
  int hz = 50,
}) {
  final periodUs = 1000000 ~/ hz;
  return [
    for (var us = 0; us <= length.inMicroseconds; us += periodUs)
      _sample(
        origin,
        Duration(microseconds: us),
        low +
            ((high - low) *
                    (0.5 +
                        0.5 *
                            math.sin(
                              2 * math.pi * us / period.inMicroseconds,
                            )))
                .round(),
      ),
  ];
}

/// Merges per-foot signals into one stream ordered by time, as the bus would
/// deliver them.
List<({String sole, RawSample sample})> interleave(
  Map<String, List<RawSample>> feet,
) {
  final all = [
    for (final entry in feet.entries)
      for (final s in entry.value) (sole: entry.key, sample: s),
  ];
  all.sort((a, b) => a.sample.t.compareTo(b.sample.t));
  return all;
}

RawSample _sample(DateTime origin, Duration at, int load) {
  final total = math.max(0, load);
  final hallux = total * 3 ~/ 10;
  final little = total * 2 ~/ 10;
  return (t: origin.add(at), pressure: [hallux, little, total - hallux - little]);
}

int _load(
  Duration at,
  List<PlannedContact> contacts,
  int baseline,
  int peak,
  Duration ramp,
) {
  for (final c in contacts) {
    if (at < c.start || at > c.end) continue;
    final rise = (at - c.start).inMicroseconds / ramp.inMicroseconds;
    final fall = (c.end - at).inMicroseconds / ramp.inMicroseconds;
    final f = math.min(1.0, math.min(rise, fall));
    return baseline + ((peak - baseline) * f).round();
  }
  return baseline;
}
```

- [ ] **Step 2：寫失敗的測試**

`test/gait_step_detector_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/step_detector.dart';

import 'helpers/gait_signal.dart';

final _origin = DateTime(2026, 11, 2, 9);

List<Contact> _run(StepDetector detector, List<RawSample> samples) {
  final found = <Contact>[];
  for (final s in samples) {
    final contact = detector.add(s.t, s.pressure);
    if (contact != null) found.add(contact);
  }
  return found;
}

void main() {
  for (final hz in [50, 20]) {
    test('finds every contact of a steady walk at $hz Hz', () {
      final planned = walkContacts(count: 12);
      final found = _run(
        StepDetector(),
        footSignal(
          origin: _origin,
          length: const Duration(seconds: 15),
          contacts: planned,
          hz: hz,
          jitter: 0.5,
        ),
      );

      expect(found, hasLength(12));
      for (var i = 0; i < planned.length; i++) {
        final start = found[i].start.difference(_origin.add(planned[i].start));
        final end = found[i].end.difference(_origin.add(planned[i].end));
        expect(start.inMilliseconds.abs(), lessThanOrEqualTo(100));
        expect(end.inMilliseconds.abs(), lessThanOrEqualTo(100));
      }
    });
  }

  test('a steady load is not a step', () {
    final found = _run(
      StepDetector(),
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 20),
        baseline: 1500,
      ),
    );
    expect(found, isEmpty);
  });

  test('an empty sole is not a step', () {
    final found = _run(
      StepDetector(),
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 20),
        baseline: 0,
        noise: 0,
      ),
    );
    expect(found, isEmpty);
  });

  test('a contact cut by a gap in the data is dropped', () {
    final samples = footSignal(
      origin: _origin,
      length: const Duration(seconds: 15),
      contacts: walkContacts(count: 12),
    );
    // Contact 3 runs 3.2–3.85 s; nothing arrives from 3.3 to 4.1 s.
    final cut = [
      for (final s in samples)
        if (s.t.isBefore(_origin.add(const Duration(milliseconds: 3300))) ||
            s.t.isAfter(_origin.add(const Duration(milliseconds: 4100))))
          s,
    ];

    final found = _run(StepDetector(), cut);

    expect(found, hasLength(11));
    expect(
      found.where(
        (c) =>
            c.start.isAfter(_origin.add(const Duration(milliseconds: 3100))) &&
            c.start.isBefore(_origin.add(const Duration(milliseconds: 3400))),
      ),
      isEmpty,
    );
  });

  test('a contact shorter than the minimum is dropped', () {
    final found = _run(
      StepDetector(),
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 15),
        contacts: walkContacts(
          count: 12,
          stance: const Duration(milliseconds: 100),
        ),
      ),
    );
    expect(found, isEmpty);
  });
}
```

- [ ] **Step 3：跑測試確認失敗**

Run: `flutter test test/gait_step_detector_test.dart`
Expected：FAIL，`step_detector.dart` 不存在。

- [ ] **Step 4：寫 `GaitConfig`**

`lib/core/gait/gait_config.dart`：

```dart
/// Every threshold in the gait pipeline, in one place.
///
/// Each one is a starting value, not a derived one: they are tuned against
/// real recordings (`tool/gait_replay.dart`, design §7.2). Durations rather
/// than sample counts throughout, because the live notify rate is not pinned
/// down (20 Hz and 50 Hz both appear in the code) and the timing comes from
/// the phone clock anyway.
class GaitConfig {
  const GaitConfig({
    this.window = const Duration(seconds: 5),
    this.onFraction = 0.6,
    this.offFraction = 0.4,
    this.minLoadRange = 200,
    this.minContact = const Duration(milliseconds: 200),
    this.maxContact = const Duration(seconds: 2),
    this.maxSampleGap = const Duration(milliseconds: 500),
    this.minStride = const Duration(milliseconds: 700),
    this.maxStride = const Duration(seconds: 2),
    this.maxStrideChange = 0.4,
    this.minBoutContacts = 5,
    this.otherFootActive = const Duration(seconds: 3),
  });

  /// How far back the detector looks for the foot's low and high load.
  final Duration window;

  /// Where between that low and high a contact starts and ends. The gap
  /// between them is the hysteresis that stops noise near one line from
  /// counting twice.
  final double onFraction;
  final double offFraction;

  /// Below this spread (raw FSR counts summed over the three sensors) the
  /// sole is not being stepped on and off — standing still, sitting, not
  /// worn — and nothing is reported.
  final int minLoadRange;

  /// Contacts outside this range are not steps.
  final Duration minContact;
  final Duration maxContact;

  /// A longer silence (link loss, dropped packets) resets the detector.
  final Duration maxSampleGap;

  /// Heel strike to heel strike of the same foot, for a contact to continue
  /// a bout. A stride over [maxStride] also ends the bout.
  final Duration minStride;
  final Duration maxStride;

  /// Largest change between consecutive strides, as a fraction of the
  /// earlier one, for the walk to count as continuous.
  final double maxStrideChange;

  /// Contacts from one foot before a bout counts as walking: five landings
  /// of one foot is about ten steps.
  final int minBoutContacts;

  /// How recently another sole must have registered a contact for both feet
  /// to count as walking together.
  final Duration otherFootActive;
}
```

- [ ] **Step 5：寫 `StepDetector`**

`lib/core/gait/step_detector.dart`：

```dart
import 'dart:collection';
import 'dart:math' as math;

import 'package:silversole/core/gait/gait_config.dart';

/// One foot on the ground: from the load rising through the upper threshold
/// to it falling through the lower one.
class Contact {
  const Contact({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is Contact && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Contact($start → $end)';
}

/// Turns one sole's raw pressure into [Contact]s.
///
/// Works on the total load of the three FSRs and needs no calibration: the
/// thresholds sit between the lowest and highest load of the last
/// [GaitConfig.window], so they follow the wearer's weight and the sole's raw
/// counts on their own — the same idea as the two-feet game input's adaptive
/// pressure reference.
///
/// Must be fed **unaveraged** samples: the live moving average would smear
/// the moment the heel lands.
class StepDetector {
  StepDetector([this.config = const GaitConfig()]);

  final GaitConfig config;

  final _window = Queue<({DateTime t, int load})>();
  DateTime? _last;
  DateTime? _contactStart;

  /// Feeds one sample; returns the contact it closes, if any.
  Contact? add(DateTime t, List<int> pressure) {
    final last = _last;
    if (last != null &&
        (t.isBefore(last) || t.difference(last) > config.maxSampleGap)) {
      reset();
    }
    _last = t;

    final load = pressure.fold<int>(0, (sum, p) => sum + p);
    _window.add((t: t, load: load));
    while (t.difference(_window.first.t) > config.window) {
      _window.removeFirst();
    }

    var lo = load;
    var hi = load;
    for (final s in _window) {
      lo = math.min(lo, s.load);
      hi = math.max(hi, s.load);
    }
    final range = hi - lo;
    if (range < config.minLoadRange) {
      _contactStart = null;
      return null;
    }

    final start = _contactStart;
    if (start == null) {
      if (load >= lo + range * config.onFraction) _contactStart = t;
      return null;
    }
    if (load > lo + range * config.offFraction) return null;

    _contactStart = null;
    final contact = Contact(start: start, end: t);
    final length = contact.duration;
    if (length < config.minContact || length > config.maxContact) return null;
    return contact;
  }

  /// Forgets everything: the next sample starts a fresh window.
  void reset() {
    _window.clear();
    _last = null;
    _contactStart = null;
  }
}
```

- [ ] **Step 6：跑測試確認通過**

Run: `flutter test test/gait_step_detector_test.dart`
Expected：PASS（6 個測試）。

- [ ] **Step 7：Commit**

```bash
git add test/helpers/gait_signal.dart lib/core/gait/gait_config.dart lib/core/gait/step_detector.dart test/gait_step_detector_test.dart
git commit -m "feat(gait): detect foot contacts from raw FSR load"
```

---

### Task 2：`BoutFilter`

**Files:**
- Create: `lib/core/gait/bout_filter.dart`
- Test: `test/gait_bout_filter_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_bout_filter_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/core/gait/step_detector.dart';

final _origin = DateTime(2026, 11, 2, 9);

/// Contacts starting at [seconds] from the origin, 600 ms each.
List<Contact> _at(List<double> seconds) => [
  for (final s in seconds)
    Contact(
      start: _origin.add(Duration(milliseconds: (s * 1000).round())),
      end: _origin.add(Duration(milliseconds: (s * 1000).round() + 600)),
    ),
];

void main() {
  test('holds four contacts back and releases the fifth with them', () {
    final filter = BoutFilter();
    final contacts = _at([0, 1.1, 2.2, 3.3, 4.4]);

    for (final c in contacts.take(4)) {
      expect(filter.add(c), isEmpty);
    }
    final released = filter.add(contacts[4]);

    expect(released.map((b) => b.contact), contacts);
    expect(released.first.startsBout, isTrue);
    expect(released.first.stride, isNull);
    for (final b in released.skip(1)) {
      expect(b.stride, const Duration(milliseconds: 1100));
      expect(b.swing, const Duration(milliseconds: 500));
    }
  });

  test('once confirmed, each contact goes straight through', () {
    final filter = BoutFilter();
    final contacts = _at([0, 1.1, 2.2, 3.3, 4.4, 5.5]);
    for (final c in contacts.take(5)) {
      filter.add(c);
    }

    final released = filter.add(contacts[5]);

    expect(released, hasLength(1));
    expect(released.single.contact, contacts[5]);
    expect(released.single.stride, const Duration(milliseconds: 1100));
  });

  test('a stride over two seconds ends the bout', () {
    final filter = BoutFilter();
    for (final c in _at([0, 1.1, 2.2, 3.3, 4.4])) {
      filter.add(c);
    }
    // 3.6 s after the last one: a new bout has to build up again.
    final after = _at([8.0, 9.1, 10.2, 11.3, 12.4]);

    for (final c in after.take(4)) {
      expect(filter.add(c), isEmpty);
    }
    final released = filter.add(after[4]);
    expect(released, hasLength(5));
    expect(released.first.startsBout, isTrue);
  });

  test('a sudden change of rhythm ends the bout', () {
    final filter = BoutFilter();
    for (final c in _at([0, 1.0, 2.0, 3.0, 4.0])) {
      filter.add(c);
    }
    // 1.5 s after a 1.0 s stride: 50 %, over the 40 % limit.
    expect(filter.add(_at([5.5]).single), isEmpty);
  });

  test('strides too short to be walking never make a bout', () {
    final filter = BoutFilter();
    for (final c in _at([for (var i = 0; i < 12; i++) i * 0.5])) {
      expect(filter.add(c), isEmpty);
    }
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_bout_filter_test.dart`
Expected：FAIL，`bout_filter.dart` 不存在。

- [ ] **Step 3：寫 `BoutFilter`**

`lib/core/gait/bout_filter.dart`：

```dart
import 'package:silversole/core/gait/gait_config.dart';
import 'package:silversole/core/gait/step_detector.dart';

/// A contact that belongs to a walking bout, with its timing relative to the
/// previous contact of the same foot in that bout.
class BoutContact {
  const BoutContact({required this.contact, this.stride, this.swing});

  final Contact contact;

  /// Heel strike to heel strike from the previous contact; null on the first
  /// contact of a bout.
  final Duration? stride;

  /// Lift-off of the previous contact to this heel strike; null on the first
  /// contact of a bout.
  final Duration? swing;

  bool get startsBout => stride == null;
}

/// Lets through only the contacts of one foot that are part of continuous
/// walking.
///
/// A bout needs [GaitConfig.minBoutContacts] contacts in a row with every
/// stride inside [GaitConfig.minStride]–[GaitConfig.maxStride] and no stride
/// changing by more than [GaitConfig.maxStrideChange]. Contacts are held back
/// until the bout is confirmed, then released together; one that breaks the
/// rhythm starts a new candidate bout. Fidgeting while seated, shifting
/// weight while standing and a few odd steps therefore count for nothing.
class BoutFilter {
  BoutFilter([this.config = const GaitConfig()]);

  final GaitConfig config;

  /// The candidate bout while unconfirmed; once confirmed, only the last two
  /// contacts, which is all the rhythm check needs.
  final _held = <Contact>[];
  bool _confirmed = false;

  /// Feeds one contact; returns the contacts it lets through — none while the
  /// bout is unconfirmed, the whole backlog the moment it is confirmed.
  List<BoutContact> add(Contact contact) {
    if (_held.isNotEmpty && !_continues(contact)) {
      _held.clear();
      _confirmed = false;
    }
    _held.add(contact);

    if (_confirmed) {
      final released = _link(_held.length - 1);
      if (_held.length > 2) _held.removeRange(0, _held.length - 2);
      return [released];
    }
    if (_held.length < config.minBoutContacts) return const [];

    _confirmed = true;
    final released = [for (var i = 0; i < _held.length; i++) _link(i)];
    _held.removeRange(0, _held.length - 2);
    return released;
  }

  bool _continues(Contact contact) {
    final previous = _held.last;
    final stride = contact.start.difference(previous.start);
    if (stride < config.minStride || stride > config.maxStride) return false;
    if (_held.length < 2) return true;
    final before = previous.start.difference(_held[_held.length - 2].start);
    final change =
        (stride - before).inMicroseconds.abs() / before.inMicroseconds;
    return change <= config.maxStrideChange;
  }

  BoutContact _link(int i) {
    final contact = _held[i];
    // Index 0 of the held list is a bout's first contact only while the bout
    // is unconfirmed; afterwards _link is only ever called on the last index.
    if (i == 0) return BoutContact(contact: contact);
    final previous = _held[i - 1];
    return BoutContact(
      contact: contact,
      stride: contact.start.difference(previous.start),
      swing: contact.start.difference(previous.end),
    );
  }
}
```

- [ ] **Step 4：跑測試確認通過**

Run: `flutter test test/gait_bout_filter_test.dart`
Expected：PASS（5 個測試）。

- [ ] **Step 5：Commit**

```bash
git add lib/core/gait/bout_filter.dart test/gait_bout_filter_test.dart
git commit -m "feat(gait): keep only contacts that belong to a walking bout"
```

---

### Task 3：`DailyGait` 每日統計

**Files:**
- Create: `lib/core/gait/daily_gait.dart`
- Test: `test/gait_daily_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_daily_test.dart`：

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/step_detector.dart';

final _origin = DateTime(2026, 11, 2, 9);

BoutContact _walked(int startMs, int stanceMs, {int? strideMs, int? swingMs}) =>
    BoutContact(
      contact: Contact(
        start: _origin.add(Duration(milliseconds: startMs)),
        end: _origin.add(Duration(milliseconds: startMs + stanceMs)),
      ),
      stride: strideMs == null ? null : Duration(milliseconds: strideMs),
      swing: swingMs == null ? null : Duration(milliseconds: swingMs),
    );

DailyGait _add(
  DailyGait day,
  GaitFoot foot,
  BoutContact contact, {
  int walkingMs = 1000,
  int steps = 2,
  int doubleSupportMs = 0,
  int bothFeetWalkingMs = 0,
}) => day.withContact(
  foot: foot,
  contact: contact,
  walking: Duration(milliseconds: walkingMs),
  steps: steps,
  doubleSupport: Duration(milliseconds: doubleSupportMs),
  bothFeetWalking: Duration(milliseconds: bothFeetWalkingMs),
);

void main() {
  test('dates are local and zero-padded', () {
    expect(gaitDateKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('stride variation matches the direct calculation', () {
    final strides = [1000, 1100, 1050, 980, 1120, 1010, 1060, 990, 1080, 1030];
    var day = const DailyGait(date: '2026-11-02');
    for (final s in strides) {
      day = _add(day, GaitFoot.right, _walked(0, 600, strideMs: s, swingMs: s - 600));
    }

    final mean = strides.reduce((a, b) => a + b) / strides.length;
    final variance =
        strides.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) /
        strides.length;
    expect(day.strideCv, closeTo(math.sqrt(variance) / mean, 1e-9));
  });

  test('stride variation needs ten strides', () {
    var day = const DailyGait(date: '2026-11-02');
    for (var i = 0; i < 9; i++) {
      day = _add(day, GaitFoot.right, _walked(0, 600, strideMs: 1000, swingMs: 400));
    }
    expect(day.strideCv, isNull);
  });

  test('cadence, stance share and walking time', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(day, GaitFoot.right, _walked(0, 600), walkingMs: 600);
    for (var i = 1; i < 10; i++) {
      day = _add(
        day,
        GaitFoot.right,
        _walked(i * 1000, 600, strideMs: 1000, swingMs: 400),
      );
    }

    expect(day.steps, 20);
    expect(day.walkingMs, 600 + 9 * 1000);
    expect(day.cadence, closeTo(20 / (9600 / 60000), 1e-9));
    expect(day.stanceRatio, closeTo(600 / (600 + 400), 1e-9));
  });

  test('left-right balance needs both feet', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(day, GaitFoot.right, _walked(0, 600));
    expect(day.symmetry, isNull);

    day = _add(day, GaitFoot.left, _walked(500, 660));
    expect(day.symmetry, closeTo(600 / 660, 1e-9));
  });

  test('a sole with no side assigned never counts towards balance', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(day, GaitFoot.right, _walked(0, 600));
    day = _add(day, GaitFoot.unknown, _walked(500, 600));
    expect(day.symmetry, isNull);
  });

  test('double support is a share of the time both feet walked', () {
    var day = const DailyGait(date: '2026-11-02');
    expect(day.doubleSupportRatio, isNull);
    day = _add(
      day,
      GaitFoot.right,
      _walked(0, 600),
      steps: 1,
      doubleSupportMs: 100,
      bothFeetWalkingMs: 550,
    );
    expect(day.doubleSupportRatio, closeTo(100 / 550, 1e-9));
  });

  test('merging two halves equals recording the whole day', () {
    var whole = const DailyGait(date: '2026-11-02');
    var first = const DailyGait(date: '2026-11-02');
    var second = const DailyGait(date: '2026-11-02');
    for (var i = 0; i < 12; i++) {
      final c = _walked(i * 1000, 600 + i, strideMs: 1000 + i, swingMs: 400);
      final foot = i.isEven ? GaitFoot.left : GaitFoot.right;
      whole = _add(whole, foot, c, steps: 1, doubleSupportMs: 50, bothFeetWalkingMs: 500);
      if (i < 6) {
        first = _add(first, foot, c, steps: 1, doubleSupportMs: 50, bothFeetWalkingMs: 500);
      } else {
        second = _add(second, foot, c, steps: 1, doubleSupportMs: 50, bothFeetWalkingMs: 500);
      }
    }

    expect(first.merge(second).toJson(), whole.toJson());
  });

  test('round-trips through JSON and rejects anything else', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(day, GaitFoot.left, _walked(0, 600, strideMs: 1000, swingMs: 400));
    day = _add(day, GaitFoot.right, _walked(500, 640), doubleSupportMs: 80, bothFeetWalkingMs: 500);

    expect(DailyGait.tryFromJson(day.toJson())?.toJson(), day.toJson());
    expect(DailyGait.tryFromJson('nope'), isNull);
    expect(DailyGait.tryFromJson({'date': '2026-11-02'}), isNull);
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_daily_test.dart`
Expected：FAIL，`daily_gait.dart` 不存在。

- [ ] **Step 3：寫 `DailyGait`**

`lib/core/gait/daily_gait.dart`：

```dart
import 'dart:math' as math;

import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/shared/models/foot_side.dart';

/// Which foot a contact came from, including a sole whose side has not been
/// assigned yet — it still counts steps, but never towards left-right balance.
enum GaitFoot {
  left,
  right,
  unknown;

  static GaitFoot of(FootSide? side) => switch (side) {
    FootSide.left => left,
    FootSide.right => right,
    null => unknown,
  };
}

/// The local calendar date of [t] as `yyyy-MM-dd` — the key days are stored
/// under, which also sorts in date order.
String gaitDateKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// One foot's running sums for one day.
///
/// Sums rather than lists, so days merge by addition and a quarter of
/// history stays small. Squared stride times are kept so the variation can
/// be worked out without keeping every stride.
class FootGaitStats {
  const FootGaitStats({
    this.contacts = 0,
    this.walkingMs = 0,
    this.stanceMs = 0,
    this.swingMs = 0,
    this.strides = 0,
    this.strideMs = 0,
    this.strideSqMs = 0,
  });

  final int contacts;

  /// Time covered by this foot's bouts.
  final int walkingMs;

  /// Summed over every contact.
  final int stanceMs;

  /// Summed over every contact that has a previous one in its bout — the
  /// same contacts [strides] counts.
  final int swingMs;
  final int strides;
  final int strideMs;
  final int strideSqMs;

  FootGaitStats add(BoutContact walked, Duration walking) {
    final stride = walked.stride?.inMilliseconds;
    return FootGaitStats(
      contacts: contacts + 1,
      walkingMs: walkingMs + walking.inMilliseconds,
      stanceMs: stanceMs + walked.contact.duration.inMilliseconds,
      swingMs: swingMs + (walked.swing?.inMilliseconds ?? 0),
      strides: strides + (stride == null ? 0 : 1),
      strideMs: strideMs + (stride ?? 0),
      strideSqMs: strideSqMs + (stride == null ? 0 : stride * stride),
    );
  }

  FootGaitStats operator +(FootGaitStats other) => FootGaitStats(
    contacts: contacts + other.contacts,
    walkingMs: walkingMs + other.walkingMs,
    stanceMs: stanceMs + other.stanceMs,
    swingMs: swingMs + other.swingMs,
    strides: strides + other.strides,
    strideMs: strideMs + other.strideMs,
    strideSqMs: strideSqMs + other.strideSqMs,
  );

  Map<String, Object> toJson() => {
    'contacts': contacts,
    'walking_ms': walkingMs,
    'stance_ms': stanceMs,
    'swing_ms': swingMs,
    'strides': strides,
    'stride_ms': strideMs,
    'stride_sq_ms': strideSqMs,
  };

  static FootGaitStats? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final values = [
      json['contacts'],
      json['walking_ms'],
      json['stance_ms'],
      json['swing_ms'],
      json['strides'],
      json['stride_ms'],
      json['stride_sq_ms'],
    ];
    if (values.any((v) => v is! int)) return null;
    final v = values.cast<int>();
    return FootGaitStats(
      contacts: v[0],
      walkingMs: v[1],
      stanceMs: v[2],
      swingMs: v[3],
      strides: v[4],
      strideMs: v[5],
      strideSqMs: v[6],
    );
  }
}

/// Everything the gait tab needs from one day of walking bouts.
///
/// Every figure the tab shows is a getter over these sums, so the same
/// formulas serve one day, a week or a quarter: merge the days, then read.
class DailyGait {
  const DailyGait({
    required this.date,
    this.steps = 0,
    this.feet = const {},
    this.doubleSupportMs = 0,
    this.bothFeetWalkingMs = 0,
  });

  /// [gaitDateKey] of the day.
  final String date;

  /// Walking steps: two per contact while only one sole is walking, one per
  /// contact while both are (see `GaitTracker`).
  final int steps;
  final Map<GaitFoot, FootGaitStats> feet;

  /// Time with both feet down, and the walking time it is a share of — both
  /// only counted while two soles walk together.
  final int doubleSupportMs;
  final int bothFeetWalkingMs;

  /// Fewer strides than this and a variation says more about chance than
  /// about the wearer.
  static const minStridesForCv = 10;

  bool get hasData => steps > 0;

  /// The feet walk at the same time, so the longest foot total is the day's
  /// walking time rather than the sum.
  int get walkingMs => feet.values.fold(0, (m, f) => math.max(m, f.walkingMs));

  /// Steps per minute of walking.
  double? get cadence => walkingMs == 0 ? null : steps / (walkingMs / 60000);

  /// Share of each step with the foot down.
  double? get stanceRatio {
    final t = _total;
    if (t.contacts == 0 || t.strides == 0) return null;
    final stance = t.stanceMs / t.contacts;
    final swing = t.swingMs / t.strides;
    return stance / (stance + swing);
  }

  /// Coefficient of variation of stride time, pooled over the feet.
  double? get strideCv {
    final t = _total;
    if (t.strides < minStridesForCv) return null;
    final mean = t.strideMs / t.strides;
    final variance = math.max(0.0, t.strideSqMs / t.strides - mean * mean);
    return math.sqrt(variance) / mean;
  }

  /// The shorter mean stance time over the longer: 1 is identical feet.
  double? get symmetry {
    final left = feet[GaitFoot.left];
    final right = feet[GaitFoot.right];
    if (left == null || right == null) return null;
    if (left.contacts == 0 || right.contacts == 0) return null;
    final l = left.stanceMs / left.contacts;
    final r = right.stanceMs / right.contacts;
    return math.min(l, r) / math.max(l, r);
  }

  double? get doubleSupportRatio =>
      bothFeetWalkingMs == 0 ? null : doubleSupportMs / bothFeetWalkingMs;

  FootGaitStats get _total =>
      feet.values.fold(const FootGaitStats(), (sum, f) => sum + f);

  DailyGait withContact({
    required GaitFoot foot,
    required BoutContact contact,
    required Duration walking,
    required int steps,
    required Duration doubleSupport,
    required Duration bothFeetWalking,
  }) => DailyGait(
    date: date,
    steps: this.steps + steps,
    feet: {
      ...feet,
      foot: (feet[foot] ?? const FootGaitStats()).add(contact, walking),
    },
    doubleSupportMs: doubleSupportMs + doubleSupport.inMilliseconds,
    bothFeetWalkingMs: bothFeetWalkingMs + bothFeetWalking.inMilliseconds,
  );

  /// This day plus [other], keeping this day's [date].
  DailyGait merge(DailyGait other) => DailyGait(
    date: date,
    steps: steps + other.steps,
    feet: {
      for (final foot in {...feet.keys, ...other.feet.keys})
        foot:
            (feet[foot] ?? const FootGaitStats()) +
            (other.feet[foot] ?? const FootGaitStats()),
    },
    doubleSupportMs: doubleSupportMs + other.doubleSupportMs,
    bothFeetWalkingMs: bothFeetWalkingMs + other.bothFeetWalkingMs,
  );

  Map<String, Object> toJson() => {
    'date': date,
    'steps': steps,
    'feet': {
      for (final entry in feet.entries) entry.key.name: entry.value.toJson(),
    },
    'double_support_ms': doubleSupportMs,
    'both_walking_ms': bothFeetWalkingMs,
  };

  /// Null for anything this app did not write — better a missing day than a
  /// wrong one.
  static DailyGait? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final date = json['date'];
    final steps = json['steps'];
    final feet = json['feet'];
    final doubleSupport = json['double_support_ms'];
    final bothWalking = json['both_walking_ms'];
    if (date is! String ||
        steps is! int ||
        feet is! Map ||
        doubleSupport is! int ||
        bothWalking is! int) {
      return null;
    }
    final parsed = <GaitFoot, FootGaitStats>{};
    for (final entry in feet.entries) {
      final foot = GaitFoot.values.asNameMap()[entry.key];
      final stats = FootGaitStats.tryFromJson(entry.value);
      if (foot == null || stats == null) return null;
      parsed[foot] = stats;
    }
    return DailyGait(
      date: date,
      steps: steps,
      feet: parsed,
      doubleSupportMs: doubleSupport,
      bothFeetWalkingMs: bothWalking,
    );
  }
}
```

- [ ] **Step 4：跑測試確認通過**

Run: `flutter test test/gait_daily_test.dart`
Expected：PASS（9 個測試）。

- [ ] **Step 5：Commit**

```bash
git add lib/core/gait/daily_gait.dart test/gait_daily_test.dart
git commit -m "feat(gait): daily gait sums and the formulas read from them"
```

---

### Task 4：`GaitTracker`

**Files:**
- Create: `lib/core/gait/gait_tracker.dart`
- Test: `test/gait_tracker_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_tracker_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_tracker.dart';
import 'package:silversole/shared/models/foot_side.dart';

import 'helpers/gait_signal.dart';

final _origin = DateTime(2026, 11, 2, 9);

GaitTracker _tracker() => GaitTracker(
  footOf: (key) => switch (key) {
    'L' => FootSide.left,
    'R' => FootSide.right,
    _ => null,
  },
);

void _feed(GaitTracker tracker, String sole, List<RawSample> samples) {
  for (final s in samples) {
    tracker.add(sole, s.t, s.pressure);
  }
}

DailyGait _single(List<DailyGait> days) {
  expect(days, hasLength(1));
  return days.single;
}

void main() {
  test('one sole walking twenty contacts makes forty steps', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 25),
        contacts: walkContacts(count: 20),
      ),
    );

    final day = _single(tracker.takePending());
    expect(day.date, '2026-11-02');
    expect(day.steps, 40);
    expect(day.feet[GaitFoot.right]?.contacts, 20);
    expect(day.feet[GaitFoot.right]?.strides, 19);
    // 19 strides of 1.1 s plus the last 0.65 s stance.
    expect(day.walkingMs, closeTo(21550, 300));
    expect(day.cadence, inInclusiveRange(100, 115));
    expect(day.symmetry, isNull);
    expect(day.doubleSupportRatio, isNull);
  });

  test('four landings are not a walk, five are', () {
    final four = _tracker();
    _feed(
      four,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 8),
        contacts: walkContacts(count: 4),
      ),
    );
    expect(four.takePending(), isEmpty);
    expect(four.rawContactCount, 4);

    final five = _tracker();
    _feed(
      five,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 8),
        contacts: walkContacts(count: 5),
      ),
    );
    expect(_single(five.takePending()).steps, 10);
  });

  test('standing and shifting weight is not walking', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      sineSignal(
        origin: _origin,
        length: const Duration(seconds: 60),
        period: const Duration(seconds: 3),
        low: 1000,
        high: 2000,
      ),
    );
    expect(tracker.takePending(), isEmpty);
  });

  test('two soles walking count each contact once', () {
    final tracker = _tracker();
    final feed = interleave({
      // Short ramps: with the default 40 ms the thresholds cut ~25 ms off
      // each end of a contact and the overlaps shrink to half.
      'R': footSignal(
        origin: _origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(count: 20),
        ramp: const Duration(milliseconds: 10),
        seed: 1,
      ),
      'L': footSignal(
        origin: _origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(
          count: 20,
          first: const Duration(milliseconds: 1550),
        ),
        ramp: const Duration(milliseconds: 10),
        seed: 2,
      ),
    });
    for (final f in feed) {
      tracker.add(f.sole, f.sample.t, f.sample.pressure);
    }

    final day = _single(tracker.takePending());
    expect(day.steps, 40);
    expect(day.symmetry, closeTo(1, 0.05));
    // Each foot overlaps the other by 0.1 s at both ends of a 1.1 s stride.
    expect(day.doubleSupportRatio, closeTo(0.2 / 1.1, 0.05));
  });

  test('a walk across midnight is split between the two days', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      footSignal(
        origin: DateTime(2026, 11, 2, 23, 59, 50),
        length: const Duration(seconds: 25),
        contacts: walkContacts(count: 20),
      ),
    );

    final days = tracker.takePending()..sort((a, b) => a.date.compareTo(b.date));
    expect(days.map((d) => d.date), ['2026-11-02', '2026-11-03']);
    expect(days.fold(0, (n, d) => n + d.steps), 40);
  });

  test('pending days are handed over once', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 25),
        contacts: walkContacts(count: 20),
      ),
    );
    expect(tracker.takePending(), hasLength(1));
    expect(tracker.takePending(), isEmpty);
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_tracker_test.dart`
Expected：FAIL，`gait_tracker.dart` 不存在。

- [ ] **Step 3：寫 `GaitTracker`**

`lib/core/gait/gait_tracker.dart`：

```dart
import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_config.dart';
import 'package:silversole/core/gait/step_detector.dart';
import 'package:silversole/shared/models/foot_side.dart';

/// The foot a sole is worn on, or null while it has none assigned.
typedef FootLookup = FootSide? Function(String soleKey);

/// Runs the gait pipeline for every sole and adds up what it finds per day.
///
/// Each sole gets its own [StepDetector] and [BoutFilter]. A walking contact
/// counts as two steps while it is the only sole walking — the other foot is
/// assumed — and as one while another sole is walking too. "Walking too" is
/// judged on the other sole's raw contacts rather than its released ones,
/// because a bout releases its first contacts in a burst once confirmed.
///
/// With both feet walking, each overlap and each second of walking is seen
/// once from either foot, so both are counted at half weight; together they
/// come to the real figure.
class GaitTracker {
  GaitTracker({required FootLookup footOf, this.config = const GaitConfig()})
    : _footOf = footOf;

  final GaitConfig config;
  final FootLookup _footOf;

  final _soles = <String, _Sole>{};
  final _pending = <String, DailyGait>{};
  int _rawContacts = 0;

  /// Raw contacts kept per sole for the double-support overlap: enough to
  /// cover a bout's backlog when it is released.
  static const _rawKept = 8;

  /// Contacts found before the bout filter — for tuning (`tool/gait_replay.dart`).
  int get rawContactCount => _rawContacts;

  void add(String soleKey, DateTime t, List<int> pressure) {
    final sole = _soles.putIfAbsent(soleKey, () => _Sole(config));
    final contact = sole.detector.add(t, pressure);
    if (contact == null) return;

    _rawContacts++;
    sole.recentRaw.add(contact);
    if (sole.recentRaw.length > _rawKept) sole.recentRaw.removeAt(0);

    for (final walked in sole.bouts.add(contact)) {
      _record(soleKey, sole, walked, now: t);
    }
  }

  /// Everything recorded since the last call, one entry per local date, and
  /// forgets it.
  List<DailyGait> takePending() {
    final days = _pending.values.toList();
    _pending.clear();
    return days;
  }

  void _record(
    String soleKey,
    _Sole sole,
    BoutContact walked, {
    required DateTime now,
  }) {
    final contact = walked.contact;
    final other = _otherWalking(soleKey, now);
    final previous = sole.lastWalked;
    final walking = walked.startsBout || previous == null
        ? contact.duration
        : contact.end.difference(previous.end);

    var overlap = Duration.zero;
    if (other != null) {
      for (final o in other.recentRaw) {
        overlap += _overlap(contact, o);
      }
    }

    final date = gaitDateKey(contact.start);
    _pending[date] = (_pending[date] ?? DailyGait(date: date)).withContact(
      foot: GaitFoot.of(_footOf(soleKey)),
      contact: walked,
      walking: walking,
      steps: other == null ? 2 : 1,
      doubleSupport: overlap ~/ 2,
      bothFeetWalking: other == null ? Duration.zero : walking ~/ 2,
    );
    sole.lastWalked = contact;
  }

  _Sole? _otherWalking(String soleKey, DateTime now) {
    for (final entry in _soles.entries) {
      if (entry.key == soleKey) continue;
      final raw = entry.value.recentRaw;
      if (raw.isEmpty) continue;
      if (now.difference(raw.last.end) <= config.otherFootActive) {
        return entry.value;
      }
    }
    return null;
  }

  static Duration _overlap(Contact a, Contact b) {
    final start = a.start.isAfter(b.start) ? a.start : b.start;
    final end = a.end.isBefore(b.end) ? a.end : b.end;
    return end.isAfter(start) ? end.difference(start) : Duration.zero;
  }
}

class _Sole {
  _Sole(GaitConfig config)
    : detector = StepDetector(config),
      bouts = BoutFilter(config);

  final StepDetector detector;
  final BoutFilter bouts;
  final recentRaw = <Contact>[];
  Contact? lastWalked;
}
```

- [ ] **Step 4：跑測試確認通過**

Run: `flutter test test/gait_tracker_test.dart`
Expected：PASS（6 個測試）。若「two soles」的 `doubleSupportRatio` 沒落在範圍內，先印出 `day.doubleSupportMs` 和 `day.bothFeetWalkingMs` 檢查是不是半權重沒套到；**不要放寬測試範圍來過關**。

- [ ] **Step 5：Commit**

```bash
git add lib/core/gait/gait_tracker.dart test/gait_tracker_test.dart
git commit -m "feat(gait): track steps per day across one or two soles"
```

---

### Task 5：歷史存檔

**Files:**
- Create: `lib/core/gait/gait_history.dart`
- Modify: `lib/core/data/save_service.dart`（`LocalSavableKey`）
- Test: `test/gait_history_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_history_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';

DailyGait _day(String date, int steps) => DailyGait(date: date, steps: steps);

void main() {
  final today = DateTime(2026, 11, 2, 10);

  test('deltas for a stored day add to it, new days are added', () {
    final merged = mergeGaitHistory(
      {'2026-11-01': _day('2026-11-01', 100)},
      [_day('2026-11-01', 50), _day('2026-11-02', 30)],
      today,
    );
    expect(merged['2026-11-01']?.steps, 150);
    expect(merged['2026-11-02']?.steps, 30);
  });

  test('keeps ninety days counting today and drops the rest', () {
    final merged = mergeGaitHistory(
      {
        '2026-08-04': _day('2026-08-04', 1), // 90 days before today: dropped
        '2026-08-05': _day('2026-08-05', 1), // 89 days before: kept
      },
      const [],
      today,
    );
    expect(merged.keys, ['2026-08-05']);
  });

  test('round-trips, and anything unreadable comes back empty', () {
    final history = {
      '2026-11-01': _day('2026-11-01', 100),
      '2026-11-02': _day('2026-11-02', 30),
    };
    final decoded = decodeGaitHistory(encodeGaitHistory(history));
    expect(decoded.keys, history.keys);
    expect(decoded['2026-11-01']?.steps, 100);

    expect(decodeGaitHistory(null), isEmpty);
    expect(decodeGaitHistory('not json'), isEmpty);
    expect(decodeGaitHistory('{"a":1}'), isEmpty);
  });

  test('one unreadable day does not take the others with it', () {
    final decoded = decodeGaitHistory(
      '[{"date":"2026-11-01","steps":5,"feet":{},'
      '"double_support_ms":0,"both_walking_ms":0},{"date":3}]',
    );
    expect(decoded.keys, ['2026-11-01']);
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_history_test.dart`
Expected：FAIL，`gait_history.dart` 不存在。

- [ ] **Step 3：寫 `gait_history.dart`**

`lib/core/gait/gait_history.dart`：

```dart
import 'dart:convert';

import 'package:silversole/core/gait/daily_gait.dart';

/// Days of history kept, counting today: the quarter view needs twelve weeks.
const gaitHistoryDays = 90;

/// [history] with [deltas] added day by day, and every day older than
/// [gaitHistoryDays] before [today] dropped.
Map<String, DailyGait> mergeGaitHistory(
  Map<String, DailyGait> history,
  Iterable<DailyGait> deltas,
  DateTime today,
) {
  final merged = {...history};
  for (final delta in deltas) {
    final stored = merged[delta.date];
    merged[delta.date] = stored == null ? delta : stored.merge(delta);
  }
  final cutoff = gaitDateKey(
    DateTime(today.year, today.month, today.day - (gaitHistoryDays - 1)),
  );
  merged.removeWhere((date, _) => date.compareTo(cutoff) < 0);
  return merged;
}

String encodeGaitHistory(Map<String, DailyGait> history) =>
    jsonEncode([for (final day in history.values) day.toJson()]);

/// The stored history; empty for nothing or anything unreadable, and a day
/// that cannot be read is skipped rather than failing the rest.
Map<String, DailyGait> decodeGaitHistory(String? raw) {
  if (raw == null) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const {};
  }
  if (decoded is! List) return const {};
  return {
    for (final item in decoded)
      if (DailyGait.tryFromJson(item) case final day?) day.date: day,
  };
}
```

- [ ] **Step 4：加存檔 key**

`lib/core/data/save_service.dart` 的 `LocalSavableKey`，把

```dart
  lastFootCheck('last_foot_check');
```

改成

```dart
  lastFootCheck('last_foot_check'),
  gaitHistory('gait_history');
```

- [ ] **Step 5：跑測試確認通過**

Run: `flutter test test/gait_history_test.dart`
Expected：PASS（4 個測試）。

- [ ] **Step 6：Commit**

```bash
git add lib/core/gait/gait_history.dart lib/core/data/save_service.dart test/gait_history_test.dart
git commit -m "feat(gait): store ninety days of daily gait on the phone"
```

---

### Task 6：用 App 內建的合成走路資料跑通整條線

**Files:**
- Test: `test/gait_clip_smoke_test.dart`

這份資料是電腦合成的，**只確認接得通、有數字，不是準確度依據**。

- [ ] **Step 1：寫測試**

`test/gait_clip_smoke_test.dart`：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/gait_tracker.dart';
import 'package:silversole/shared/models/demo_motion_clip.dart';
import 'package:silversole/shared/models/foot_side.dart';

void main() {
  test('the bundled synthetic walk comes out as walking on both feet', () {
    final clip = DemoMotionClip.parse(
      File(
        'assets/foot-pressure-heatmpt-samples/synthetic_walk_pair_30s.json',
      ).readAsStringSync(),
      maxRateHz: 1000,
    );
    expect(clip, isNotNull);
    final left = clip!.left;
    expect(left, isNotNull);

    final tracker = GaitTracker(
      footOf: (key) => key == 'L' ? FootSide.left : FootSide.right,
    );
    final origin = DateTime(2026, 11, 2, 9);
    for (var i = 0; i < clip.right.length; i++) {
      final t = origin.add(clip.frameInterval * i);
      tracker.add('R', t, clip.right[i]);
      tracker.add('L', t, left![i]);
    }

    final days = tracker.takePending();
    expect(days, hasLength(1));
    final day = days.single;
    expect(day.steps, greaterThan(20));
    expect(day.cadence, isNotNull);
    expect(day.symmetry, isNotNull);
  });
}
```

- [ ] **Step 2：跑測試**

Run: `flutter test test/gait_clip_smoke_test.dart`
Expected：PASS。若 FAIL，先把 `tracker.rawContactCount` 和 `clip.frameInterval` 印出來：`rawContactCount` 是 0 代表門檻跟這份資料的壓力尺度對不上（懸空約 400、踩地約 4800，`minLoadRange` 200 應該夠）；有 contact 但步數 0 代表 `BoutFilter` 擋掉了，檢查步幅（這份約 1.06 秒）。修程式，不要改這份資料。

- [ ] **Step 3：Commit**

```bash
git add test/gait_clip_smoke_test.dart
git commit -m "test(gait): run the bundled synthetic walk through the pipeline"
```

---

### Task 7：Provider 與背景追蹤

**Files:**
- Modify: `lib/constants.dart`
- Create: `lib/shared/providers/gait_providers.dart`
- Modify: `lib/app.dart`
- Test: `test/gait_providers_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_providers_test.dart`：

```dart
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/gait_providers.dart';

import 'helpers/gait_signal.dart';

ImuNotifyDataModel _imu(List<int> pressure) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: pressure,
  batteryPercent: 100,
  isCharging: false,
);

/// Streams a twenty-contact walk onto the bus in fake time, one sample per
/// 20 ms, so the tracker's `clock.now()` stamps match the signal.
void _walk(FakeAsync async, SoleSampleBus bus) {
  final samples = footSignal(
    origin: clock.now(),
    length: const Duration(seconds: 25),
    contacts: walkContacts(count: 20),
  );
  for (final s in samples) {
    async.elapse(const Duration(milliseconds: 20));
    bus.emit(SoleSample(identityKey: 'R', data: _imu(s.pressure)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('samples on the bus reach the stored history within five minutes', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [realGaitEnabledProvider.overrideWithValue(true)],
      );
      container.read(gaitTrackingProvider);
      async.flushMicrotasks();

      _walk(async, container.read(soleSampleBusProvider));
      async.elapse(gaitFlushInterval);
      async.flushMicrotasks();

      final today = gaitDateKey(clock.now());
      expect(container.read(gaitHistoryProvider)[today]?.steps, 40);
      container.dispose();
    });
  });

  test('switched off, nothing is tracked', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [realGaitEnabledProvider.overrideWithValue(false)],
      );
      container.read(gaitTrackingProvider);
      async.flushMicrotasks();

      _walk(async, container.read(soleSampleBusProvider));
      async.elapse(gaitFlushInterval);
      async.flushMicrotasks();

      expect(container.read(gaitHistoryProvider), isEmpty);
      container.dispose();
    });
  });

  test('history added before the stored one loads is not lost', () async {
    final stored = {'2026-11-01': const DailyGait(date: '2026-11-01', steps: 7)};
    SharedPreferences.setMockInitialValues({
      LocalSavableKey.gaitHistory.value: encodeGaitHistory(stored),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await withClock(Clock.fixed(DateTime(2026, 11, 2, 9)), () async {
      await container
          .read(gaitHistoryProvider.notifier)
          .add([const DailyGait(date: '2026-11-02', steps: 3)]);
    });

    final history = container.read(gaitHistoryProvider);
    expect(history['2026-11-01']?.steps, 7);
    expect(history['2026-11-02']?.steps, 3);
    final saved = decodeGaitHistory(
      await loadLocalValue(LocalSavableKey.gaitHistory),
    );
    expect(saved.keys, containsAll(['2026-11-01', '2026-11-02']));
  });

  test('falls are counted from the moment the provider starts', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(fallCountSinceOpenProvider), 0);

    container
        .read(fallEventBusProvider)
        .emit(
          FallDetectEvent(
            timestamp: DateTime(2026, 11, 2),
            deviceId: 'R',
            detect: true,
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(fallCountSinceOpenProvider), 1);
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_providers_test.dart`
Expected：FAIL，`gait_providers.dart` 不存在。

- [ ] **Step 3：加 `Constants.realGait`**

`lib/constants.dart`，在 `static const bool friendsOnSupabase = friendsBackend == 'supabase';` 之後、`class Constants` 最後的 `}` 之前加：

```dart

  /// Whether the gait tab shows the wearer's own figures instead of the
  /// sample page. Off in release until the step detection has been tuned on
  /// real recordings (`docs/superpowers/specs/2026-10-31-daily-gait-design.md`
  /// §6); debug builds are always on (see `realGaitEnabledProvider`).
  ///
  ///     flutter run --release --dart-define=REAL_GAIT=on
  static const bool realGait = String.fromEnvironment('REAL_GAIT') == 'on';
```

- [ ] **Step 4：寫 `gait_providers.dart`（先不含 snapshot，Task 10 再加）**

`lib/shared/providers/gait_providers.dart`：

```dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';
import 'package:silversole/core/gait/gait_tracker.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// Whether gait is computed and the gait tab shows the wearer's figures.
///
/// Release builds keep the sample page until [Constants.realGait] is set —
/// the thresholds have not been tuned on real recordings yet. Debug builds
/// are always on so the pipeline can be tried.
final realGaitEnabledProvider = Provider<bool>(
  (ref) => Constants.realGait || kDebugMode,
);

/// How often the tracker's running totals are written to the phone — short
/// enough that the gait tab never lags far behind.
const gaitFlushInterval = Duration(minutes: 5);

/// The stored daily history, keyed by [gaitDateKey].
class GaitHistoryNotifier extends Notifier<Map<String, DailyGait>> {
  Future<void>? _loading;

  @override
  Map<String, DailyGait> build() {
    _loading = _load();
    return const {};
  }

  Future<void> _load() async {
    final saved = decodeGaitHistory(
      await loadLocalValue(LocalSavableKey.gaitHistory),
    );
    state = mergeGaitHistory(saved, const [], clock.now());
  }

  /// Adds [deltas] and saves. Waits for the stored history first, so an
  /// early flush can never overwrite it.
  Future<void> add(List<DailyGait> deltas) async {
    await _loading;
    if (deltas.isEmpty) return;
    state = mergeGaitHistory(state, deltas, clock.now());
    await saveLocalValue(
      LocalSavableKey.gaitHistory,
      encodeGaitHistory(state),
    );
  }
}

final gaitHistoryProvider =
    NotifierProvider<GaitHistoryNotifier, Map<String, DailyGait>>(
      GaitHistoryNotifier.new,
    );

/// Feeds every raw sample on the bus to a [GaitTracker] and flushes its
/// totals into [gaitHistoryProvider] every [gaitFlushInterval], when the app
/// goes to the background, and on dispose.
///
/// Watched once in `App`. Reads the unaveraged bus rather than the live
/// telemetry window, which is moving-averaged.
final gaitTrackingProvider = Provider<void>((ref) {
  if (!ref.watch(realGaitEnabledProvider)) return;

  final history = ref.read(gaitHistoryProvider.notifier);
  final tracker = GaitTracker(
    footOf: (key) => ref
        .read(settingsProvider)
        .pairedDevicesList
        .firstWhereOrNull((d) => d.identityKey == key)
        ?.footSide,
  );
  void flush() => unawaited(history.add(tracker.takePending()));

  final sub = ref
      .watch(soleSampleBusProvider)
      .stream
      .listen((s) => tracker.add(s.identityKey, clock.now(), s.data.pressure));
  final timer = Timer.periodic(gaitFlushInterval, (_) => flush());
  final lifecycle = AppLifecycleListener(onPause: flush);

  ref.onDispose(() {
    flush();
    unawaited(sub.cancel());
    timer.cancel();
    lifecycle.dispose();
  });
});

/// Falls reported since the app was opened. Nothing is stored, so this is
/// the honest count — the same one the mascot home card shows.
class FallCountSinceOpenNotifier extends Notifier<int> {
  @override
  int build() {
    final sub = ref.watch(fallEventBusProvider).stream.listen((_) => state++);
    ref.onDispose(sub.cancel);
    return 0;
  }
}

final fallCountSinceOpenProvider =
    NotifierProvider<FallCountSinceOpenNotifier, int>(
      FallCountSinceOpenNotifier.new,
    );
```

- [ ] **Step 5：在 App 接上**

`lib/app.dart`：加 import

```dart
import 'package:silversole/shared/providers/gait_providers.dart';
```

把

```dart
    ref.watch(bleForegroundControlProvider);
```

改成

```dart
    ref.watch(bleForegroundControlProvider);
    // Both run for the whole app session: gait totals and the fall count
    // must not start only when the gait tab is first opened.
    ref.watch(gaitTrackingProvider);
    ref.watch(fallCountSinceOpenProvider);
```

- [ ] **Step 6：跑測試確認通過**

Run: `flutter test test/gait_providers_test.dart`
Expected：PASS（4 個測試）。若第一個測試拿到 `null`：確認 `fake_async` 有接管 `clock.now()`（在測試裡印 `clock.now()` 前後各一次，應該差 25 秒以上）；若沒有，把 `_walk` 改成用 `withClock(Clock(() => origin.add(async.elapsed)), ...)` 包住整個 `fakeAsync` 內容。

- [ ] **Step 7：跑全部測試**

Run: `flutter test`
Expected：全部 PASS（App 多 watch 兩個 provider 不應影響其他測試）。

- [ ] **Step 8：Commit**

```bash
git add lib/constants.dart lib/shared/providers/gait_providers.dart lib/app.dart test/gait_providers_test.dart
git commit -m "feat(gait): track gait in the background behind REAL_GAIT"
```

---

### Task 8：`GaitSnapshot` 一般化（範例頁長相不變）

**Files:**
- Modify: `lib/shared/models/gait_analysis_data.dart`
- Modify: `lib/shared/widgets/gait/gait_panel.dart`
- Modify: `lib/shared/widgets/gait/gait_panel_t2.dart`
- Modify: `test/gait_panel_test.dart`、`test/gait_panel_t2_test.dart`、`test/gait_analysis_data_test.dart`
- Modify: `assets/translations/strings.csv`

目標：兩個面板改吃一份 `GaitSnapshot`，範例頁畫面與現有測試結果**完全不變**。

- [ ] **Step 1：改測試的建構方式（先讓它編譯失敗）**

`test/gait_panel_test.dart`：

```dart
                  builder: (_, value, _) => GaitAnalysisPanel(scale: value),
```

改成

```dart
                  builder: (_, value, _) =>
                      GaitAnalysisPanel(snapshot: gaitSnapshot(value)),
```

`test/gait_panel_t2_test.dart`：

```dart
                builder: (_, value, _) => GaitAnalysisPanelT2(scale: value),
```

改成

```dart
                builder: (_, value, _) =>
                    GaitAnalysisPanelT2(snapshot: gaitSnapshot(value)),
```

`test/gait_analysis_data_test.dart`：把每個 `speedSeries` 改成 `series`（第 78、87、96、129 行）。

Run: `flutter test test/gait_panel_test.dart`
Expected：FAIL，`snapshot` 參數不存在。

- [ ] **Step 2：改 `GaitTopic`**

`lib/shared/models/gait_analysis_data.dart` 的 `enum GaitTopic`，把

```dart
  speed(hasNote: true, hasEvidence: true),
  cadence(hasEvidence: true),
```

改成

```dart
  speed(hasNote: true, hasEvidence: true),
  steps(hasNote: true),
  cadence(hasEvidence: true),
  stance(),
  variation(hasEvidence: true),
```

- [ ] **Step 3：改 `GaitSnapshot` 建構子與欄位**

把整個 `class GaitSnapshot { const GaitSnapshot({ ... });` 的建構子換成：

```dart
  const GaitSnapshot({
    required this.scale,
    required this.heroLabelKey,
    required this.heroValue,
    required this.chartLabelKey,
    required this.series,
    required this.ability,
    required this.stability,
    required this.fallCount,
    required this.noteKey,
    this.isSample = true,
    this.phase,
    this.heroUnitKey = 'gait_unit_mps',
    this.heroTopic = GaitTopic.speed,
    this.heroDelta,
    this.heroDeltaSuffixKey,
    this.heroTone = GaitTone.neutral,
    this.thresholdNoteKey,
    this.seriesStep = 0.05,
    this.fallTitleKey = 'gait_fall_title',
    this.fallLastKey,
    this.pendingDays,
    this.smallMultiplesTitleKey = 'gait_sect_four_metrics',
    this.stanceLeft = const [],
    this.stanceRight = const [],
    this.phaseSpans = const [],
    this.referenceSpeed,
    this.referenceUncertainty,
    this.smallMultiples = const [],
    this.adviceKeys = const [],
  });
```

欄位宣告：把從 `final GaitScale scale;` 到 `final int fallCount;`（含）這一段換成下面這段；`stanceLeft` 以下的欄位與 getter 不動：

```dart
  final GaitScale scale;

  /// True for the bundled example ([gaitSnapshot]): the panel then opens with
  /// the "sample data" banner.
  final bool isSample;

  /// The trend stage on the hero card; null when there is no staging to show
  /// — the wearer's own data is never staged (design §5.3).
  final GaitPhase? phase;

  /// Keys in `strings.csv`.
  final String heroLabelKey;
  final String heroUnitKey;
  final String chartLabelKey;
  final String fallTitleKey;
  final String noteKey;
  final String smallMultiplesTitleKey;
  final String? thresholdNoteKey;
  final String? fallLastKey;

  /// The explanation behind the hero's ⓘ, and the week chart's.
  final GaitTopic heroTopic;

  /// Already formatted — the hero is the one figure read at a glance.
  final String heroValue;
  final String? heroDelta;

  /// What the delta is measured against, e.g. "vs previous 7 days".
  final String? heroDeltaSuffixKey;
  final GaitTone heroTone;

  /// One value per bucket: days on the week scale, whole weeks after that.
  final List<double> series;

  /// Snapping step for the chart's y range, in the series' own unit.
  final double seriesStep;

  final List<GaitMetric> ability;
  final List<GaitMetric> stability;

  final int fallCount;

  /// Days of data still missing before this scale can show figures; null
  /// when it can. The panel then shows a "still collecting" card instead.
  final int? pendingDays;
```

把 `phaseAt` 的最後一行

```dart
    return phaseSpans.isEmpty ? phase : phaseSpans.last.phase;
```

改成

```dart
    return phaseSpans.last.phase;
```

並把它的說明第一行改成 `/// Which phase a bucket fell in — only asked when [hasPhaseTimeline].`

在 `bool get hasAdvice => adviceKeys.isNotEmpty;` 之後加：

```dart
  bool get isPending => pendingDays != null;
```

最後把檔案裡三個 `speedSeries:` 改成 `series:`。檔頭 library 註解的「**Every figure here is mockup copy.**」那段保留，後面補一句：

```dart
/// The wearer's own figures, when gait tracking is on, come from
/// `realGaitSnapshot()` in `gait_real_snapshot.dart` in the same shape.
```

（放在 `library;` 那行之前、原本說明的最後。）

- [ ] **Step 4：改經典主題面板 `gait_panel.dart`**

4a. 類別宣告與 build：

```dart
class GaitAnalysisPanel extends StatelessWidget {
  const GaitAnalysisPanel({super.key, required this.snapshot});

  /// The "sample data" banner, for tests.
  static const sampleBannerKey = Key('gait-sample-banner');

  /// The "still collecting" card, for tests.
  static const pendingKey = Key('gait-pending');

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        if (snapshot.isSample) const _SampleBanner(),
        if (snapshot.isPending)
          _PendingCard(days: snapshot.pendingDays!)
        else ...[
          _Hero(snapshot: snapshot),

          _GroupLabel('gait_group_ability'.tr()),
          _SpeedChartCard(snapshot: snapshot),
          for (final metric in snapshot.ability) _MetricTile(metric: metric),

          _GroupLabel('gait_group_stability'.tr()),
          for (final metric in snapshot.stability) _MetricTile(metric: metric),
          if (snapshot.hasStanceChart)
            SectionCard(
              title: 'gait_sect_lr_stance'.tr(),
              child: SizedBox(
                height: 170,
                child: GaitStanceChart(
                  left: snapshot.stanceLeft,
                  right: snapshot.stanceRight,
                  leftColor: context.colorScheme.primary,
                  rightColor: context.tokens.dataOrange,
                ),
              ),
            ),
          if (snapshot.hasPhaseTimeline)
            SectionCard(
              title: 'gait_sect_phase'.tr(),
              trailing: const GaitTopicButton(topic: GaitTopic.phase),
              child: GaitPhaseTimeline(
                spans: snapshot.phaseSpans,
                colorOf: (phase) => phaseColor(context, phase),
              ),
            ),
          if (snapshot.hasSmallMultiples)
            SectionCard(
              title: snapshot.smallMultiplesTitleKey.tr(),
              child: GaitSmallMultiples(
                lines: snapshot.smallMultiples,
                colorOf: (tone) => toneColor(context, tone),
              ),
            ),
        ],

        _FallCard(snapshot: snapshot),
        if (snapshot.hasAdvice) _AdviceCard(keys: snapshot.adviceKeys),
        _NoteCard(textKey: snapshot.noteKey),
      ],
    );
  }
}
```

類別說明的「Figures are mockup copy, see [gaitSnapshot] — so the panel opens with a banner that says so and cannot be dismissed.」改成「Draws whatever [snapshot] it is given: the bundled example ([gaitSnapshot]), which opens with a banner that says so and cannot be dismissed, or the wearer's own figures.」

4b. 在 `_SampleBanner` 類別後面加：

```dart
/// Shown instead of the figures while a scale has too few days behind it —
/// an empty state rather than a number the data cannot support yet.
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: GaitAnalysisPanel.pendingKey,
      child: SectionCard(
        child: Row(
          spacing: AppSpacing.md,
          children: [
            Icon(LucideIcons.clock, color: context.colorScheme.primary),
            Expanded(
              child: Text(
                'gait_pending_days'.tr(args: ['$days']),
                style: context.textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

4c. `_SpeedChartCard`：`trailing: GaitTopicButton(topic: isWeek ? GaitTopic.speed : GaitTopic.binning,)` 改成 `topic: isWeek ? snapshot.heroTopic : GaitTopic.binning`；兩處 `values: snapshot.speedSeries,` 改成 `values: snapshot.series,`，並在這兩處各加一行 `step: snapshot.seriesStep,`。

4d. `_Hero` 的 build 換成：

```dart
  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;
    final delta = snapshot.heroDelta;
    final threshold = snapshot.thresholdNoteKey;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          if (phase != null)
            Row(
              children: [
                _PhasePill(phase: phase, color: phaseColor(context, phase)),
                const GaitTopicButton(topic: GaitTopic.phase),
              ],
            ),
          Row(
            children: [
              Flexible(
                child: Text(
                  snapshot.heroLabelKey.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              GaitTopicButton(topic: snapshot.heroTopic),
              Text(
                'gait_live_daily'.tr(),
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                snapshot.heroValue,
                style: context.textTheme.displayMedium.bold,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                snapshot.heroUnitKey.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (delta != null || threshold != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                if (delta != null)
                  Text(
                    '$delta ${snapshot.heroDeltaSuffixKey?.tr() ?? ''}',
                    style: context.textTheme.titleMedium.bold?.copyWith(
                      color: toneColor(context, snapshot.heroTone),
                    ),
                  ),
                if (threshold != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        threshold.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const GaitTopicButton(topic: GaitTopic.threshold),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
```

說明「Speed, the one figure read at a glance, with the phase it sits in.」改成「The one figure read at a glance, with the phase it sits in when there is one.」

4e. `_FallCard`：`'gait_fall_title'.tr()` 改成 `snapshot.fallTitleKey.tr()`；副標那段

```dart
                Text(
                  snapshot.fallLastKey.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
```

改成

```dart
                if (snapshot.fallLastKey case final last?)
                  Text(
                    last.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
```

- [ ] **Step 5：改吉祥物主題面板 `gait_panel_t2.dart`**（同樣的改法，換成這個主題的元件）

5a. 類別宣告與 build：

```dart
class GaitAnalysisPanelT2 extends StatelessWidget {
  const GaitAnalysisPanelT2({super.key, required this.snapshot});

  /// The "sample data" banner, for tests.
  static const sampleBannerKey = Key('gait-sample-banner-t2');

  /// The "still collecting" card, for tests.
  static const pendingKey = Key('gait-pending-t2');

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (snapshot.isSample) const _SampleBanner(),
        if (snapshot.isPending)
          _PendingCard(days: snapshot.pendingDays!)
        else ...[
          _Hero(snapshot: snapshot),

          _GroupLabel('gait_group_ability'.tr()),
          _SpeedChartCard(snapshot: snapshot),
          for (final metric in snapshot.ability) _MetricTile(metric: metric),

          _GroupLabel('gait_group_stability'.tr()),
          for (final metric in snapshot.stability) _MetricTile(metric: metric),
          if (snapshot.hasStanceChart)
            _Titled(
              title: 'gait_sect_lr_stance'.tr(),
              child: SizedBox(
                height: 170,
                child: GaitStanceChart(
                  left: snapshot.stanceLeft,
                  right: snapshot.stanceRight,
                  leftColor: AppPaletteT2.gold,
                  rightColor: AppPaletteT2.flame,
                ),
              ),
            ),
          if (snapshot.hasPhaseTimeline)
            _Titled(
              title: 'gait_sect_phase'.tr(),
              topic: GaitTopic.phase,
              child: GaitPhaseTimeline(
                spans: snapshot.phaseSpans,
                colorOf: _phaseColor,
              ),
            ),
          if (snapshot.hasSmallMultiples)
            _Titled(
              title: snapshot.smallMultiplesTitleKey.tr(),
              child: GaitSmallMultiples(
                lines: snapshot.smallMultiples,
                colorOf: _toneColor,
              ),
            ),
        ],

        _FallCard(snapshot: snapshot),
        if (snapshot.hasAdvice) _AdviceCard(keys: snapshot.adviceKeys),
        _NoteCard(textKey: snapshot.noteKey),
      ],
    );
  }
}
```

類別說明的「Figures are mockup copy, see [gaitSnapshot] — so the panel opens with a banner that says so and cannot be dismissed.」改成「Draws whatever [snapshot] it is given: the bundled example ([gaitSnapshot]), which opens with a banner that says so and cannot be dismissed, or the wearer's own figures.」

5b. 在 `_SampleBanner` 類別後面加：

```dart
/// Shown instead of the figures while a scale has too few days behind it.
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      key: GaitAnalysisPanelT2.pendingKey,
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom, color: AppPaletteT2.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'gait_pending_days'.tr(args: ['$days']),
              style: context.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
```

（先確認 `MascotCard` 的建構子有 `super.key`：`grep -n "const MascotCard" lib/shared/widgets/theme_two/mascot_card.dart`。沒有的話改用 `KeyedSubtree(key: GaitAnalysisPanelT2.pendingKey, child: MascotCard(...))`。）

5c. `_SpeedChartCard`：`topic: isWeek ? GaitTopic.speed : GaitTopic.binning,` 改成 `topic: isWeek ? snapshot.heroTopic : GaitTopic.binning,`；兩處 `values: snapshot.speedSeries,` 改成 `values: snapshot.series,`，各加一行 `step: snapshot.seriesStep,`。

5d. `_Hero` 的 build 換成：

```dart
  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;
    final delta = snapshot.heroDelta;
    final threshold = snapshot.thresholdNoteKey;

    return MascotCard(
      color: AppPaletteT2.cardWarm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phase != null) ...[
            Row(
              children: [
                MascotPill(
                  color: _phaseColor(phase),
                  child: Text(
                    phase.labelKey.tr(),
                    style: context.textTheme.labelLarge?.copyWith(
                      color: AppPaletteT2.card,
                    ),
                  ),
                ),
                GaitTopicButton(topic: GaitTopic.phase),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Flexible(
                child: Text(
                  snapshot.heroLabelKey.tr(),
                  style: context.textTheme.bodyLarge,
                ),
              ),
              GaitTopicButton(topic: snapshot.heroTopic),
              Text(
                'gait_live_daily'.tr(),
                style: context.textTheme.labelMedium,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                snapshot.heroValue,
                style: context.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppPaletteT2.ink,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                snapshot.heroUnitKey.tr(),
                style: context.textTheme.titleLarge,
              ),
            ],
          ),
          if (delta != null || threshold != null) ...[
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                if (delta != null)
                  Text(
                    '$delta ${snapshot.heroDeltaSuffixKey?.tr() ?? ''}',
                    style: context.textTheme.titleMedium.bold?.copyWith(
                      color: _toneColor(snapshot.heroTone),
                    ),
                  ),
                if (threshold != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(threshold.tr(), style: context.textTheme.bodyMedium),
                      GaitTopicButton(topic: GaitTopic.threshold),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
```

5e. `_FallCard`：`'gait_fall_title'.tr()` 改成 `snapshot.fallTitleKey.tr()`；副標

```dart
                Text(
                  snapshot.fallLastKey.tr(),
                  style: context.textTheme.bodyMedium,
                ),
```

改成

```dart
                if (snapshot.fallLastKey case final last?)
                  Text(last.tr(), style: context.textTheme.bodyMedium),
```

- [ ] **Step 6：加這一步就會用到的字串**

`assets/translations/strings.csv` 檔尾加（英文不放逗號，中文用全形標點）：

```csv
gait_pending_days,Collecting data: {} more day(s) needed,資料累積中，還要 {} 天
gait_help_steps_title,Daily walking steps,每日走路步數
gait_help_steps_body,Steps taken during walks of 10 or more steps in a row. Short shuffles and sitting or shifting weight while standing are left out — so the number is lower than a phone or band pedometer.,連續走 10 步以上時的步數。零星幾步、坐著、站著換重心都不算，所以會比手機或手環計步少。
gait_help_steps_note,With one sole the steps are estimated as that foot's landings times two.,只穿一隻鞋墊時，步數是用那隻腳落地次數乘以 2 估算。
gait_help_stance_title,Stance share,站立期比例
gait_help_stance_body,Of each step the share the foot spends on the ground rather than swinging through. It comes from when the pressure under the sole rises and falls.,每一步裡，腳踩在地上（而不是抬起來往前擺）的時間占比，用鞋墊壓力升起和落下的時間算出來。
gait_help_variation_title,Step timing variation,每步時間差異
gait_help_variation_body,How much the time each step takes varies — the coefficient of variation of stride time. Lower means a steadier rhythm.,每一步花的時間有多不一樣，用跨步時間的變異係數表示。越小代表節奏越穩，忽快忽慢會讓數字變大。
gait_help_variation_evidence,Arch Phys Med Rehabil 2001: 52 older adults wore force-sensing insoles for a year. Stride-time variability was 106±30 ms among those who fell against 49±4 ms among those who did not.,Arch Phys Med Rehabil 2001：52 位長者穿力感應鞋墊追蹤 1 年。跌倒者跨步時間變異度 106±30 ms、未跌倒者 49±4 ms，與本產品同一類感測方式。
```

- [ ] **Step 7：跑步態相關測試**

Run: `flutter test test/gait_panel_test.dart test/gait_panel_t2_test.dart test/gait_analysis_data_test.dart`
Expected：PASS，範例頁的所有斷言都沒改就過。`gait_analysis_data_test` 若有「每個 GaitTopic 都有字串」的檢查，三個新主題靠 Step 6 的字串過關。

- [ ] **Step 8：Commit**

```bash
git add lib/shared/models/gait_analysis_data.dart lib/shared/widgets/gait/gait_panel.dart lib/shared/widgets/gait/gait_panel_t2.dart test/gait_panel_test.dart test/gait_panel_t2_test.dart test/gait_analysis_data_test.dart assets/translations/strings.csv
git commit -m "refactor(gait): panels draw any snapshot, not only the sample"
```

---

### Task 9：`realGaitSnapshot`

**Files:**
- Create: `lib/shared/models/gait_real_snapshot.dart`
- Modify: `assets/translations/strings.csv`
- Test: `test/gait_real_snapshot_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_real_snapshot_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/models/gait_real_snapshot.dart';

final _today = DateTime(2026, 11, 2, 15);

/// A day [daysAgo] before today with [steps] walking steps on the right foot:
/// one minute of walking per 100 steps, 650 ms stance, 1100 ms strides.
DailyGait _day(int daysAgo, int steps, {bool bothFeet = false}) {
  final date = gaitDateKey(
    DateTime(_today.year, _today.month, _today.day - daysAgo),
  );
  final contacts = steps ~/ 2;
  final foot = FootGaitStats(
    contacts: contacts,
    walkingMs: steps * 600,
    stanceMs: contacts * 650,
    swingMs: contacts * 450,
    strides: contacts,
    strideMs: contacts * 1100,
    strideSqMs: contacts * 1100 * 1100,
  );
  return DailyGait(
    date: date,
    steps: steps,
    feet: {GaitFoot.right: foot, if (bothFeet) GaitFoot.left: foot},
    doubleSupportMs: bothFeet ? steps * 100 : 0,
    bothFeetWalkingMs: bothFeet ? steps * 600 : 0,
  );
}

Map<String, DailyGait> _history(List<DailyGait> days) => {
  for (final d in days) d.date: d,
};

String? _value(List<GaitMetric> metrics, String nameKey) =>
    metrics.where((m) => m.nameKey == nameKey).firstOrNull?.value;

void main() {
  test('no data at all: every scale is still collecting', () {
    for (final scale in GaitScale.values) {
      final s = realGaitSnapshot(
        scale: scale,
        history: const {},
        today: _today,
        fallCount: 0,
      );
      expect(s.isSample, isFalse);
      expect(s.pendingDays, gaitDaysNeeded(scale));
    }
  });

  test('week: averages the days worn and charts each day', () {
    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([_day(0, 3000), _day(2, 5000)]),
      today: _today,
      fallCount: 2,
    );

    expect(s.isPending, isFalse);
    expect(s.phase, isNull);
    expect(s.heroValue, '4000');
    expect(s.heroUnitKey, 'gait_unit_steps');
    expect(s.heroTopic, GaitTopic.steps);
    expect(s.series, [0, 0, 0, 0, 5000, 0, 3000]);
    expect(s.fallCount, 2);
    expect(s.fallLastKey, isNull);
    expect(s.referenceSpeed, isNull);
    expect(s.adviceKeys, isEmpty);
    // 8000 steps over 2 × 8000 × 600 ms → 8000 / (4800 s / 60) = 100 / min.
    expect(_value(s.ability, 'gait_metric_cadence'), '100');
    expect(_value(s.ability, 'gait_metric_stance'), '59');
    expect(_value(s.stability, 'gait_metric_stride_cv'), '0.0');
    expect(_value(s.stability, 'gait_metric_symmetry'), isNull);
    expect(_value(s.stability, 'gait_metric_double_support'), isNull);
  });

  test('days outside the window do not count towards it', () {
    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([_day(8, 3000)]),
      today: _today,
      fallCount: 0,
    );
    expect(s.pendingDays, 1);
  });

  test('month needs seven days in the last four weeks', () {
    final six = _history([for (var i = 0; i < 6; i++) _day(i, 3000)]);
    expect(
      realGaitSnapshot(
        scale: GaitScale.month,
        history: six,
        today: _today,
        fallCount: 0,
      ).pendingDays,
      1,
    );

    final seven = _history([for (var i = 0; i < 7; i++) _day(i, 3000)]);
    final s = realGaitSnapshot(
      scale: GaitScale.month,
      history: seven,
      today: _today,
      fallCount: 0,
    );
    expect(s.isPending, isFalse);
    expect(s.series, hasLength(4));
    expect(s.series.last, 3000);
  });

  test('both feet bring balance and double support', () {
    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([_day(0, 3000, bothFeet: true)]),
      today: _today,
      fallCount: 0,
    );
    expect(_value(s.stability, 'gait_metric_symmetry'), '100');
    expect(_value(s.stability, 'gait_metric_double_support'), '16.7');
  });

  test('quarter draws weekly lines once 28 days are in', () {
    final s = realGaitSnapshot(
      scale: GaitScale.quarter,
      history: _history([for (var i = 0; i < 28; i++) _day(i, 3000 + i * 10)]),
      today: _today,
      fallCount: 0,
    );
    expect(s.isPending, isFalse);
    expect(s.series, hasLength(12));
    expect(s.smallMultiplesTitleKey, 'gait_sect_weekly_metrics');
    expect(
      s.smallMultiples.map((l) => l.nameKey),
      containsAll(['gait_metric_daily_steps', 'gait_metric_cadence']),
    );
    for (final line in s.smallMultiples) {
      expect(line.values, hasLength(4), reason: 'only weeks with data');
    }
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_real_snapshot_test.dart`
Expected：FAIL，`gait_real_snapshot.dart` 不存在。

- [ ] **Step 3：寫 `realGaitSnapshot`**

`lib/shared/models/gait_real_snapshot.dart`：

```dart
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';

/// Days with data inside a scale's window before it shows figures (design
/// §5.2): a week needs one, four weeks need seven, twelve weeks need 28.
int gaitDaysNeeded(GaitScale scale) => switch (scale) {
  GaitScale.week => 1,
  GaitScale.month => 7,
  GaitScale.quarter => 28,
};

typedef _Bucket = ({DailyGait total, int days});

/// The gait tab for [scale], from the wearer's own [history].
///
/// No phase, no reference speed, no advice and no deltas: those need months
/// of a personal baseline (design §5.3). Until the window holds
/// [gaitDaysNeeded] days with data the snapshot is a "still collecting" one
/// and carries no figures at all.
GaitSnapshot realGaitSnapshot({
  required GaitScale scale,
  required Map<String, DailyGait> history,
  required DateTime today,
  required int fallCount,
}) {
  final buckets = switch (scale) {
    GaitScale.week => _buckets(history, today, count: 7, days: 1),
    GaitScale.month => _buckets(history, today, count: 4, days: 7),
    GaitScale.quarter => _buckets(history, today, count: 12, days: 7),
  };
  final daysWithData = buckets.fold(0, (n, b) => n + b.days);
  final need = gaitDaysNeeded(scale);

  if (daysWithData < need) {
    return GaitSnapshot(
      scale: scale,
      isSample: false,
      pendingDays: need - daysWithData,
      heroLabelKey: '',
      heroValue: '',
      chartLabelKey: '',
      series: const [],
      ability: const [],
      stability: const [],
      fallCount: fallCount,
      fallTitleKey: _fallTitleKey,
      noteKey: _noteKey,
    );
  }

  var window = const DailyGait(date: '');
  for (final b in buckets) {
    window = window.merge(b.total);
  }

  return GaitSnapshot(
    scale: scale,
    isSample: false,
    heroLabelKey: switch (scale) {
      GaitScale.week => 'gait_hero_steps_week',
      GaitScale.month => 'gait_hero_steps_month',
      GaitScale.quarter => 'gait_hero_steps_quarter',
    },
    heroValue: (window.steps / daysWithData).round().toString(),
    heroUnitKey: 'gait_unit_steps',
    heroTopic: GaitTopic.steps,
    chartLabelKey: switch (scale) {
      GaitScale.week => 'gait_sect_daily_steps',
      GaitScale.month => 'gait_sect_four_weeks',
      GaitScale.quarter => 'gait_sect_twelve_weeks',
    },
    series: [for (final b in buckets) _dailySteps(b) ?? 0],
    seriesStep: 100,
    ability: [
      if (window.cadence case final cadence?)
        _metric(
          'gait_metric_cadence',
          GaitTopic.cadence,
          'gait_reading_cadence_real',
          cadence.round().toString(),
          'gait_unit_spm',
        ),
      _metric(
        'gait_metric_walk_minutes',
        GaitTopic.steps,
        'gait_reading_walk_minutes',
        (window.walkingMs / 60000 / daysWithData).round().toString(),
        'gait_unit_min',
      ),
      if (window.stanceRatio case final stance?)
        _metric(
          'gait_metric_stance',
          GaitTopic.stance,
          'gait_reading_stance_real',
          (stance * 100).round().toString(),
          'gait_unit_percent',
        ),
    ],
    stability: [
      if (window.strideCv case final cv?)
        _metric(
          'gait_metric_stride_cv',
          GaitTopic.variation,
          'gait_reading_stride_cv',
          (cv * 100).toStringAsFixed(1),
          'gait_unit_percent',
        ),
      if (window.symmetry case final symmetry?)
        _metric(
          'gait_metric_symmetry',
          GaitTopic.symmetry,
          'gait_reading_sym_real',
          (symmetry * 100).round().toString(),
          'gait_unit_percent',
        ),
      if (window.doubleSupportRatio case final ds?)
        _metric(
          'gait_metric_double_support',
          GaitTopic.doubleSupport,
          'gait_reading_ds_real',
          (ds * 100).toStringAsFixed(1),
          'gait_unit_percent',
        ),
    ],
    fallCount: fallCount,
    fallTitleKey: _fallTitleKey,
    noteKey: _noteKey,
    smallMultiplesTitleKey: 'gait_sect_weekly_metrics',
    smallMultiples: scale != GaitScale.quarter
        ? const []
        : [
            for (final line in [
              _line('gait_metric_daily_steps', buckets, _dailySteps),
              _line('gait_metric_cadence', buckets, (b) => b.total.cadence),
              _line(
                'gait_metric_stride_cv',
                buckets,
                (b) => _percent(b.total.strideCv),
              ),
              _line(
                'gait_metric_symmetry',
                buckets,
                (b) => _percent(b.total.symmetry),
              ),
            ])
              ?line,
          ],
  );
}

const _fallTitleKey = 'gait_fall_title_since_open';
const _noteKey = 'gait_note_real';

/// [count] buckets of [days] days each, oldest first, the last one ending
/// today.
List<_Bucket> _buckets(
  Map<String, DailyGait> history,
  DateTime today, {
  required int count,
  required int days,
}) => [
  for (var b = count - 1; b >= 0; b--)
    _bucket(history, today, endsDaysAgo: b * days, days: days),
];

_Bucket _bucket(
  Map<String, DailyGait> history,
  DateTime today, {
  required int endsDaysAgo,
  required int days,
}) {
  var total = const DailyGait(date: '');
  var withData = 0;
  for (var i = 0; i < days; i++) {
    final day = history[gaitDateKey(
      DateTime(today.year, today.month, today.day - endsDaysAgo - i),
    )];
    if (day == null || !day.hasData) continue;
    total = total.merge(day);
    withData++;
  }
  return (total: total, days: withData);
}

/// Average daily steps over the days in [b] that have data.
double? _dailySteps(_Bucket b) => b.days == 0 ? null : b.total.steps / b.days;

double? _percent(double? fraction) => fraction == null ? null : fraction * 100;

/// A weekly line over the buckets that have data, or null with fewer than
/// two points to draw.
GaitTrendLine? _line(
  String nameKey,
  List<_Bucket> buckets,
  double? Function(_Bucket b) valueOf,
) {
  final values = <double>[
    for (final b in buckets)
      if (b.days > 0) ?valueOf(b),
  ];
  if (values.length < 2) return null;
  return GaitTrendLine(nameKey: nameKey, values: values, tone: GaitTone.neutral);
}

GaitMetric _metric(
  String nameKey,
  GaitTopic topic,
  String readingKey,
  String value,
  String unitKey,
) => GaitMetric(
  nameKey: nameKey,
  topic: topic,
  readingKey: readingKey,
  value: value,
  unitKey: unitKey,
  delta: '',
);
```

（`?line`、`?valueOf(b)` 是 Dart 3.8 的 null-aware element，pubspec 的 SDK 是 `^3.9.0`，可以用。）

- [ ] **Step 4：加字串**

`assets/translations/strings.csv` 檔尾加：

```csv
gait_hero_steps_week,Daily walking steps · 7-day average,近 7 天平均每日走路步數
gait_hero_steps_month,Daily walking steps · 4-week average,近 4 週平均每日走路步數
gait_hero_steps_quarter,Daily walking steps · 12-week average,近 12 週平均每日走路步數
gait_sect_daily_steps,Walking steps per day,每日走路步數
gait_sect_weekly_metrics,Week by week,每週指標
gait_unit_steps,steps,步
gait_unit_min,min,分鐘
gait_metric_walk_minutes,Walking time per day,每日走路時間
gait_metric_stance,Stance share,站立期比例
gait_metric_stride_cv,Step timing variation,每步時間差異
gait_metric_daily_steps,Daily steps,每日步數
gait_reading_cadence_real,Steps per minute while walking,走路時每分鐘的步數
gait_reading_walk_minutes,Only walks of 10 or more steps count,只算連續走 10 步以上
gait_reading_stance_real,Share of each step with the foot down,每一步裡腳踩在地上的時間占比
gait_reading_stride_cv,Lower means a steadier rhythm,越小代表節奏越穩
gait_reading_sym_real,How alike the two feet's stance times are,左右腳踩地時間有多接近
gait_reading_ds_real,Share of walking time with both feet down,走路時雙腳同時著地的時間占比
gait_fall_title_since_open,Falls since the app was opened,開啟 App 以來跌倒
gait_note_real,Only walks of 10 or more steps in a row count. Sitting and shifting weight while standing do not. With one sole the steps are estimated as that foot's landings times two.,只計算連續走 10 步以上的走路，坐著、站著換重心都不算。只穿一隻鞋墊時，步數是用那隻腳落地次數乘以 2 估算。
```

- [ ] **Step 5：跑測試確認通過**

Run: `flutter test test/gait_real_snapshot_test.dart test/gait_analysis_data_test.dart`
Expected：PASS。

- [ ] **Step 6：Commit**

```bash
git add lib/shared/models/gait_real_snapshot.dart assets/translations/strings.csv test/gait_real_snapshot_test.dart
git commit -m "feat(gait): build the gait tab from the wearer's own history"
```

---

### Task 10：步態頁接上真資料

**Files:**
- Modify: `lib/shared/providers/gait_providers.dart`
- Modify: `lib/shared/pages/analytics_page.dart`
- Modify: `lib/shared/pages/theme_two/analytics_page_t2.dart`
- Test: `test/gait_panel_real_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_panel_real_test.dart`：

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/widgets/gait/gait_panel.dart';

/// Holds whatever history a test hands it, without touching storage.
class _FixedHistory extends GaitHistoryNotifier {
  _FixedHistory(this.days);

  final Map<String, DailyGait> days;

  @override
  Map<String, DailyGait> build() => days;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount: EasyLocalization keeps global state between mounts.
  testWidgets('real mode: no banner, collecting card, then the steps', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final today = gaitDateKey(DateTime.now());
    final scale = ValueNotifier(GaitScale.month);
    addTearDown(scale.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          realGaitEnabledProvider.overrideWithValue(true),
          gaitHistoryProvider.overrideWith(
            () => _FixedHistory({
              today: DailyGait(
                date: today,
                steps: 3200,
                feet: const {
                  GaitFoot.right: FootGaitStats(
                    contacts: 1600,
                    walkingMs: 1920000,
                    stanceMs: 1040000,
                    swingMs: 720000,
                    strides: 1600,
                    strideMs: 1760000,
                    strideSqMs: 1936000000,
                  ),
                },
              ),
            }),
          ),
        ],
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
                body: SingleChildScrollView(
                  child: ValueListenableBuilder(
                    valueListenable: scale,
                    builder: (_, value, _) => Consumer(
                      builder: (_, ref, _) => GaitAnalysisPanel(
                        snapshot: ref.watch(gaitViewSnapshotProvider(value)),
                      ),
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

    // Month with one day of data: six more to go, no figures, no banner.
    expect(find.byKey(GaitAnalysisPanel.sampleBannerKey), findsNothing);
    expect(find.byKey(GaitAnalysisPanel.pendingKey), findsOneWidget);
    expect(find.text('Collecting data: 6 more day(s) needed'), findsOneWidget);
    expect(find.text('Falls since the app was opened'), findsOneWidget);

    // Week: today's steps, no phase, no speed, one sole so no balance row.
    scale.value = GaitScale.week;
    await tester.pumpAndSettle();
    expect(find.byKey(GaitAnalysisPanel.pendingKey), findsNothing);
    expect(find.text('3200'), findsOneWidget);
    expect(find.text('Daily walking steps · 7-day average'), findsOneWidget);
    expect(find.text('Walking steps per day'), findsOneWidget);
    expect(find.text('Cadence'), findsOneWidget);
    expect(find.text('Step timing variation'), findsOneWidget);
    expect(find.text('Left-right balance'), findsNothing);
    expect(find.text('Stable'), findsNothing);
    expect(find.text('m/s'), findsNothing);
  });

  test('switched off, the sample comes back', () {
    final container = ProviderContainer(
      overrides: [realGaitEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    final snapshot = container.read(gaitViewSnapshotProvider(GaitScale.week));
    expect(snapshot.isSample, isTrue);
    expect(snapshot.heroValue, gaitSnapshot(GaitScale.week).heroValue);
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_panel_real_test.dart`
Expected：FAIL，`gaitViewSnapshotProvider` 不存在。

- [ ] **Step 3：加 `gaitViewSnapshotProvider`**

`lib/shared/providers/gait_providers.dart`：加 import

```dart
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/models/gait_real_snapshot.dart';
```

檔尾加：

```dart
/// What the gait tab draws for a scale: the bundled sample while
/// [realGaitEnabledProvider] is off, otherwise the wearer's own history.
final gaitViewSnapshotProvider = Provider.family<GaitSnapshot, GaitScale>((
  ref,
  scale,
) {
  if (!ref.watch(realGaitEnabledProvider)) return gaitSnapshot(scale);
  return realGaitSnapshot(
    scale: scale,
    history: ref.watch(gaitHistoryProvider),
    today: clock.now(),
    fallCount: ref.watch(fallCountSinceOpenProvider),
  );
});
```

- [ ] **Step 4：經典主題頁改成 Consumer**

`lib/shared/pages/analytics_page.dart`：

加 import：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
```

把

```dart
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
```

改成

```dart
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
```

把

```dart
                GaitAnalysisPanel(scale: _scale),
```

改成

```dart
                GaitAnalysisPanel(
                  snapshot: ref.watch(gaitViewSnapshotProvider(_scale)),
                ),
```

類別說明「Only the pressure map is real (live BLE FSR values); the gait figures are mockup copy from [gaitSnapshot].」改成「The pressure map is live BLE FSR data. The gait figures come from [gaitViewSnapshotProvider]: the wearer's own walking once gait tracking is on, the bundled sample until then.」

- [ ] **Step 5：吉祥物主題頁同樣改**

`lib/shared/pages/theme_two/analytics_page_t2.dart`：加 import

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
```

`class AnalyticsPageT2 extends StatefulWidget` → `ConsumerStatefulWidget`；`State<AnalyticsPageT2> createState()` → `ConsumerState<AnalyticsPageT2> createState()`；`class _AnalyticsPageT2State extends State<AnalyticsPageT2>` → `extends ConsumerState<AnalyticsPageT2>`。

把

```dart
                GaitAnalysisPanelT2(scale: _scale),
```

改成

```dart
                GaitAnalysisPanelT2(
                  snapshot: ref.watch(gaitViewSnapshotProvider(_scale)),
                ),
```

類別說明同 Step 4 的改法。

- [ ] **Step 6：跑測試確認通過**

Run: `flutter test test/gait_panel_real_test.dart`
Expected：PASS。

- [ ] **Step 7：跑全部測試＋靜態檢查**

Run: `flutter test && flutter analyze`
Expected：全部 PASS、analyze 沒有 issue。若有其他頁面測試直接 pump `AnalyticsPage` 而沒包 `ProviderScope`，替它包上 `ProviderScope`。

- [ ] **Step 8：Commit**

```bash
git add lib/shared/providers/gait_providers.dart lib/shared/pages/analytics_page.dart lib/shared/pages/theme_two/analytics_page_t2.dart test/gait_panel_real_test.dart
git commit -m "feat(gait): show the wearer's own figures when tracking is on"
```

---

### Task 11：原始資料錄製與重播

**Files:**
- Create: `lib/core/gait/gait_recording.dart`
- Create: `lib/shared/widgets/gait/gait_raw_record_button.dart`
- Create: `tool/gait_replay.dart`
- Modify: `lib/shared/pages/analytics_page.dart`、`lib/shared/pages/theme_two/analytics_page_t2.dart`
- Test: `test/gait_recording_test.dart`

- [ ] **Step 1：寫失敗的測試**

`test/gait_recording_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/gait_recording.dart';
import 'package:silversole/shared/models/foot_side.dart';

import 'helpers/gait_signal.dart';

void main() {
  final origin = DateTime(2026, 11, 2, 9);

  test('a recording replays to the same walk', () {
    final recording = GaitRecording(origin);
    final feed = interleave({
      'R': footSignal(
        origin: origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(count: 20),
      ),
      'L': footSignal(
        origin: origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(
          count: 20,
          first: const Duration(milliseconds: 1550),
        ),
        seed: 2,
      ),
    });
    for (final f in feed) {
      recording.add(
        at: f.sample.t,
        soleKey: f.sole,
        foot: f.sole == 'L' ? FootSide.left : FootSide.right,
        pressure: f.sample.pressure,
        imu: const [0, 0, 0, 0, 0, 0],
      );
    }

    final result = replayGaitRecording(recording.encode());

    expect(result, isNotNull);
    expect(result!.samples, feed.length);
    expect(result.rawContacts, 40);
    expect(result.day.steps, 40);
    expect(result.day.symmetry, isNotNull);
  });

  test('anything else is refused', () {
    expect(replayGaitRecording('not json'), isNull);
    expect(replayGaitRecording('{"format":"something-else"}'), isNull);
  });
}
```

- [ ] **Step 2：跑測試確認失敗**

Run: `flutter test test/gait_recording_test.dart`
Expected：FAIL，`gait_recording.dart` 不存在。

- [ ] **Step 3：寫 `gait_recording.dart`**

`lib/core/gait/gait_recording.dart`：

```dart
import 'dart:convert';

import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_tracker.dart';
import 'package:silversole/shared/models/foot_side.dart';

/// Format tag on files [GaitRecording.encode] writes; [replayGaitRecording]
/// refuses anything without it.
const gaitRecordingFormat = 'silversole-gait-raw';

/// Raw live samples kept for tuning the step detection: unaveraged pressure
/// with the phone time it arrived, plus the IMU axes for later work on
/// walking speed.
class GaitRecording {
  GaitRecording(this.startedAt);

  final DateTime startedAt;
  final _rows = <List<Object?>>[];

  int get length => _rows.length;

  void add({
    required DateTime at,
    required String soleKey,
    required FootSide? foot,
    required List<int> pressure,
    required List<int> imu,
  }) {
    _rows.add([
      at.millisecondsSinceEpoch,
      soleKey,
      foot?.name,
      ...pressure.take(3),
      ...imu,
    ]);
  }

  String encode() => jsonEncode({
    'format': gaitRecordingFormat,
    'version': 1,
    'started_at': startedAt.toIso8601String(),
    'columns': [
      't_ms',
      'sole',
      'foot',
      'p_hallux',
      'p_little_toe',
      'p_heel',
      'ax',
      'ay',
      'az',
      'gx',
      'gy',
      'gz',
    ],
    'samples': _rows,
  });
}

/// What one recording comes to when run through the gait pipeline.
class GaitReplayResult {
  const GaitReplayResult({
    required this.samples,
    required this.rawContacts,
    required this.day,
  });

  final int samples;
  final int rawContacts;

  /// Every day in the recording folded into one.
  final DailyGait day;
}

/// Runs [json] — a file [GaitRecording.encode] wrote — through a fresh
/// [GaitTracker]. Null if it is not such a file.
GaitReplayResult? replayGaitRecording(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded['format'] != gaitRecordingFormat) return null;
  final samples = decoded['samples'];
  if (samples is! List) return null;

  final feet = <String, FootSide?>{};
  final rows = <({DateTime t, String sole, List<int> pressure})>[];
  for (final row in samples) {
    if (row is! List || row.length < 6) continue;
    final t = row[0];
    final sole = row[1];
    final foot = row[2];
    final pressure = row.sublist(3, 6);
    if (t is! int || sole is! String || pressure.any((p) => p is! int)) {
      continue;
    }
    feet[sole] = foot is String ? FootSide.values.asNameMap()[foot] : null;
    rows.add((
      t: DateTime.fromMillisecondsSinceEpoch(t),
      sole: sole,
      pressure: pressure.cast<int>(),
    ));
  }
  rows.sort((a, b) => a.t.compareTo(b.t));

  final tracker = GaitTracker(footOf: (key) => feet[key]);
  for (final r in rows) {
    tracker.add(r.sole, r.t, r.pressure);
  }
  var day = const DailyGait(date: '');
  for (final d in tracker.takePending()) {
    day = day.merge(d);
  }
  return GaitReplayResult(
    samples: rows.length,
    rawContacts: tracker.rawContactCount,
    day: day,
  );
}
```

- [ ] **Step 4：跑測試確認通過**

Run: `flutter test test/gait_recording_test.dart`
Expected：PASS（2 個測試）。

- [ ] **Step 5：錄製按鈕＋放進兩個頁面**

`lib/shared/widgets/gait/gait_raw_record_button.dart`：

```dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/core/gait/gait_recording.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/create_file_and_share.dart';

/// Debug builds only: records raw live samples from every sole and shares
/// them as a file for `tool/gait_replay.dart`.
///
/// Not localized on purpose — release builds never show it (the analytics
/// pages guard it with `kDebugMode`).
class GaitRawRecordButton extends ConsumerStatefulWidget {
  const GaitRawRecordButton({super.key});

  @override
  ConsumerState<GaitRawRecordButton> createState() =>
      _GaitRawRecordButtonState();
}

class _GaitRawRecordButtonState extends ConsumerState<GaitRawRecordButton> {
  GaitRecording? _recording;
  StreamSubscription<SoleSample>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    final recording = GaitRecording(clock.now());
    _sub = ref.read(soleSampleBusProvider).stream.listen((s) {
      final d = s.data;
      recording.add(
        at: clock.now(),
        soleKey: s.identityKey,
        foot: ref
            .read(settingsProvider)
            .pairedDevicesList
            .firstWhereOrNull((p) => p.identityKey == s.identityKey)
            ?.footSide,
        pressure: d.pressure,
        imu: [d.ax, d.ay, d.az, d.gx, d.gy, d.gz],
      );
      // Redraw the sample count about once a second, not on every packet.
      if (recording.length % 50 == 0 && mounted) setState(() {});
    });
    setState(() => _recording = recording);
  }

  Future<void> _stop() async {
    final recording = _recording;
    await _sub?.cancel();
    _sub = null;
    setState(() => _recording = null);
    if (recording == null || recording.length == 0) return;
    final stamp = recording.startedAt.toIso8601String().replaceAll(
      RegExp('[:.]'),
      '-',
    );
    await createFileAndShare(
      fileName: 'gait_raw_$stamp.json',
      content: recording.encode(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recording = _recording;
    return OutlinedButton.icon(
      onPressed: recording == null ? _start : _stop,
      icon: Icon(recording == null ? Icons.fiber_manual_record : Icons.stop),
      label: Text(
        recording == null
            ? 'Record raw gait data (debug)'
            : 'Stop and share · ${recording.length} samples',
      ),
    );
  }
}
```

`lib/shared/pages/analytics_page.dart`：加 import

```dart
import 'package:flutter/foundation.dart';
import 'package:silversole/shared/widgets/gait/gait_raw_record_button.dart';
```

在 `GaitAnalysisPanel(` 那一行之前（gait 分支、刻度選單之後）加：

```dart
                if (kDebugMode) const GaitRawRecordButton(),
```

`lib/shared/pages/theme_two/analytics_page_t2.dart`：同樣加這兩個 import，並在 `GaitAnalysisPanelT2(` 之前加：

```dart
                if (kDebugMode) ...[
                  const GaitRawRecordButton(),
                  const SizedBox(height: 14),
                ],
```

- [ ] **Step 6：寫重播工具**

`tool/gait_replay.dart`：

```dart
import 'dart:io';

import 'package:silversole/core/gait/gait_recording.dart';

/// Prints what each raw gait recording comes to, for tuning `GaitConfig`.
///
///     dart run tool/gait_replay.dart walk100.json sit2min.json
void main(List<String> paths) {
  if (paths.isEmpty) {
    stderr.writeln('usage: dart run tool/gait_replay.dart <recording.json>...');
    exitCode = 64;
    return;
  }
  String pct(double? v) => v == null ? '-' : '${(v * 100).toStringAsFixed(1)}%';
  for (final path in paths) {
    final result = replayGaitRecording(File(path).readAsStringSync());
    if (result == null) {
      stdout.writeln('$path: not a gait recording');
      continue;
    }
    final d = result.day;
    stdout.writeln(
      [
        path,
        'samples=${result.samples}',
        'contacts=${result.rawContacts}',
        'steps=${d.steps}',
        'walking=${(d.walkingMs / 1000).toStringAsFixed(1)}s',
        'cadence=${d.cadence?.toStringAsFixed(1) ?? '-'}',
        'stance=${pct(d.stanceRatio)}',
        'cv=${pct(d.strideCv)}',
        'symmetry=${pct(d.symmetry)}',
        'double_support=${pct(d.doubleSupportRatio)}',
      ].join('  '),
    );
  }
}
```

- [ ] **Step 7：確認工具跑得起來**

先用測試產生一份錄製檔：在 `test/gait_recording_test.dart` 第一個測試的最後暫時加
`File('${Directory.systemTemp.path}/gait_sample.json').writeAsStringSync(recording.encode());`（記得 `import 'dart:io';`），跑一次 `flutter test test/gait_recording_test.dart`，然後：

Run: `dart run tool/gait_replay.dart "$TEMP/gait_sample.json"`（PowerShell 用 `$env:TEMP`）
Expected：一行輸出，`contacts=40  steps=40`。

確認後把那行暫時程式和 `dart:io` import 拿掉。

- [ ] **Step 8：跑全部測試＋靜態檢查**

Run: `flutter test && flutter analyze`
Expected：全部 PASS、沒有 issue。

- [ ] **Step 9：Commit**

```bash
git add lib/core/gait/gait_recording.dart lib/shared/widgets/gait/gait_raw_record_button.dart tool/gait_replay.dart lib/shared/pages/analytics_page.dart lib/shared/pages/theme_two/analytics_page_t2.dart test/gait_recording_test.dart
git commit -m "feat(gait): record raw samples in debug builds and replay them"
```

---

### Task 12：文件收尾

**Files:**
- Modify: `CLAUDE.md`（本 repo）
- Create: `C:/Users/Admin/Desktop/動域科技/02_產品/鞋墊_SilverSole/步態錄製說明.md`（總倉庫，給團隊）

- [ ] **Step 1：`CLAUDE.md` 管線狀態補一條**

在「Pipeline implementation status」清單的 `- **Upload queue — not implemented.**` 那一條之前加：

```markdown
- **Gait — on-device, behind a flag.** `soleSampleBusProvider` (raw, unaveraged) → `gaitTrackingProvider` → `GaitTracker` (`lib/core/gait/`: `StepDetector` → `BoutFilter` → per-day `DailyGait`) → every 5 min and on app pause into `gaitHistoryProvider` (shared_preferences `gait_history`, 90 days) → `gaitViewSnapshotProvider` → both gait panels. On in debug builds; release needs `--dart-define=REAL_GAIT=on`, which stays off until the thresholds in `GaitConfig` are tuned on real recordings (debug "Record raw gait data" button + `dart run tool/gait_replay.dart`). Nothing is uploaded.
```

並把同一段開頭「After `bleForegroundControlProvider` the flow fans out into five branches.」的 five 改成 six。

- [ ] **Step 2：寫團隊錄製說明**

`C:/Users/Admin/Desktop/動域科技/02_產品/鞋墊_SilverSole/步態錄製說明.md`：

```markdown
# 步態錄製說明（給拿著鞋墊的人）

App 會從鞋墊壓力判斷每一步。判斷的門檻要用真人走路的資料來調，所以需要大家幫忙錄幾段。

## 準備

- 手機裝**測試版**（debug build）的 App，正式版沒有錄製按鈕。
- 兩隻鞋墊都連上，並且在「我的裝置」指定好左右腳。只有一隻也可以錄，跟負責的人說一聲。
- 進「分析」頁、切到步態那一頁，選時間範圍的按鈕下面會有「Record raw gait data (debug)」按鈕。

## 每一段怎麼錄

1. 按按鈕開始錄。
2. 照下面的動作做。
3. 再按一次按鈕，會跳出分享，把檔案傳到群組，**檔名後面加上是哪一段**（例如 `走路100步`）。

| 段落 | 動作 | 要記下來的 |
|---|---|---|
| 走路 100 步 | 用平常的速度走，心裡數到 100 步（左右腳各算一步）就停 | 實際走了幾步 |
| 坐 2 分鐘 | 坐在椅子上，可以自然動腳 | 無 |
| 站著換重心 1 分鐘 | 站著不走，左右換重心 | 無 |
| 上下樓梯一趟 | 走一層樓上去再下來 | 上去幾階、下來幾階 |

每個人每段錄一次就好。可以的話找兩三個人錄，年紀不同更好。

## 注意

- 錄製檔只有鞋墊壓力和動作感測的數字，沒有姓名、位置等個資。
- 檔案傳給負責的人就好，不要放到公開的地方。
```

- [ ] **Step 3：Commit（只 commit App repo 的 CLAUDE.md；總倉庫照「我說推你再推」，不 commit）**

```bash
git add CLAUDE.md
git commit -m "docs: note the on-device gait branch in the pipeline status"
```

---

## 完成條件

- [ ] `flutter test` 全部 PASS、`flutter analyze` 沒有 issue
- [ ] debug 版在手機上：步態頁沒有「範例資料」橫幅；沒資料時月、季顯示「資料累積中」；接上鞋墊走一段後 5 分鐘內週頁出現步數
- [ ] release 版不加 `REAL_GAIT` 時，步態頁跟現在一模一樣（範例頁＋橫幅），沒有錄製按鈕
- [ ] 分支 `feat/daily-gait` 只在本地，**沒有推**；推送與開 PR（`--reviewer andongni0723`）等使用者指示
