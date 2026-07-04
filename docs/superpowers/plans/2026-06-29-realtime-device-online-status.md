# Real-time Device Online Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the device status card flip online → offline on its own, exactly when telemetry has been silent for the online window, without a manual page switch.

**Architecture:** The online/offline boolean depends on two inputs — `last telemetry timestamp` (reactive, 20 Hz) and `now` (NOT reactive). Riverpod only rebuilds on data changes, so the "telemetry went silent" transition never fires. We introduce a `deviceOnlineProvider` (`Notifier<bool>`) that (a) reacts to telemetry timestamp changes via `ref.listen`, and (b) owns a one-shot `Timer` that flips the state to `false` precisely at `lastTimestamp + onlineWindow`. The widget becomes a pure `ref.watch(deviceOnlineProvider)` consumer; the per-widget timer added earlier is removed. All time reads go through `package:clock` so the logic is deterministically testable under `fakeAsync`.

**Tech Stack:** Flutter, Riverpod v3 (`Notifier`/`NotifierProvider`), `package:clock`, `package:fake_async` (tests).

## Global Constraints

- State management is **Riverpod v3**; expose logic via a `Notifier`, consume via `ref.watch`. (verbatim project rule)
- **No behavior change in production**: `clock.now()` equals `DateTime.now()` under the default clock. The clock swap only enables deterministic tests.
- **Online window is a single source of truth**: `TelemetryFacade.onlineWindow = Duration(seconds: 35)`. Never re-hardcode `35`.
- **Single-device scope**: `deviceOnlineProvider` derives from the one `liveTelemetryProvider` stream (the preferred device). Multi-device per-card status is out of scope.
- Access theme through `context` getters (not relevant to these files, but the project rule stands).
- No freezed/json model is edited here, so **`build_runner` is NOT required**.

---

### Task 1: Make `checkDeviceOnline` clock-driven and testable

Switch the online check from `DateTime.now()` to `clock.now()` so the window logic is unit-testable with a pinned clock. Add the `clock` dependency (needed in `lib/`) and `fake_async` (tests).

**Files:**

- Modify: `pubspec.yaml` (add `clock` to `dependencies`, `fake_async` to `dev_dependencies`)
- Modify: `lib/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart`
- Test: `test/telemetry_facade_test.dart`

**Interfaces:**

- Consumes: nothing.
- Produces: `TelemetryFacade.onlineWindow` (`static const Duration`, already exists), `TelemetryFacade.checkDeviceOnline(DateTime? time) -> bool` (now reads `clock.now()`).

- [ ] **Step 1: Add dependencies**

In `pubspec.yaml`, under `dependencies:` add:

```yaml
clock: ^1.1.1
```

Under `dev_dependencies:` add:

```yaml
fake_async: ^1.3.1
```

- [ ] **Step 2: Install**

Run: `flutter pub get`
Expected: resolves with `clock` and `fake_async` added, exit code 0.

- [ ] **Step 3: Write the failing test**

Create `test/telemetry_facade_test.dart`:

```dart
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

void main() {
  final facade = TelemetryFacade();
  final base = DateTime(2030, 1, 1, 12, 0, 0);

  test('null timestamp is offline', () {
    expect(facade.checkDeviceOnline(null), isFalse);
  });

  test('within the online window is online', () {
    withClock(Clock.fixed(base), () {
      final fresh = base.subtract(TelemetryFacade.onlineWindow ~/ 2);
      expect(facade.checkDeviceOnline(fresh), isTrue);
    });
  });

  test('past the online window is offline', () {
    withClock(Clock.fixed(base), () {
      final stale = base.subtract(
        TelemetryFacade.onlineWindow + const Duration(seconds: 1),
      );
      expect(facade.checkDeviceOnline(stale), isFalse);
    });
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/telemetry_facade_test.dart`
Expected: FAIL on "within the online window is online" — with `DateTime.now()` the difference is ~4 years, so it returns false instead of true.

- [ ] **Step 5: Switch the facade to `clock.now()`**

Replace the body of `lib/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart` with:

