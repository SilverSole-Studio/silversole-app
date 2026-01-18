
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_device_model.freezed.dart';

part 'user_device_model.g.dart';

@freezed
abstract class UserDeviceModel with _$UserDeviceModel {
  const factory UserDeviceModel({
    @JsonKey(includeToJson: false) int? id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'device_id') required String deviceId,
    String? nickname,
    @JsonKey(name: 'created_at', includeToJson: false) DateTime? createdAt,
  }) = _UserDeviceModel;

  factory UserDeviceModel.fromJson(Map<String, dynamic> json) => _$UserDeviceModelFromJson(json);
}