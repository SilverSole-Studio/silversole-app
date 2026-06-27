import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_model.freezed.dart';

// Not JSON-serialized (built from the Supabase user), so no json_serializable /
// .g.dart — freezed alone gives value equality, copyWith, toString.
@freezed
abstract class UserData with _$UserData {
  const factory UserData({required String email, required String uuid}) =
      _UserData;
}
