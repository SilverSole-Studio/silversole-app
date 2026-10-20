import 'package:flutter/foundation.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// What one sole is reporting right now.
@immutable
class SoleLiveFacts {
  const SoleLiveFacts({required this.online, this.batteryPercent});

  /// A sole that is not streaming at all.
  const SoleLiveFacts.offline() : online = false, batteryPercent = null;

  /// True while this sole's own telemetry is fresh.
  final bool online;

  /// The level it last reported on the live stream, if any.
  final int? batteryPercent;
}

/// A paired device plus the live facts for that sole.
class DeviceRow {
  const DeviceRow({
    required this.device,
    required this.online,
    required this.battery,
  });

  final BlePairedDevice device;

  /// True while this sole's own telemetry is fresh. With one sole per foot,
  /// more than one row can be online at a time.
  final bool online;

  /// Live for a sole that is streaming a valid reading; every other row shows
  /// the level remembered from that sole's last session.
  final BatteryDisplay battery;
}

/// Derives the devices panel's rows.
///
/// [liveFor] answers, per sole identityKey, whether that sole is streaming and
/// what it last reported — [SoleLiveFacts.offline] for a sole that is not.
List<DeviceRow> buildDeviceRows({
  required List<BlePairedDevice> devices,
  required SoleLiveFacts Function(String identityKey) liveFor,
}) {
  final rows = <DeviceRow>[];
  for (final device in devices) {
    final live = liveFor(device.identityKey);
    rows.add(
      DeviceRow(
        device: device,
        online: live.online,
        battery: BatteryDisplay.resolve(
          live: live.online ? live.batteryPercent : null,
          lastKnown: device.lastBatteryPercent,
        ),
      ),
    );
  }
  return rows;
}
