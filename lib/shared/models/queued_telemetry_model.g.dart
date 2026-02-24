// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queued_telemetry_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_QueuedTelemetry _$QueuedTelemetryFromJson(Map<String, dynamic> json) =>
    _QueuedTelemetry(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>,
      createAt: DateTime.parse(json['createAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$QueuedTelemetryToJson(_QueuedTelemetry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deviceId': instance.deviceId,
      'type': instance.type,
      'payload': instance.payload,
      'createAt': instance.createAt.toIso8601String(),
      'retryCount': instance.retryCount,
    };
