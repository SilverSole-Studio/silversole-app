import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/providers/firmware_update_provider.dart';

import 'live_telemetry_notifier.dart';
import 'telemetry_facade_provider.dart';

/// Whether **any** sole is currently "online" — i.e. live telemetry arrived
/// from one of them within [TelemetryFacade.onlineWindow]. With two feet the
/// wearable is online while either one is reporting; a per-foot answer comes
/// from `footTelemetryProvider`.
///
/// Online/offline depends on `now`, which is not a reactive value, so a pure
/// `ref.watch` would never flip to offline once telemetry stops (the missing
/// data is the signal, and silence emits no event). This notifier reacts to
/// telemetry timestamp changes AND owns a one-shot timer that flips the state
/// to `false` exactly at `lastTimestamp + onlineWindow`.
class DeviceOnlineNotifier extends Notifier<bool> {
  Timer? _timer;

  /// A sole being updated pauses its 50 Hz stream and then reboots; it is
  /// busy, not gone, so it stays online until the update has an outcome.
  var _updating = false;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _updating = ref.watch(firmwareUpdateProvider.select((s) => s.busy));
    ref.listen(latestTelemetryAtProvider, (_, next) => _reschedule(next));
    final updatedAt = ref.read(latestTelemetryAtProvider);
    _arm(updatedAt); // build() must not write `state`; only schedule the timer.
    return _updating ||
        ref.read(telemetryFacadeProvider).checkDeviceOnline(updatedAt);
  }

  void _reschedule(DateTime? updatedAt) {
    state =
        _updating ||
        ref.read(telemetryFacadeProvider).checkDeviceOnline(updatedAt);
    _arm(updatedAt);
  }

  /// Schedules the exact moment the device falls outside the online window.
  void _arm(DateTime? updatedAt) {
    _timer?.cancel();
    if (updatedAt == null) return;
    final remaining =
        TelemetryFacade.onlineWindow - clock.now().difference(updatedAt);
    if (remaining <= Duration.zero) return; // already stale
    _timer = Timer(remaining, () => state = _updating);
  }
}

final deviceOnlineProvider = NotifierProvider<DeviceOnlineNotifier, bool>(
  DeviceOnlineNotifier.new,
);
