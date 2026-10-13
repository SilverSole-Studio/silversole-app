import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// A paired device plus the live facts that only apply to the one currently
/// streaming.
class DeviceRow {
  const DeviceRow({
    required this.device,
    required this.online,
    required this.battery,
  });

  final BlePairedDevice device;

  /// True only for the preferred device while its telemetry is fresh — the app
  /// holds one BLE connection at a time, so at most one row is online.
  final bool online;

  /// Live for the device that is streaming; every other row shows the level
  /// remembered from its last session.
  final BatteryDisplay battery;
}

/// Derives the devices panel's rows.
///
/// [online] and [liveBatteryPercent] describe the live stream, which belongs
/// to [preferred]; the remaining paired devices carry only their remembered
/// battery level.
List<DeviceRow> buildDeviceRows({
  required List<BlePairedDevice> devices,
  required BlePairedDevice? preferred,
  required bool online,
  required int? liveBatteryPercent,
}) {
  return [
    for (final device in devices)
      if (device.identityKey == preferred?.identityKey)
        DeviceRow(
          device: device,
          online: online,
          battery: BatteryDisplay.resolve(
            live: online ? liveBatteryPercent : null,
            lastKnown: device.lastBatteryPercent,
          ),
        )
      else
        DeviceRow(
          device: device,
          online: false,
          battery: BatteryDisplay.resolve(lastKnown: device.lastBatteryPercent),
        ),
  ];
}
