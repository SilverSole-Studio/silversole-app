import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// Firmware facts the devices panel shows but the app cannot read yet: the
/// GATT contract (`ble_uuids.dart`) has no firmware characteristic, so these
/// are mockup copy. Kept here so both themes print the same thing and there is
/// a single place to delete once the sole reports its own version.
abstract final class MockFirmware {
  static const String version = 'v2.4.1';
  static const int sampleRateHz = 100;
  static const bool upToDate = true;
}

/// A paired device plus the live facts that only apply to the one currently
/// streaming.
class DeviceRow {
  const DeviceRow({
    required this.device,
    required this.online,
    this.batteryPercent,
  });

  final BlePairedDevice device;

  /// True only for the preferred device while its telemetry is fresh — the app
  /// holds one BLE connection at a time, so at most one row is online.
  final bool online;

  /// Live battery level; null for every device that is not the one streaming,
  /// since nothing else reports one.
  final int? batteryPercent;
}

/// Derives the devices panel's rows.
///
/// [online] and [liveBatteryPercent] describe the live stream, which belongs
/// to [preferred]; the remaining paired devices are listed but carry no
/// readings of their own.
List<DeviceRow> buildDeviceRows({
  required List<BlePairedDevice> devices,
  required BlePairedDevice? preferred,
  required bool online,
  required int? liveBatteryPercent,
}) {
  return [
    for (final device in devices)
      if (device.remoteId == preferred?.remoteId)
        DeviceRow(
          device: device,
          online: online,
          batteryPercent: liveBatteryPercent,
        )
      else
        DeviceRow(device: device, online: false),
  ];
}
