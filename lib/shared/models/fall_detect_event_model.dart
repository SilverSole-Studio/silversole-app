import 'package:freezed_annotation/freezed_annotation.dart';

part 'fall_detect_event_model.freezed.dart';
part 'fall_detect_event_model.g.dart';

@freezed
abstract class FallDetectEvent with _$FallDetectEvent {
  const factory FallDetectEvent({
    required DateTime timestamp,
    required String deviceId,
    required bool detect,
  }) = _FallDetectEvent;

  factory FallDetectEvent.fromJson(Map<String, dynamic> json) => _$FallDetectEventFromJson(json);
}

// flutter pub run build_runner build --delete-conflicting-outputs
