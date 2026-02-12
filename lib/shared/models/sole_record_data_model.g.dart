// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sole_record_data_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SilverSoleRecordModel _$SilverSoleRecordModelFromJson(
  Map<String, dynamic> json,
) => _SilverSoleRecordModel(
  id: (json['id'] as num).toInt(),
  deviceId: json['device_id'] as String,
  receivedAt: DateTime.parse(json['received_at'] as String),
  clientTs: (json['client_ts'] as num?)?.toInt(),
  wearStatus: json['wear_status'] as bool,
  pressure: (json['pressure'] as num).toInt(),
  pitch: (json['pitch'] as num?)?.toDouble(),
  roll: (json['roll'] as num?)?.toDouble(),
);

Map<String, dynamic> _$SilverSoleRecordModelToJson(
  _SilverSoleRecordModel instance,
) => <String, dynamic>{
  'device_id': instance.deviceId,
  'received_at': instance.receivedAt.toIso8601String(),
  'client_ts': instance.clientTs,
  'wear_status': instance.wearStatus,
  'pressure': instance.pressure,
  'pitch': instance.pitch,
  'roll': instance.roll,
};
