// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_imu_notify_data_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RecordImuNotifyDataModel _$RecordImuNotifyDataModelFromJson(
  Map<String, dynamic> json,
) => _RecordImuNotifyDataModel(
  timestamp: (json['timestamp'] as num).toInt(),
  ax: (json['ax'] as num).toInt(),
  ay: (json['ay'] as num).toInt(),
  az: (json['az'] as num).toInt(),
  gx: (json['gx'] as num).toInt(),
  gy: (json['gy'] as num).toInt(),
  gz: (json['gz'] as num).toInt(),
  pressure: (json['pressure'] as num).toInt(),
  wearStatus: json['wear_status'] as bool,
  batteryPercent: (json['battery_percent'] as num).toInt(),
);

Map<String, dynamic> _$RecordImuNotifyDataModelToJson(
  _RecordImuNotifyDataModel instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp,
  'ax': instance.ax,
  'ay': instance.ay,
  'az': instance.az,
  'gx': instance.gx,
  'gy': instance.gy,
  'gz': instance.gz,
  'pressure': instance.pressure,
  'wear_status': instance.wearStatus,
  'battery_percent': instance.batteryPercent,
};
