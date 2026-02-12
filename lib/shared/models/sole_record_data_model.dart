import 'package:freezed_annotation/freezed_annotation.dart';

part 'sole_record_data_model.freezed.dart';
part 'sole_record_data_model.g.dart';

@freezed
abstract class SilverSoleRecordModel with _$SilverSoleRecordModel {
  const factory SilverSoleRecordModel({
    @JsonKey(includeToJson: false) required int id,
    @JsonKey(name: 'device_id') required String deviceId,
    @JsonKey(name: 'received_at', includeToJson: false) required DateTime receivedAt,
    @JsonKey(name: 'client_ts') int? clientTs,
    @JsonKey(name: 'wear_status') required bool wearStatus,
    @JsonKey(name: 'pressure') required int pressure,
    double? pitch,
    double? roll,
  }) = _SilverSoleRecordModel;

  factory SilverSoleRecordModel.fromJson(Map<String, dynamic> json) => _$SilverSoleRecordModelFromJson(json);
}