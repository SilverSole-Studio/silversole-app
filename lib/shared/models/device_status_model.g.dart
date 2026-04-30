// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_status_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceStatusBodyModel _$DeviceStatusBodyModelFromJson(
  Map<String, dynamic> json,
) => _DeviceStatusBodyModel(
  batteryPercent: (json['battery_percent'] as num).toInt(),
  isCharging: json['is_charging'] as bool,
);

Map<String, dynamic> _$DeviceStatusBodyModelToJson(
  _DeviceStatusBodyModel instance,
) => <String, dynamic>{
  'battery_percent': instance.batteryPercent,
  'is_charging': instance.isCharging,
};

_DeviceStatusModel _$DeviceStatusModelFromJson(Map<String, dynamic> json) =>
    _DeviceStatusModel(
      signature: json['signature'] as String,
      deviceId: json['device_id'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
      body: DeviceStatusBodyModel.fromJson(
        json['body'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$DeviceStatusModelToJson(_DeviceStatusModel instance) =>
    <String, dynamic>{
      'signature': instance.signature,
      'device_id': instance.deviceId,
      'timestamp': instance.timestamp,
      'body': instance.body,
    };
