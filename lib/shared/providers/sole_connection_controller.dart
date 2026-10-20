import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// What a firmware update needs from the auto-connect loop: keep it from
/// swapping soles mid-transfer, and bring the same sole back after it reboots.
abstract interface class SoleConnectionController {
  /// Stops searching and every watchdog until [release], and tears down every
  /// session **except** [identityKey]'s. A manual primary-device pick is
  /// ignored meanwhile.
  ///
  /// Dropping the other foot is deliberate: flutter_blue_plus 2.1.1 runs every
  /// GATT operation behind a single global mutex, so the other sole's
  /// handshake would contend with this transfer's page writes — and a page
  /// write that stalls is exactly what drops the link.
  void hold(String identityKey);

  /// Resumes normal auto-connect.
  void release();

  /// The sole keyed [identityKey]'s DFU link, or null when that sole is not
  /// connected or its firmware has no DFU service.
  DfuLink? dfuLink(String identityKey);

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
  void hold(String identityKey) {}

  @override
  void release() {}

  @override
  DfuLink? dfuLink(String identityKey) => null;

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) async => null;
}
