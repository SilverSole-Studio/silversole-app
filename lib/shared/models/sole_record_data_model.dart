import 'package:freezed_annotation/freezed_annotation.dart';

part 'sole_record_data_model.freezed.dart';
part 'sole_record_data_model.g.dart';

@freezed
abstract class SilverSoleRecordModel with _$SilverSoleRecordModel {
  const factory SilverSoleRecordModel({
    @JsonKey(includeToJson: false) required String uuid,
    @JsonKey(name: 'user_id') String? userId,
    @JsonKey(name: 'device_id') required String deviceId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'wear_status') required bool wearStatus,
    int? pressure,
    double? pitch,
    double? roll,
    double? latitude,
    double? longitude,
}) = _SilverSoleRecordModel;

  factory SilverSoleRecordModel.fromJson(Map<String, dynamic> json) => _$SilverSoleRecordModelFromJson(json);
}