// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sole_record_data_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SilverSoleRecordModel _$SilverSoleRecordModelFromJson(
  Map<String, dynamic> json,
) => _SilverSoleRecordModel(
  uuid: json['uuid'] as String,
  userId: json['user_id'] as String?,
  deviceId: json['device_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  wearStatus: json['wear_status'] as bool,
  pressure: (json['pressure'] as num?)?.toInt(),
  pitch: (json['pitch'] as num?)?.toDouble(),
  roll: (json['roll'] as num?)?.toDouble(),
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$SilverSoleRecordModelToJson(
  _SilverSoleRecordModel instance,
) => <String, dynamic>{
  'user_id': instance.userId,
  'device_id': instance.deviceId,
  'created_at': instance.createdAt.toIso8601String(),
  'wear_status': instance.wearStatus,
  'pressure': instance.pressure,
  'pitch': instance.pitch,
  'roll': instance.roll,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};
