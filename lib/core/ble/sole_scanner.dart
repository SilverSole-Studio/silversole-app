import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// The substring every sole carries in its advertised name.
///
/// Every sole advertises the same name, so this only says "a sole"; which sole
/// it is comes from its device ID ([soleDeviceIdFrom]).
const soleNameKeyword = 'silversole';

bool isSoleName(String name) => name.toLowerCase().contains(soleNameKeyword);

/// The company code in front of the device ID in the sole's Manufacturer
/// Specific Data. `0xFFFF` is the Bluetooth SIG's test value and the firmware
/// replaces it before production — this is the one place to change it.
const soleManufacturerId = 0xFFFF;

/// The sole's chip ID from its advertisement: the 8 bytes after
/// [soleManufacturerId], big-endian, as 16 uppercase hex characters — the same
/// string the Device Information Service's Serial Number returns.
///
/// Null for firmware from before the ID existed.
String? soleDeviceIdFrom(Map<int, List<int>> manufacturerData) {
  final bytes = manufacturerData[soleManufacturerId];
  if (bytes == null || bytes.length != 8) return null;
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}

/// One sole seen in a scan.
@immutable
class SoleCandidate {
  const SoleCandidate({
    required this.remoteId,
    required this.name,
    required this.rssi,
    this.deviceId,
  });

  factory SoleCandidate.fromScanResult(ScanResult r) => SoleCandidate(
    remoteId: r.device.remoteId.str,
    name: scanResultName(r),
    rssi: r.rssi,
    deviceId: soleDeviceIdFrom(r.advertisementData.manufacturerData),
  );

  final String remoteId;
  final String name;
  final int rssi;

  /// The chip ID it advertised; null on firmware too old to report one.
  final String? deviceId;

  @override
  String toString() =>
      'SoleCandidate($name ${deviceId ?? '-'} $remoteId ${rssi}dBm)';
}

/// The advertised name, falling back to the platform's cached one.
String scanResultName(ScanResult r) => r.advertisementData.advName.isNotEmpty
    ? r.advertisementData.advName
    : r.device.platformName;

/// Whether [candidate] is the sole recorded as [paired]: by chip ID when both
/// have one, otherwise by address — the only handle on old firmware.
bool isSameSole(SoleCandidate candidate, BlePairedDevice paired) {
  final id = candidate.deviceId;
  final pairedId = paired.deviceId;
  if (id != null && pairedId != null) return id == pairedId;
  return candidate.remoteId == paired.remoteId;
}

/// Picks which sole to connect to, in this order:
///
/// 1. the primary device, when it is on the air;
/// 2. any other paired sole, strongest signal first;
/// 3. as a last resort, a sole that cannot be identified — one advertising no
///    ID, or any sole while some entry in [paired] still has no ID on record
///    (a sole paired on old firmware looks like a stranger once it reports an
///    ID, and this is how auto-connect finds it again).
///
/// Otherwise nothing: a sole that reports an ID nobody paired is someone
/// else's, and auto-connect leaves it alone.
SoleCandidate? pickSole(
  List<SoleCandidate> candidates, {
  required List<BlePairedDevice> paired,
}) {
  SoleCandidate? strongest(Iterable<SoleCandidate> pool) =>
      pool.sorted((a, b) => b.rssi.compareTo(a.rssi)).firstOrNull;

  final primary = paired.firstWhereOrNull((d) => d.isPreferred);
  if (primary != null) {
    final found = candidates.firstWhereOrNull((c) => isSameSole(c, primary));
    if (found != null) return found;
  }

  final known = strongest(
    candidates.where((c) => paired.any((d) => isSameSole(c, d))),
  );
  if (known != null) return known;

  final hasLegacyEntry = paired.any((d) => d.deviceId == null);
  return strongest(
    candidates.where((c) => c.deviceId == null || hasLegacyEntry),
  );
}

/// Finds the soles that are advertising right now.
class SoleScanner {
  static const defaultWindow = Duration(seconds: 5);

  /// Scans for [window] and returns every sole seen, keyed by remoteId so a
  /// device advertising repeatedly is reported once with its latest RSSI.
  ///
  /// The scan is deliberately unfiltered at the platform level and matched by
  /// name in Dart, exactly like the pairing sheet — that is the path known to
  /// work with this firmware.
  Future<List<SoleCandidate>> scan({Duration window = defaultWindow}) async {
    final found = <String, SoleCandidate>{};
    StreamSubscription<List<ScanResult>>? sub;
    try {
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (!isSoleName(scanResultName(r))) continue;
          found[r.device.remoteId.str] = SoleCandidate.fromScanResult(r);
        }
      });

      if (FlutterBluePlus.isScanningNow) {
        // The pairing sheet owns this scan; watch its results instead of
        // restarting it (Android allows only 5 startScan calls per 30 s).
        await Future<void>.delayed(window);
      } else {
        await FlutterBluePlus.startScan(
          androidScanMode: AndroidScanMode.lowLatency,
          timeout: window,
        );
        await FlutterBluePlus.isScanning
            .where((scanning) => !scanning)
            .first
            .timeout(window + const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('sole scan failed: $e');
    } finally {
      await sub?.cancel();
    }
    return found.values.toList();
  }

  /// Scans until a sole matching [stopWhen] shows up or [timeout] passes, and
  /// returns every sole seen meanwhile.
  ///
  /// One continuous scan rather than repeated [scan] windows: Android refuses
  /// a sixth startScan within 30 s. Results stamped before this call are
  /// ignored, so a sole seen before it — one about to reboot into new
  /// firmware — is not taken as being on the air now. (onScanResults alone
  /// does not guarantee this when another scan is already running.)
  Future<List<SoleCandidate>> watch({
    required Duration timeout,
    required bool Function(SoleCandidate sole) stopWhen,
  }) async {
    if (timeout <= Duration.zero) return const [];
    final since = DateTime.now();
    final found = <String, SoleCandidate>{};
    final matched = Completer<void>();
    StreamSubscription<List<ScanResult>>? sub;
    var startedHere = false;
    try {
      sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (r.timeStamp.isBefore(since)) continue;
          if (!isSoleName(scanResultName(r))) continue;
          final sole = SoleCandidate.fromScanResult(r);
          found[sole.remoteId] = sole;
          if (stopWhen(sole) && !matched.isCompleted) matched.complete();
        }
      });
      if (!FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.startScan(
          androidScanMode: AndroidScanMode.lowLatency,
          timeout: timeout,
        );
        startedHere = true;
      }
      await matched.future.timeout(timeout, onTimeout: () {});
    } catch (e) {
      debugPrint('sole watch failed: $e');
    } finally {
      await sub?.cancel();
      if (startedHere && FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    }
    return found.values.toList();
  }
}