```dart
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TelemetryFacade {
  /// A device counts as "online" while live telemetry keeps arriving within
  /// this window; once it elapses with no new data, it flips to offline.
  static const onlineWindow = Duration(seconds: 35);

  bool checkDeviceOnline(DateTime? time) {
    if (time == null) return false;
    return clock.now().difference(time) < onlineWindow;
  }
}

final telemetryFacadeProvider = Provider<TelemetryFacade>((_) => TelemetryFacade());
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/telemetry_facade_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart test/telemetry_facade_test.dart
git commit -m "refactor(telemetry): make online check clock-driven for testability

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Add `deviceOnlineProvider` (reactive + one-shot timer)

Create the notifier that turns "telemetry went silent for `onlineWindow`" into a state change. Make live telemetry timestamps use `clock.now()` so the notifier is deterministic under `fakeAsync`.

**Files:**

- Modify: `lib/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart` (timestamps → `clock.now()`)
- Create: `lib/shared/providers/telemetry_process_providers/device_online_provider.dart`
- Test: `test/device_online_provider_test.dart`

**Interfaces:**

- Consumes: `liveTelemetryProvider` (`NotifierProvider<LiveTelemetryNotifier, LiveTelemetryState>`), `LiveTelemetryState.updatedAt` (`DateTime?`), `TelemetryFacade.checkDeviceOnline`, `TelemetryFacade.onlineWindow`, `LiveTelemetryNotifier.updateImuNotifyData(ImuNotifyDataModel)`.
- Produces: `deviceOnlineProvider` (`NotifierProvider<DeviceOnlineNotifier, bool>`) — `true` while telemetry is fresh, auto-flips to `false` `onlineWindow` after the last sample.

- [ ] **Step 1: Make live telemetry timestamps clock-driven**

In `lib/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart`, add the import at the top:

```dart
import 'package:clock/clock.dart';
```

Then replace the two `updatedAt: DateTime.now()` occurrences (in `updateImuNotifyData` and `updateRecordImuNotifyData`) with:

```dart
      updatedAt: clock.now(),
```

- [ ] **Step 2: Write the failing test**

Create `test/device_online_provider_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

ImuNotifyDataModel _sample() => const ImuNotifyDataModel(
      ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0,
      pressure: [0, 0, 0], batteryPercent: 100, isCharging: false,
    );

void main() {
  test('offline with no telemetry, online on data, auto-offline after window', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // build() runs and registers the telemetry listener.
      expect(container.read(deviceOnlineProvider), isFalse);

      final live = container.read(liveTelemetryProvider.notifier);

      live.updateImuNotifyData(_sample());
      async.flushMicrotasks();
      expect(container.read(deviceOnlineProvider), isTrue);

      async.elapse(TelemetryFacade.onlineWindow - const Duration(seconds: 1));
      expect(container.read(deviceOnlineProvider), isTrue);

      async.elapse(const Duration(seconds: 2)); // now past the window
      expect(container.read(deviceOnlineProvider), isFalse);

      // Fresh telemetry brings it back online immediately.
      live.updateImuNotifyData(_sample());
      async.flushMicrotasks();
      expect(container.read(deviceOnlineProvider), isTrue);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/device_online_provider_test.dart`
Expected: FAIL to compile — `deviceOnlineProvider` is not defined.

- [ ] **Step 4: Create the provider**

Create `lib/shared/providers/telemetry_process_providers/device_online_provider.dart`:

```dart
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_telemetry_notifier.dart';
import 'telemetry_facade_provider.dart';

/// Whether the device is currently "online" — i.e. live telemetry arrived
/// within [TelemetryFacade.onlineWindow].
///
/// Online/offline depends on `now`, which is not a reactive value, so a pure
/// `ref.watch` would never flip to offline once telemetry stops (the missing
/// data is the signal, and silence emits no event). This notifier reacts to
/// telemetry timestamp changes AND owns a one-shot timer that flips the state
/// to `false` exactly at `lastTimestamp + onlineWindow`.
class DeviceOnlineNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(
      liveTelemetryProvider.select((s) => s.updatedAt),
      (_, next) => _reschedule(next),
    );
    final updatedAt = ref.read(liveTelemetryProvider).updatedAt;
    _arm(updatedAt); // build() must not write `state`; only schedule the timer.
    return ref.read(telemetryFacadeProvider).checkDeviceOnline(updatedAt);
  }

  void _reschedule(DateTime? updatedAt) {
    state = ref.read(telemetryFacadeProvider).checkDeviceOnline(updatedAt);
    _arm(updatedAt);
  }

  /// Schedules the exact moment the device falls outside the online window.
  void _arm(DateTime? updatedAt) {
    _timer?.cancel();
    if (updatedAt == null) return;
    final remaining =
        TelemetryFacade.onlineWindow - clock.now().difference(updatedAt);
    if (remaining <= Duration.zero) return; // already stale
    _timer = Timer(remaining, () => state = false);
  }
}

