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
