// lib/shared/providers/foot_side_calibration_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/sole_reconcile.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// The connected soles, in paired order — what a calibration is about.
final connectedPairedSolesProvider = Provider<List<BlePairedDevice>>((ref) {
  final connected = ref.watch(connectedSolesProvider);
  if (connected.isEmpty) return const [];
  return ref
      .watch(settingsProvider)
      .pairedDevicesList
      .where((d) => connected.containsKey(d.identityKey))
      .toList();
});

/// Whether the wearer still has to say which sole is which.
///
/// True once both feet are connected and either sole has no side yet. A single
/// sole is never asked: there is nothing to compare it against, and the app
/// has always drawn one sole as the right foot.
final needsFootSideCalibrationProvider = Provider<bool>((ref) {
  final soles = ref.watch(connectedPairedSolesProvider);
  return soles.length >= maxSoles && soles.any((d) => d.footSide == null);
});