final deviceOnlineProvider =
    NotifierProvider<DeviceOnlineNotifier, bool>(DeviceOnlineNotifier.new);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/device_online_provider_test.dart`
Expected: PASS.

> If the post-`updateImuNotifyData` assertion reads stale, replace `async.flushMicrotasks();` with `async.elapse(Duration.zero);` — both drain the Riverpod listener notification under `fakeAsync`.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart lib/shared/providers/telemetry_process_providers/device_online_provider.dart test/device_online_provider_test.dart
git commit -m "feat(telemetry): add deviceOnlineProvider with auto-offline timer

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Wire the card to the provider and remove the per-widget timer

Replace the imperative timer in `DeviceStatusCard` with a single `ref.watch(deviceOnlineProvider)`. The online logic now lives entirely in the provider (covered by Task 2's test).

**Files:**

- Modify: `lib/shared/widgets/device_status_card.dart`

**Interfaces:**

- Consumes: `deviceOnlineProvider` (from Task 2).
- Produces: nothing new.

- [ ] **Step 1: Replace the widget body**

Rewrite `lib/shared/widgets/device_status_card.dart` so the state class drops `dart:async`, the `_offlineTimer`/`_armOfflineTimer`/`didUpdateWidget`, and the `telemetry_facade_provider` import; and `build` watches the provider. Final file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import 'status_card.dart';

class DeviceStatusCard extends ConsumerStatefulWidget {
  final StatusCardType type;
  final String name;
  final String model;
  final String id;
  final bool activeDisplay;
  final bool frosted;
  final DeviceStatusDetailModel? detail;
  final DateTime? lastConnectedAt;
  final List<ListTileData> menuItems;
  final VoidCallback? onClick;

  const DeviceStatusCard({
    super.key,
    this.type = StatusCardType.normal,
    required this.name,
    required this.model,
    required this.id,
    required this.activeDisplay,
    this.frosted = false,
    this.detail,
    this.lastConnectedAt,
    this.menuItems = const <ListTileData>[],
    this.onClick,
  });

  @override
  ConsumerState<DeviceStatusCard> createState() => _DeviceStatusCard();
}

class _DeviceStatusCard extends ConsumerState<DeviceStatusCard> {
  ProviderSubscription<AppSettings>? _sub;
  bool _load = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<AppSettings>(settingsProvider, (prev, next) {
      final deviceId = next.deviceId;
      if (!_load && deviceId != null && deviceId.isNotEmpty) {
        _load = true;
        // refreshDeviceStatus(deviceId);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    super.dispose();
    _sub?.close();
  }

  Future<void> openDeviceStatusPage() async {
    //TODO: this is test feature now
    // context.push('/device-stat us');
    // debugPrint('click device card');
  }

  @override
  Widget build(BuildContext context) {
    return statusCard(
      context,
      type: widget.type,
      title: widget.name,
      model: widget.model,
      id: widget.id,
      icon: LucideIcons.footprints,
      menuItems: widget.menuItems,
      active: ref.watch(deviceOnlineProvider),
      addition: true,
      frosted: widget.frosted,
      detail: widget.detail,
      lastConnectedAt: widget.lastConnectedAt,
      onTap: widget.onClick ?? () {},
    );
  }
}
```

- [ ] **Step 2: Static-analyze the change**

Run: `flutter analyze lib/shared/widgets/device_status_card.dart`
Expected: "No issues found!" (no unused `dart:async`/facade imports, no undefined `deviceOnlineProvider`).

- [ ] **Step 3: Full test + analyze gate**

Run: `flutter test && flutter analyze`
Expected: all tests PASS (incl. Task 1 & 2 suites), analyze clean. The online→offline behavior is covered by `test/device_online_provider_test.dart`; this task is a pure wiring/refactor of that verified logic.

- [ ] **Step 4: Commit**

```bash
git add lib/shared/widgets/device_status_card.dart
git commit -m "refactor(home): drive device status card online state from deviceOnlineProvider

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual Verification (after Task 3)

1. `flutter run` on Android with a paired device streaming telemetry → card shows **online**.
2. Power off / disconnect the sole. **Without touching the app**, after ~35 s the card flips to **offline** on its own (no page switch).
3. Reconnect → card returns to **online** within one telemetry sample (~50 ms).

## Notes / Known Limitations

- `deviceOnlineProvider` is a single global derived from `liveTelemetryProvider` (one preferred device). If the app later shows multiple live devices simultaneously, convert it to a `NotifierProvider.family` keyed by `remoteId`.
- This plan does not make the "last connected: X ago" relative _text_ tick live — only the online/offline state. That text refreshes on the next rebuild (e.g. when the offline flip fires). A live-ticking relative label is a separate change.
