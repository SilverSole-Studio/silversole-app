import 'package:freezed_annotation/freezed_annotation.dart';

part 'queued_telemetry_model.freezed.dart';
part 'queued_telemetry_model.g.dart';

@freezed
abstract class QueuedTelemetry with _$QueuedTelemetry {
  const factory QueuedTelemetry({
    required String id,
    required String deviceId,
    required String type,
    required Map<String, dynamic> payload,
    required DateTime createAt,
    @Default(0) int retryCount,
  }) = _QueuedTelemetry;

  factory QueuedTelemetry.fromJson(Map<String, dynamic> json) => _$QueuedTelemetryFromJson(json);
}

