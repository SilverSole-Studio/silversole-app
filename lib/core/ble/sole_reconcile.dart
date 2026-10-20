import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// How many soles may be connected at once — one per foot.
const int maxSoles = 2;

/// The key a scanned sole's session is held under: its paired entry's
/// [BlePairedDevice.identityKey] when the sole is known, otherwise its own ID,
/// otherwise its address.
///
/// Deliberately the *stored* entry's key, not the candidate's own ID: a sole
/// paired on old firmware reports an ID only after it is linked, so the scan
/// can show a different key than the session was opened under. Within one call
/// the stored entry gives one stable key.
///
/// The key does change between calls once the handshake persists the chip ID,
/// and this function cannot follow that on its own. It is the session
/// registry's obligation to re-key a live session when its paired entry's
/// identityKey changes. Until it does, the old key reads as "no longer paired"
/// and [reconcileSoleLinks] detaches a working connection.
String identityKeyFor(
  SoleCandidate candidate,
  List<BlePairedDevice> paired,
) {
  final known = paired.firstWhereOrNull((d) => isSameSole(candidate, d));
  return known?.identityKey ?? candidate.deviceId ?? candidate.remoteId;
}

/// What the search loop should do after one scan.
@immutable
class SoleReconciliation {
  const SoleReconciliation({required this.attach, required this.detach});

  /// Soles to start a session with, best first.
  final List<SoleCandidate> attach;

  /// identityKeys whose session should be torn down.
  final Set<String> detach;
}

/// Works out which soles to connect and which sessions to drop.
///
/// [picks] is what [pickSoles] returned, [paired] the stored entries and
/// [linkedKeys] the soles that already have a session.
///
/// A sole that already has a link is never re-attached — that would drop a
/// working connection. **Being absent from [picks] is never a reason to
/// detach**: a connected sole usually stops advertising, so a scan says
/// nothing about it. Only a sole that is no longer paired loses its session.
SoleReconciliation reconcileSoleLinks({
  required List<SoleCandidate> picks,
  required List<BlePairedDevice> paired,
  required Set<String> linkedKeys,
  int max = maxSoles,
}) {
  final pairedKeys = paired.map((d) => d.identityKey).toSet();
  final detach = linkedKeys.difference(pairedKeys);
  final keeping = linkedKeys.difference(detach);

  final attach = <SoleCandidate>[];
  final attaching = <String>{};
  for (final pick in picks) {
    if (keeping.length + attach.length >= max) break;
    final key = identityKeyFor(pick, paired);
    if (keeping.contains(key) || !attaching.add(key)) continue;
    attach.add(pick);
  }

  return SoleReconciliation(attach: attach, detach: detach);
}
