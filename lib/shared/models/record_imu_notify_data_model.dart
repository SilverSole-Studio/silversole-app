import 'package:freezed_annotation/freezed_annotation.dart';

part 'record_imu_notify_data_model.freezed.dart';
part 'record_imu_notify_data_model.g.dart';

@freezed
abstract class RecordImuNotifyDataModel with _$RecordImuNotifyDataModel {
  const factory RecordImuNotifyDataModel({
    required int timestamp,
    required int ax,
    required int ay,
    required int az,
    required int gx,
    required int gy,
    required int gz,
    required int pressure,
    @JsonKey(name: 'wear_status') required bool wearStatus,
    @JsonKey(name: 'battery_percent') required int batteryPercent,
  }) = _RecordImuNotifyDataModel;

  factory RecordImuNotifyDataModel.fromJson(Map<String, dynamic> json) => _$RecordImuNotifyDataModelFromJson(json);
}

// flutter pub run build_runner build --delete-conflicting-outputs
