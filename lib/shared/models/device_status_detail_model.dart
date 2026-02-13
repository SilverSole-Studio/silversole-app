import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_status_detail_model.freezed.dart';
part 'device_status_detail_model.g.dart';

@freezed
abstract class DeviceStatusDetailModel with _$DeviceStatusDetailModel {
  const factory DeviceStatusDetailModel({
    @JsonKey(name: 'last_heartbeat_at', includeToJson: false) DateTime? lastHeartbeatAt,
    @JsonKey(name: 'last_battery_percent') int? lastBatteryPercent,
    @JsonKey(name: 'last_battery_at', includeToJson: false) DateTime? lastBatteryAt,
    @JsonKey(name: 'is_charging') bool? isCharging,
  }) = _DeviceStatusDetailModel;

  factory DeviceStatusDetailModel.fromJson(Map<String, dynamic> json) => _$DeviceStatusDetailModelFromJson(json);
}
