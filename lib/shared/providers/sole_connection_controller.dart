import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// What a firmware update needs from the auto-connect loop: keep it from
/// swapping soles mid-transfer, and bring the same sole back after it reboots.
abstract interface class SoleConnectionController {
  /// Stops searching and the watchdog until [release]; a manual primary-device
  /// pick is ignored meanwhile.
  void hold();

  /// Resumes normal auto-connect.
  void release();

  /// The connected sole's DFU link, or null when none is connected or its
  /// firmware has no DFU service.
  DfuLink? dfuLink();

  /// Finds [target] again after it rebooted, connects with the app's usual
  /// handlers and returns the new session — or null after [timeout].
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  });
}

@immutable
class ReacquiredSole {
  const ReacquiredSole(this.session, this.confidence);

  final SoleSessionInfo session;
  final ReacquireConfidence confidence;
}

/// Where the BLE pipeline does not run (anything but Android).
class NoSoleConnection implements SoleConnectionController {
  const NoSoleConnection();

  @override
  void hold() {}

  @override
  void release() {}

  @override
  DfuLink? dfuLink() => null;

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) async => null;
}
