import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// The substring every sole carries in its advertised name.
///
/// This is the only stable way to recognise a sole: the firmware never
/// populates the device-id characteristic, and the sole advertises a new MAC
/// (`remoteId`) after every boot — so a remembered remoteId is not enough to
/// find the same physical sole again.
const soleNameKeyword = 'silversole';

bool isSoleName(String name) => name.toLowerCase().contains(soleNameKeyword);

/// One sole seen in a scan.
@immutable
class SoleCandidate {
  const SoleCandidate({
    required this.remoteId,
    required this.name,
    required this.rssi,
  });

  final String remoteId;
  final String name;
  final int rssi;

  @override
  String toString() => 'SoleCandidate($name $remoteId ${rssi}dBm)';
}

/// Picks which sole to connect to.
///
/// [preferredRemoteId] — the user's primary device — only breaks ties: a sole
/// that is actually advertising always beats a remembered remoteId that is not,
/// otherwise a stale primary device would block connecting to the sole in the
/// user's hand.
SoleCandidate? pickSole(
  List<SoleCandidate> candidates, {
  String? preferredRemoteId,
}) {
  final preferred = candidates.firstWhereOrNull(
    (c) => c.remoteId == preferredRemoteId,
  );
  if (preferred != null) return preferred;
  return candidates.sorted((a, b) => b.rssi.compareTo(a.rssi)).firstOrNull;
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
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          if (!isSoleName(name)) continue;
          found[r.device.remoteId.str] = SoleCandidate(
            remoteId: r.device.remoteId.str,
            name: name,
            rssi: r.rssi,
          );
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
}
