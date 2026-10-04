import 'package:freezed_annotation/freezed_annotation.dart';

part 'ble_paired_device_model.freezed.dart';

part 'ble_paired_device_model.g.dart';

@freezed
abstract class BlePairedDevice with _$BlePairedDevice {
  const factory BlePairedDevice({
    String? deviceId,
    required String remoteId,
    required String name,
    String? displayModel,
    String? modelCode,
    int? lastRssi,
    DateTime? lastConnectedAt,

    /// The last valid battery level this sole reported, shown greyed out while
    /// it is offline or has not sent a fresh reading yet.
    int? lastBatteryPercent,
    @Default(false) bool isPreferred,
  }) = _BlePairedDevice;

  factory BlePairedDevice.fromJson(Map<String, dynamic> json) =>
      _$BlePairedDeviceFromJson(json);
}
