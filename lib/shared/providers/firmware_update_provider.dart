import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_transfer.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/core/utils/firmware_version.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/sole_connection_controller.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Below this the sole refuses an update (LOW_BATTERY), so the app refuses
/// first.
const otaMinBatteryPercent = 30;

/// How long a rebooting sole gets to come back on its new firmware.
const otaReacquireTimeout = Duration(seconds: 90);

/// Measured throughput at MTU 247 (the handoff's §4), for the estimate shown
/// before an update.
const otaBytesPerSecond = 7 * 1024;

/// Keeps the screen on while an update runs, so the phone does not doze off
/// in the middle of the transfer.
final keepScreenOnProvider = Provider<Future<void> Function(bool on)>(
  (_) =>
      (on) => WakelockPlus.toggle(enable: on),
);

/// One firmware update, from download to verdict (the OTA spec's §2.4).
class FirmwareUpdateNotifier extends Notifier<OtaState> {
  DfuTransfer? _transfer;
  var _cancelRequested = false;

  @override
  OtaState build() => const OtaState();

  /// Downloads [manifest]'s image, checks it and installs it.
  Future<void> installRelease(FirmwareManifest manifest) async {
    if (state.busy) return;
    final sole = ref.read(connectedSoleProvider);
    if (_refused(sole)) return;
    final fromVersion = sole!.firmwareVersion;
    // The sole does not refuse older firmware itself, so the app must never
    // offer it outside developer mode (the handoff's §6.2).
    final devMode = ref.read(settingsProvider).firmwareDevMode;
    if (!devMode &&
        compareFirmware(fromVersion, manifest.version) !=
            FirmwareComparison.upgrade) {
      state = OtaState(
        phase: OtaPhase.failed,
        failure: DfuFailure.notNewer,
        fromVersion: fromVersion,
      );
      return;
    }
    _cancelRequested = false;
    state = OtaState(
      phase: OtaPhase.downloading,
      fromVersion: fromVersion,
      toVersion: manifest.version,
    );
    final downloaded = await ref
        .read(firmwareReleaseServiceProvider)
        .download(manifest);
    if (_cancelRequested) {
      _fail(DfuFailure.cancelled);
      return;
    }
    switch (downloaded) {
      case Error(:final error):
        _failWith(error);
      case Ok(:final value):
        await _install(sole, value);
    }
  }

  /// Installs a developer's own image (debug builds only).
  Future<void> installLocal(FirmwareImage image) async {
    if (state.busy) return;
    final sole = ref.read(connectedSoleProvider);
    if (_refused(sole)) return;
    _cancelRequested = false;
    state = OtaState(
      phase: OtaPhase.transferring,
      fromVersion: sole!.firmwareVersion,
      size: image.bin.length,
    );
    await _install(sole, image);
  }

  /// Stops a download or transfer. The sole keeps its old firmware.
  Future<void> cancel() async {
    _cancelRequested = true;
    await _transfer?.cancel();
  }

  /// Back to the confirmation, once the last update has an outcome.
  void reset() {
    if (!state.busy) state = const OtaState();
  }

  bool _refused(ConnectedSole? sole) {
    final failure = _preflight(sole);
    if (failure == null) return false;
    state = OtaState(
      phase: OtaPhase.failed,
      failure: failure,
      fromVersion: sole?.firmwareVersion,
    );
    return true;
  }

  DfuFailure? _preflight(ConnectedSole? sole) {
    if (sole == null) return DfuFailure.notConnected;
    if (!sole.dfuSupported) return DfuFailure.dfuUnsupported;
    // 255 (unknown) is let through: the sole checks its own battery on START.
    // This sole's own battery, not whichever foot happens to be primary.
    final battery = ref
        .read(liveTelemetryProvider(sole.device.identityKey))
        .recentImu
        .lastOrNull
        ?.batteryPercent
        .validBatteryPercent;
    if (battery != null && battery < otaMinBatteryPercent) {
      return DfuFailure.lowBattery;
    }
    return null;
  }

