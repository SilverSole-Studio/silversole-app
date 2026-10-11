import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/firmware_version.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

enum FirmwareCheckStatus {
  notConnected,
  needsWiredUpdate,
  versionUnreadable,
  checkFailed,
  manifestUnsupported,
  upToDate,
  updateAvailable,
  downgradeAvailable,
}

/// Whether the connected sole has firmware to install, and which.
@immutable
class FirmwareCheck {
  const FirmwareCheck(this.status, {this.sole, this.manifest});

  final FirmwareCheckStatus status;
  final ConnectedSole? sole;

  /// The release on offer — set for updateAvailable and downgradeAvailable.
  final FirmwareManifest? manifest;
}

/// The verdicts that need no server: no sole, no DFU service, or a version
/// that cannot be compared. Null when the server should be asked.
FirmwareCheck? firmwarePrecheck(ConnectedSole? sole) {
  if (sole == null) {
    return const FirmwareCheck(FirmwareCheckStatus.notConnected);
  }
  if (!sole.dfuSupported) {
    return FirmwareCheck(FirmwareCheckStatus.needsWiredUpdate, sole: sole);
  }
  if (parseFirmwareVersion(sole.firmwareVersion) == null) {
    debugPrint('sole firmware version is not semver: ${sole.firmwareVersion}');
    return FirmwareCheck(FirmwareCheckStatus.versionUnreadable, sole: sole);
  }
  return null;
}

/// Compares the sole with the channel's manifest. The sole does not refuse
/// older firmware, so the app must never offer it — except to a developer who
/// turned developer mode on.
FirmwareCheck evaluateManifest(
  ConnectedSole sole,
  Result<FirmwareManifest> fetched, {
  required bool devMode,
}) {
  if (fetched case Error(:final error)) {
    debugPrint('firmware manifest unavailable: $error');
    return FirmwareCheck(FirmwareCheckStatus.checkFailed, sole: sole);
  }
  final manifest = (fetched as Ok<FirmwareManifest>).value;
  if (manifest.schema != firmwareManifestSchema) {
    debugPrint('firmware manifest schema ${manifest.schema} is not understood');
    return FirmwareCheck(FirmwareCheckStatus.manifestUnsupported, sole: sole);
  }
  return switch (compareFirmware(sole.firmwareVersion, manifest.version)) {
    FirmwareComparison.upgrade => FirmwareCheck(
      FirmwareCheckStatus.updateAvailable,
      sole: sole,
      manifest: manifest,
    ),
    FirmwareComparison.downgrade when devMode => FirmwareCheck(
      FirmwareCheckStatus.downgradeAvailable,
      sole: sole,
      manifest: manifest,
    ),
    FirmwareComparison.downgrade || FirmwareComparison.same => FirmwareCheck(
      FirmwareCheckStatus.upToDate,
      sole: sole,
    ),
    // The sole's version passed the precheck, so it is the server's that is
    // not semver.
    null => FirmwareCheck(FirmwareCheckStatus.manifestUnsupported, sole: sole),
  };
}

final firmwareReleaseServiceProvider = Provider<FirmwareReleaseService>(
  (_) => FirmwareReleaseService(),
);

/// Re-checked on every handshake (the connected sole changes) and whenever
/// developer mode switches channel; the devices page's firmware card shows it.
final firmwareCheckProvider = FutureProvider<FirmwareCheck>((ref) async {
  final sole = ref.watch(connectedSoleProvider);
  final devMode = ref.watch(settingsProvider.select((s) => s.firmwareDevMode));
  final early = firmwarePrecheck(sole);
  if (early != null) return early;
  final fetched = await ref
      .read(firmwareReleaseServiceProvider)
      .fetchManifest(devMode ? FirmwareChannel.beta : FirmwareChannel.stable);
  return evaluateManifest(sole!, fetched, devMode: devMode);
});
