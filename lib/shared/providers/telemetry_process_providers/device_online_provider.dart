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
