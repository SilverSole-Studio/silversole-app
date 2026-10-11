import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

enum ReacquireConfidence {
  /// The same chip ID, or for a sole that had none, the same address.
  certain,

  /// The only sole on the air, and no other paired sole's ID.
  probable,
}

@immutable
class ReacquireMatch {
  const ReacquireMatch(this.candidate, this.confidence);

  final SoleCandidate candidate;
  final ReacquireConfidence confidence;
}

/// Whether [candidate] is certainly [target]: by chip ID, or by address for a
/// sole that reported no ID before its update.
bool isReacquireTarget(SoleCandidate candidate, BlePairedDevice target) {
  final id = target.deviceId;
  if (id != null) return candidate.deviceId == id;
  return candidate.remoteId == target.remoteId;
}

/// Picks the sole that was just updated out of everything a scan saw
/// (the OTA spec's §2.3). Only a sole on firmware too old to report an ID is
/// ever guessed at, and only when exactly one sole is on the air and it is
/// not another paired sole.
ReacquireMatch? matchReacquireTarget({
  required BlePairedDevice target,
  required List<SoleCandidate> seen,
  required List<BlePairedDevice> paired,
}) {
  final certain = seen.firstWhereOrNull((c) => isReacquireTarget(c, target));
  if (certain != null) {
    return ReacquireMatch(certain, ReacquireConfidence.certain);
  }
  if (target.deviceId != null || seen.length != 1) return null;
  final only = seen.single;
  final ownedElsewhere = paired.any(
    (d) =>
        d.identityKey != target.identityKey &&
        d.deviceId != null &&
        d.deviceId == only.deviceId,
  );
  return ownedElsewhere
      ? null
      : ReacquireMatch(only, ReacquireConfidence.probable);
}
