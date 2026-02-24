// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ble_paired_device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BlePairedDevice _$BlePairedDeviceFromJson(Map<String, dynamic> json) =>
    _BlePairedDevice(
      deviceId: json['deviceId'] as String?,
      remoteId: json['remoteId'] as String,
      name: json['name'] as String,
      displayModel: json['displayModel'] as String?,
      modelCode: json['modelCode'] as String?,
      lastRssi: (json['lastRssi'] as num?)?.toInt(),
      lastConnectedAt: json['lastConnectedAt'] == null
          ? null
          : DateTime.parse(json['lastConnectedAt'] as String),
      isPreferred: json['isPreferred'] as bool? ?? false,
    );

Map<String, dynamic> _$BlePairedDeviceToJson(_BlePairedDevice instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'remoteId': instance.remoteId,
      'name': instance.name,
      'displayModel': instance.displayModel,
      'modelCode': instance.modelCode,
      'lastRssi': instance.lastRssi,
      'lastConnectedAt': instance.lastConnectedAt?.toIso8601String(),
      'isPreferred': instance.isPreferred,
    };
