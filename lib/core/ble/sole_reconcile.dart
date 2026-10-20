import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';
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
///
/// **Known hazard, deliberately not fixed.** A legacy pre-ID entry whose sole
/// comes back on a *new* address, already reporting a chip ID, matches no
/// paired entry at all: [isSameSole] cannot tie the new ID to an entry that
/// only ever knew an address. A fresh entry is appended under the chip ID, the
/// old entry keeps the foot side while live data streams under the new key —
/// so the assigned foot silently goes blank and the devices page grows a
/// duplicate row. Near-unreachable with nRF random-static addressing, where
/// the address does not change between boots, which is why this is a note
/// rather than a fix. The exit is "clear all devices" and pairing again.
String identityKeyFor(SoleCandidate candidate, List<BlePairedDevice> paired) {
  final known = paired.firstWhereOrNull((d) => isSameSole(candidate, d));
  return known?.identityKey ?? candidate.deviceId ?? candidate.remoteId;
}

/// A link as the search decision sees it.
@immutable
class LinkState {
  const LinkState({
    required this.key,
    required this.isConnected,
    required this.awaitingWatchdog,
  });

  /// The key the session is filed under — not necessarily its device's
  /// current identityKey, which is why the caller must read it from the
  /// registry's own map.
  final String key;

  final bool isConnected;

  /// True while this link's watchdog has yet to fire — the grace period in
  /// which the service's own backoff may still bring the same address back.
  final bool awaitingWatchdog;

  /// Whether this link still holds its foot's slot. A link whose watchdog has
  /// fired without reconnecting is dead: it must not keep its slot, or the
  /// sole it belongs to can never be re-attached on a new address.
  bool get isLive => isConnected || awaitingWatchdog;
}

/// What the search decision sees in [registry].
///
/// Keyed off the registry's own map rather than each link's device, because a
/// link filed under an address still carries that key until the next re-key.
///
/// `watchdog?.isActive ?? false` is the subtle part, and why this is a
/// function with tests of its own rather than a closure: a *fired* Timer
/// reports `isActive == false`, which is exactly "this link's watchdog has had
/// its chance". A link whose watchdog has fired without reconnecting no longer
/// holds its foot's slot, and a link with no watchdog at all never held one.
List<LinkState> linkStatesOf(SoleSessionRegistry registry) => [
  for (final entry in registry.entries.entries)
    LinkState(
      key: entry.key,
      isConnected: entry.value.isConnected,
      awaitingWatchdog: entry.value.watchdog?.isActive ?? false,
    ),
];

/// What the search loop should do after one scan.
@immutable
class SoleReconciliation {
  const SoleReconciliation({
    required this.attach,
    required this.detach,
    required this.reschedule,
  });

  /// Soles to start a session with, best first.
  final List<SoleCandidate> attach;

  /// identityKeys whose session should be torn down.
  final Set<String> detach;

  /// Whether a foot is still unaccounted for once this plan is carried out, so
  /// the search has to run again on its backoff.
  final bool reschedule;
}

int _desiredFor(List<BlePairedDevice> paired, int max) =>
    paired.length < max ? paired.length : max;

/// Works out which soles to connect and which sessions to drop.
///
/// [picks] is what [pickSoles] returned, [paired] the stored entries and
/// [links] the sessions that already exist, with the keys they are filed
/// under.
///
/// A sole that already has a *live* link is never re-attached — that would
/// drop a working connection. **Being absent from [picks] is never a reason to
/// detach**: a connected sole usually stops advertising, so a scan says
/// nothing about it. Only a sole that is no longer paired loses its session.
///
/// The cost of that rule, accepted rather than solved: a link to a sole that
/// is still paired but out of range is never torn down, so its own backoff
/// retries forever on a 30 s ceiling, and each attempt holds
/// flutter_blue_plus 2.1.1's single global GATT mutex for up to the 15 s
/// connect timeout. [LinkState.isLive] stops such a link starving a *foot's
/// slot*, but it does not stop it starving the *mutex* — with two feet there
/// can be two dead links queued ahead of a live foot's handshake. Dropping
/// the retry would be worse: that session is the only thing that reconnects
/// the sole when the wearer walks back into range.
SoleReconciliation reconcileSoleLinks({
  required List<SoleCandidate> picks,
  required List<BlePairedDevice> paired,
  required List<LinkState> links,
  int max = maxSoles,
}) {
  final pairedKeys = paired.map((d) => d.identityKey).toSet();
  final desired = _desiredFor(paired, max);
  final detach = links
      .where((l) => !pairedKeys.contains(l.key))
      .map((l) => l.key)
      .toSet();
  // Only a live link holds its foot's slot. A dead one keeps its session —
  // it is still paired, and that session is what reconnects it — but it must
  // not stand in the way of attaching the same sole on a new address.
  final held = links
      .where((l) => l.isLive && pairedKeys.contains(l.key))
      .map((l) => l.key)
      .toSet();

  final attach = <SoleCandidate>[];
  final attaching = <String>{};
  for (final pick in picks) {
    if (held.length + attach.length >= desired) break;
    final key = identityKeyFor(pick, paired);
    if (held.contains(key) || !attaching.add(key)) continue;
    attach.add(pick);
  }

  return SoleReconciliation(
    attach: attach,
    detach: detach,
    reschedule: held.length + attach.length < desired,
  );
}

/// Whether a search pass is worth running at all, before paying for a scan.
///
/// True when a foot is missing, when a link has died, or when a link belongs
/// to a sole that is no longer paired — and always for a forced manual pick,
/// and always when nothing is paired, which is the teardown path.
bool needsSearch({
  required List<BlePairedDevice> paired,
  required List<LinkState> links,
  required bool force,
  int max = maxSoles,
}) {
  if (force) return true;
  if (paired.isEmpty) return true;
  final pairedKeys = paired.map((d) => d.identityKey).toSet();
  // A session for a sole the wearer has unpaired has to be torn down, and
  // unpairing anything but the primary sole changes neither the preferred key
  // nor the preferred address — so this is the only signal the search loop
  // gets. Left running, that sole keeps streaming and its next handshake puts
  // it back in the paired list.
  if (links.any((l) => !pairedKeys.contains(l.key))) return true;
  final live = links.where((l) => l.isLive && pairedKeys.contains(l.key));
  return live.length < _desiredFor(paired, max);
}
