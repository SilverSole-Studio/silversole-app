import 'package:freezed_annotation/freezed_annotation.dart';

part 'imu_notify_data_model.freezed.dart';
part 'imu_notify_data_model.g.dart';

@freezed
abstract class ImuNotifyDataModel with _$ImuNotifyDataModel {
  const factory ImuNotifyDataModel({
    required int ax,
    required int ay,
    required int az,
    required int gx,
    required int gy,
    required int gz,
    double? pitch,
    double? roll,
    required int pressure,
    @JsonKey(name: 'battery_percent') required int batteryPercent,
    @JsonKey(name: 'is_charging') required bool isCharging,
  }) = _ImuNotifyDataModel;

  factory ImuNotifyDataModel.fromJson(Map<String, dynamic> json) => _$ImuNotifyDataModelFromJson(json);
}