  Future<void> _install(ConnectedSole sole, FirmwareImage image) async {
    final connection = ref.read(bleForegroundControlProvider);
    final link = connection.dfuLink(sole.device.identityKey);
    if (link == null) {
      _fail(DfuFailure.notConnected);
      return;
    }
    // attach()'s own detach() cancels the old session's listener before the
    // new link comes up, so a forced swap (a manual primary-device pick
    // while another sole is connected) can leave connectedSoleProvider on
    // the old sole while dfuLink() above already answers for the new one.
    // Never write into a sole we did not confirm is still the one we started
    // with.
    final current = ref.read(connectedSoleProvider);
    if (current == null ||
        current.device.identityKey != sole.device.identityKey) {
      _fail(DfuFailure.notConnected);
      return;
    }
    final keepScreenOn = ref.read(keepScreenOnProvider);
    connection.hold(sole.device.identityKey);
    await _quietly(() => keepScreenOn(true));
    try {
      if (_cancelRequested) {
        _fail(DfuFailure.cancelled);
        return;
      }
      final size = image.bin.length;
      state = state.copyWith(
        phase: OtaPhase.transferring,
        committed: 0,
        size: size,
      );
      final transfer = DfuTransfer(link);
      _transfer = transfer;
      final result = await transfer.run(
        image: image.bin,
        sha256: image.sha256,
        signature: image.signature,
        onProgress: (committed, total) => state = state.copyWith(
          committed: committed,
          phase: committed == total
              ? OtaPhase.verifying
              : OtaPhase.transferring,
        ),
      );
      _transfer = null;
      if (result case Error(:final error)) {
        final failure = error is DfuException
            ? error.failure
            : DfuFailure.disconnected;
        // Once APPLY is out the sole may have installed the image even though
        // its answer was lost; only the version it boots with can tell.
        final mayHaveApplied =
            transfer.applySent &&
            (failure == DfuFailure.disconnected ||
                failure == DfuFailure.timeout);
        if (!mayHaveApplied) {
          _failWith(error);
          return;
        }
      }
      state = state.copyWith(phase: OtaPhase.rebooting);
      final back = await connection.reacquire(
        sole.device,
        timeout: otaReacquireTimeout,
      );
      state = _verdict(back, expected: image.version);
    } catch (e) {
      // Anything that escapes the transfer itself (e.g. subscribeStatus()
      // throwing when the link drops before DfuTransfer's own try starts)
      // must not leave the update stuck in a busy phase forever.
      debugPrint('ota: _install failed: $e');
      _transfer = null;
      _fail(DfuFailure.disconnected);
    } finally {
      _transfer = null;
      connection.release();
      await _quietly(() => keepScreenOn(false));
    }
  }

  OtaState _verdict(ReacquiredSole? back, {required String? expected}) {
    final read = back?.session.firmwareVersion;
    if (back == null || read == null) {
      return state.copyWith(phase: OtaPhase.unconfirmed);
    }
    final next = state.copyWith(
      readVersion: read,
      probable: back.confidence == ReacquireConfidence.probable,
    );
    if (expected == null) return next.copyWith(phase: OtaPhase.localFinished);
    if (compareFirmware(read, expected) == FirmwareComparison.same) {
      return next.copyWith(phase: OtaPhase.succeeded);
    }
    if (compareFirmware(read, state.fromVersion) == FirmwareComparison.same) {
      return next.copyWith(phase: OtaPhase.notUpdated);
    }
    return next.copyWith(phase: OtaPhase.unconfirmed);
  }

  void _fail(DfuFailure failure) =>
      state = state.copyWith(phase: OtaPhase.failed, failure: failure);

  void _failWith(Exception error) {
    debugPrint('ota failed: $error');
    _fail(error is DfuException ? error.failure : DfuFailure.disconnected);
  }

  /// Screen-on is a nicety: its failure must not fail the update.
  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('ota: keep screen on failed: $e');
    }
  }
}

final firmwareUpdateProvider =
    NotifierProvider<FirmwareUpdateNotifier, OtaState>(
      FirmwareUpdateNotifier.new,
    );
