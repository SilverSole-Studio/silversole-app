// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceLocationModel _$DeviceLocationModelFromJson(Map<String, dynamic> json) =>
    _DeviceLocationModel(
      id: (json['id'] as num?)?.toInt(),
      deviceId: json['device_id'] as String,
      receivedAt: DateTime.parse(json['received_at'] as String),
      clientCreatedAt: json['client_ts'] == null
          ? null
          : DateTime.parse(json['client_ts'] as String),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracy: (json['accuracy_m'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$DeviceLocationModelToJson(
  _DeviceLocationModel instance,
) => <String, dynamic>{
  'device_id': instance.deviceId,
  'client_ts': instance.clientCreatedAt?.toIso8601String(),
  'lat': instance.lat,
  'lng': instance.lng,
  'accuracy_m': instance.accuracy,
};
