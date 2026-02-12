import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_location_model.freezed.dart';

part 'device_location_model.g.dart';

@freezed
abstract class DeviceLocationModel with _$DeviceLocationModel {
  const factory DeviceLocationModel({
    @JsonKey(includeToJson: false) int? id,
    @JsonKey(name: 'device_id') required String deviceId,
    @JsonKey(name: 'received_at', includeToJson: false) required DateTime receivedAt,
    @JsonKey(name: 'client_ts') DateTime? clientCreatedAt,
    required double lat,
    required double lng,
    @JsonKey(name: 'accuracy_m') double? accuracy,
  }) = _DeviceLocationModel;

  factory DeviceLocationModel.fromJson(Map<String, dynamic> json) => _$DeviceLocationModelFromJson(json);
}
