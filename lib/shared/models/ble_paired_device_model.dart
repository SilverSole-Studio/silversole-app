import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:silversole/shared/models/foot_side.dart';

part 'ble_paired_device_model.freezed.dart';

part 'ble_paired_device_model.g.dart';

/// A sole the user has paired.
///
/// [deviceId] is the sole's permanent chip ID (the nRF52840 FICR DEVICEID as
/// 16 uppercase hex characters), and it is what identifies the sole. Firmware
/// from before the ID existed reports none, so such a sole is identified by
/// [remoteId] instead — see [identityKey]. [remoteId] itself is only the
/// address the sole was last seen at.
@freezed
abstract class BlePairedDevice with _$BlePairedDevice {
  const BlePairedDevice._();

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

    /// Which foot this sole is worn on, or null until it has been assigned.
    /// The firmware reports nothing about this — see [FootSide].
    FootSide? footSide,
    @Default(false) bool isPreferred,
  }) = _BlePairedDevice;

  factory BlePairedDevice.fromJson(Map<String, dynamic> json) =>
      _$BlePairedDeviceFromJson(json);

  /// What tells this sole apart from every other one: the chip ID, or the
  /// address for a sole on firmware too old to report one. An ID is 16 hex
  /// characters and an address carries colons, so the two never collide.
  String get identityKey => deviceId ?? remoteId;

  /// The last 4 characters of the chip ID — enough to tell soles apart in a
  /// list where every one of them is called "SilverSole".
  String? get shortId {
    final id = deviceId;
    if (id == null || id.length < 4) return id;
    return id.substring(id.length - 4);
  }
}
