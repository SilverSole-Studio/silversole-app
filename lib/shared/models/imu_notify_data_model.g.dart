// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'imu_notify_data_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ImuNotifyDataModel _$ImuNotifyDataModelFromJson(Map<String, dynamic> json) =>
    _ImuNotifyDataModel(
      ax: (json['ax'] as num).toInt(),
      ay: (json['ay'] as num).toInt(),
      az: (json['az'] as num).toInt(),
      gx: (json['gx'] as num).toInt(),
      gy: (json['gy'] as num).toInt(),
      gz: (json['gz'] as num).toInt(),
      pitch: (json['pitch'] as num?)?.toDouble(),
      roll: (json['roll'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num).toInt(),
      batteryPercent: (json['battery_percent'] as num).toInt(),
      isCharging: json['is_charging'] as bool,
    );

Map<String, dynamic> _$ImuNotifyDataModelToJson(_ImuNotifyDataModel instance) =>
    <String, dynamic>{
      'ax': instance.ax,
      'ay': instance.ay,
      'az': instance.az,
      'gx': instance.gx,
      'gy': instance.gy,
      'gz': instance.gz,
      'pitch': instance.pitch,
      'roll': instance.roll,
      'pressure': instance.pressure,
      'battery_percent': instance.batteryPercent,
      'is_charging': instance.isCharging,
    };
