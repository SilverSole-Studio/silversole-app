import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_status_model.freezed.dart';
part 'device_status_model.g.dart';

@freezed
abstract class DeviceStatusBodyModel with _$DeviceStatusBodyModel {
  const factory DeviceStatusBodyModel({
    @JsonKey(name: 'battery_percent') required int batteryPercent,
    @JsonKey(name: 'is_charging') required bool isCharging,
  }) = _DeviceStatusBodyModel;

  factory DeviceStatusBodyModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceStatusBodyModelFromJson(json);
}

@freezed
abstract class DeviceStatusModel with _$DeviceStatusModel {
  const factory DeviceStatusModel({
    required String signature,
    @JsonKey(name: 'device_id') required String deviceId,
    required int timestamp,
    required DeviceStatusBodyModel body,
  }) = _DeviceStatusModel;

  factory DeviceStatusModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceStatusModelFromJson(json);
}
