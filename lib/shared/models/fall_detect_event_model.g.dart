// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fall_detect_event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FallDetectEvent _$FallDetectEventFromJson(Map<String, dynamic> json) =>
    _FallDetectEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['deviceId'] as String,
      detect: json['detect'] as bool,
    );

Map<String, dynamic> _$FallDetectEventToJson(_FallDetectEvent instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.toIso8601String(),
      'deviceId': instance.deviceId,
      'detect': instance.detect,
    };
