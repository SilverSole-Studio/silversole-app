// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_status_detail_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceStatusDetailModel _$DeviceStatusDetailModelFromJson(
  Map<String, dynamic> json,
) => _DeviceStatusDetailModel(
  lastHeartbeatAt: json['last_heartbeat_at'] == null
      ? null
      : DateTime.parse(json['last_heartbeat_at'] as String),
  lastBatteryPercent: (json['last_battery_percent'] as num?)?.toInt(),
  lastBatteryAt: json['last_battery_at'] == null
      ? null
      : DateTime.parse(json['last_battery_at'] as String),
  isCharging: json['is_charging'] as bool?,
);

Map<String, dynamic> _$DeviceStatusDetailModelToJson(
  _DeviceStatusDetailModel instance,
) => <String, dynamic>{
  'last_battery_percent': instance.lastBatteryPercent,
  'is_charging': instance.isCharging,
};
