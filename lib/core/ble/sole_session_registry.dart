import 'dart:async';

import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// One sole's live session plus the per-sole state the orchestrator keeps
/// alongside it.
class SoleLink {
  SoleLink({required this.service, required this.device});

  final BleConnectionService service;

  /// The sole as the last handshake saw it. The orchestrator refreshes this
  /// (a fresh battery level, an ID a legacy entry just picked up).
  BlePairedDevice device;

  /// Re-scans when this session never connects, or does not come back after a
  /// link loss — the "give up on this MAC" path, per sole.
  Timer? watchdog;

  /// Throttles the IMU parse-failure log: a wire-format mismatch fails on
  /// every packet and would otherwise spam ~20 lines/s.
  int imuFailCount = 0;

  bool get isConnected => service.isConnected;

  void cancelWatchdog() {
    watchdog?.cancel();
    watchdog = null;
  }
}

/// Every live sole session, keyed by [BlePairedDevice.identityKey].
///
/// [BleConnectionService] already keeps all of its state per instance, so one
/// instance per sole is all two feet need; this owns those instances and their
/// lifetimes. [createService] exists so tests can stand in a fake.
class SoleSessionRegistry {
  SoleSessionRegistry({BleConnectionService Function()? createService})
    : _createService = createService ?? BleConnectionService.new;

  final BleConnectionService Function() _createService;
  final _links = <String, SoleLink>{};

  Iterable<SoleLink> get links => _links.values;

  Set<String> get keys => _links.keys.toSet();

  /// The links with the keys they are filed under — what the search decision
  /// needs, since a link's device can carry a different identityKey than the
  /// key it was filed under until the next re-key.
  Map<String, SoleLink> get entries => Map.unmodifiable(_links);

  int get connectedCount => _links.values.where((l) => l.isConnected).length;

  bool get anyConnected => _links.values.any((l) => l.isConnected);

  SoleLink? lookup(String identityKey) => _links[identityKey];

  /// The link for [identityKey], created on first use. An existing link keeps
  /// its service — and therefore its connection — and only takes the fresher
  /// [device].
  SoleLink link(String identityKey, BlePairedDevice device) {
    final existing = _links[identityKey];
    if (existing != null) {
      existing.device = device;
      return existing;
    }
    return _links[identityKey] = SoleLink(
      service: _createService(),
      device: device,
    );
  }

  /// Moves a live session from [oldKey] to [newKey], keeping its service — and
  /// so its connection — intact.
  ///
  /// A sole paired on pre-ID firmware is filed under its address; the moment
  /// its handshake reports a chip ID its paired entry is keyed by that ID
  /// instead, and a session still filed under the address reads as "no longer
  /// paired" to `reconcileSoleLinks`, which would tear down a working link.
  ///
  /// The map move completes **synchronously**, before this method's first
  /// await, on purpose: the orchestrator calls this fire-and-forget from a
  /// handshake and reads the new key straight afterwards. An await placed
  /// ahead of the move would silently stop that sole's telemetry.
  Future<void> rekey(String oldKey, String newKey) async {
    if (oldKey == newKey) return;
    final link = _links.remove(oldKey);
    if (link == null) return;
    if (!_links.containsKey(newKey)) {
      _links[newKey] = link;
      return;
    }
    // Something is already filed under the new key — the same sole reached
    // twice. Keep that one and retire the misfiled session rather than leave
    // two links to one foot.
    link.cancelWatchdog();
    await link.service.detach();
  }

  Future<void> detach(String identityKey) async {
    final link = _links.remove(identityKey);
    if (link == null) return;
    link.cancelWatchdog();
    await link.service.detach();
  }

  Future<void> detachAll() async {
    for (final key in keys) {
      await detach(key);
    }
  }
}
