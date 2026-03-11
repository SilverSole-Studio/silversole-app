import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

part 'live_telemetry_state.freezed.dart';

enum TelemetrySource {
  bleLive,
  supabase,
  none,
}

@freezed
abstract class LiveTelemetryState with _$LiveTelemetryState {
  const factory LiveTelemetryState({
    @Default(TelemetrySource.none) TelemetrySource source,
    @Default(<ImuNotifyDataModel>[]) List<ImuNotifyDataModel> recentImu,
    @Default(<ImuNotifyDataModel>[]) List<ImuNotifyDataModel> record,
    DateTime? updatedAt,
    @Default(false) bool loading,
    String? errorMessage,
  }) = _LiveTelemetryState;
}