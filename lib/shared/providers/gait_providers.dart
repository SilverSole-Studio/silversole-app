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
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/models/gait_real_snapshot.dart';
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
    var saved = const <String, DailyGait>{};
    try {
      saved = decodeGaitHistory(
        await loadLocalValue(LocalSavableKey.gaitHistory),
      );
    } catch (_) {
      // Unreadable storage: start empty rather than fail every later add.
    }
    if (!ref.mounted) return;
    state = mergeGaitHistory(saved, const [], clock.now());
  }

  /// Adds [deltas] and saves. Waits for the stored history first, so an
  /// early flush can never overwrite it.
  Future<void> add(List<DailyGait> deltas) async {
    await _loading;
    if (!ref.mounted || deltas.isEmpty) return;
    state = mergeGaitHistory(state, deltas, clock.now());
    await saveLocalValue(LocalSavableKey.gaitHistory, encodeGaitHistory(state));
  }
}

final gaitHistoryProvider =
    NotifierProvider<GaitHistoryNotifier, Map<String, DailyGait>>(
      GaitHistoryNotifier.new,
    );

/// Feeds every raw sample on the bus to a [GaitTracker] and flushes its
/// totals into [gaitHistoryProvider] every [gaitFlushInterval], when the app
/// goes to the background, and on dispose. The flush on dispose is best
/// effort: by then the history notifier may be gone too, and the pending
/// totals are lost.
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

/// What the gait tab draws for a scale: the bundled sample while
/// [realGaitEnabledProvider] is off, otherwise the wearer's own history.
///
/// Disposed once the gait tab is left, so coming back re-reads the clock and
/// a tab left open past midnight starts the new day.
final gaitViewSnapshotProvider = Provider.autoDispose
    .family<GaitSnapshot, GaitScale>((ref, scale) {
      if (!ref.watch(realGaitEnabledProvider)) return gaitSnapshot(scale);
      return realGaitSnapshot(
        scale: scale,
        history: ref.watch(gaitHistoryProvider),
        today: clock.now(),
        fallCount: ref.watch(fallCountSinceOpenProvider),
      );
    });
