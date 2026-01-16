// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sole_record_data_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SilverSoleRecordModel {

@JsonKey(includeToJson: false) String get uuid;@JsonKey(name: 'user_id') String? get userId;@JsonKey(name: 'device_id') String get deviceId;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'wear_status') bool get wearStatus; int? get pressure; double? get pitch; double? get roll; double? get latitude; double? get longitude;
/// Create a copy of SilverSoleRecordModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SilverSoleRecordModelCopyWith<SilverSoleRecordModel> get copyWith => _$SilverSoleRecordModelCopyWithImpl<SilverSoleRecordModel>(this as SilverSoleRecordModel, _$identity);

  /// Serializes this SilverSoleRecordModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SilverSoleRecordModel&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.wearStatus, wearStatus) || other.wearStatus == wearStatus)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.roll, roll) || other.roll == roll)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,userId,deviceId,createdAt,wearStatus,pressure,pitch,roll,latitude,longitude);

@override
String toString() {
  return 'SilverSoleRecordModel(uuid: $uuid, userId: $userId, deviceId: $deviceId, createdAt: $createdAt, wearStatus: $wearStatus, pressure: $pressure, pitch: $pitch, roll: $roll, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class $SilverSoleRecordModelCopyWith<$Res>  {
  factory $SilverSoleRecordModelCopyWith(SilverSoleRecordModel value, $Res Function(SilverSoleRecordModel) _then) = _$SilverSoleRecordModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) String uuid,@JsonKey(name: 'user_id') String? userId,@JsonKey(name: 'device_id') String deviceId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'wear_status') bool wearStatus, int? pressure, double? pitch, double? roll, double? latitude, double? longitude
});




}
/// @nodoc
class _$SilverSoleRecordModelCopyWithImpl<$Res>
    implements $SilverSoleRecordModelCopyWith<$Res> {
  _$SilverSoleRecordModelCopyWithImpl(this._self, this._then);

  final SilverSoleRecordModel _self;
  final $Res Function(SilverSoleRecordModel) _then;

/// Create a copy of SilverSoleRecordModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uuid = null,Object? userId = freezed,Object? deviceId = null,Object? createdAt = null,Object? wearStatus = null,Object? pressure = freezed,Object? pitch = freezed,Object? roll = freezed,Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(_self.copyWith(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,wearStatus: null == wearStatus ? _self.wearStatus : wearStatus // ignore: cast_nullable_to_non_nullable
as bool,pressure: freezed == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int?,pitch: freezed == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double?,roll: freezed == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
as double?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [SilverSoleRecordModel].
extension SilverSoleRecordModelPatterns on SilverSoleRecordModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SilverSoleRecordModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SilverSoleRecordModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SilverSoleRecordModel value)  $default,){
final _that = this;
switch (_that) {
case _SilverSoleRecordModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SilverSoleRecordModel value)?  $default,){
final _that = this;
switch (_that) {
case _SilverSoleRecordModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String uuid, @JsonKey(name: 'user_id')  String? userId, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'wear_status')  bool wearStatus,  int? pressure,  double? pitch,  double? roll,  double? latitude,  double? longitude)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SilverSoleRecordModel() when $default != null:
return $default(_that.uuid,_that.userId,_that.deviceId,_that.createdAt,_that.wearStatus,_that.pressure,_that.pitch,_that.roll,_that.latitude,_that.longitude);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  String uuid, @JsonKey(name: 'user_id')  String? userId, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'wear_status')  bool wearStatus,  int? pressure,  double? pitch,  double? roll,  double? latitude,  double? longitude)  $default,) {final _that = this;
switch (_that) {
case _SilverSoleRecordModel():
return $default(_that.uuid,_that.userId,_that.deviceId,_that.createdAt,_that.wearStatus,_that.pressure,_that.pitch,_that.roll,_that.latitude,_that.longitude);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  String uuid, @JsonKey(name: 'user_id')  String? userId, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'wear_status')  bool wearStatus,  int? pressure,  double? pitch,  double? roll,  double? latitude,  double? longitude)?  $default,) {final _that = this;
switch (_that) {
case _SilverSoleRecordModel() when $default != null:
return $default(_that.uuid,_that.userId,_that.deviceId,_that.createdAt,_that.wearStatus,_that.pressure,_that.pitch,_that.roll,_that.latitude,_that.longitude);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SilverSoleRecordModel implements SilverSoleRecordModel {
  const _SilverSoleRecordModel({@JsonKey(includeToJson: false) required this.uuid, @JsonKey(name: 'user_id') this.userId, @JsonKey(name: 'device_id') required this.deviceId, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'wear_status') required this.wearStatus, this.pressure, this.pitch, this.roll, this.latitude, this.longitude});
  factory _SilverSoleRecordModel.fromJson(Map<String, dynamic> json) => _$SilverSoleRecordModelFromJson(json);

@override@JsonKey(includeToJson: false) final  String uuid;
@override@JsonKey(name: 'user_id') final  String? userId;
@override@JsonKey(name: 'device_id') final  String deviceId;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'wear_status') final  bool wearStatus;
@override final  int? pressure;
@override final  double? pitch;
@override final  double? roll;
@override final  double? latitude;
@override final  double? longitude;

/// Create a copy of SilverSoleRecordModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SilverSoleRecordModelCopyWith<_SilverSoleRecordModel> get copyWith => __$SilverSoleRecordModelCopyWithImpl<_SilverSoleRecordModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SilverSoleRecordModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SilverSoleRecordModel&&(identical(other.uuid, uuid) || other.uuid == uuid)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.wearStatus, wearStatus) || other.wearStatus == wearStatus)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.roll, roll) || other.roll == roll)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,uuid,userId,deviceId,createdAt,wearStatus,pressure,pitch,roll,latitude,longitude);

@override
String toString() {
  return 'SilverSoleRecordModel(uuid: $uuid, userId: $userId, deviceId: $deviceId, createdAt: $createdAt, wearStatus: $wearStatus, pressure: $pressure, pitch: $pitch, roll: $roll, latitude: $latitude, longitude: $longitude)';
}


}

/// @nodoc
abstract mixin class _$SilverSoleRecordModelCopyWith<$Res> implements $SilverSoleRecordModelCopyWith<$Res> {
  factory _$SilverSoleRecordModelCopyWith(_SilverSoleRecordModel value, $Res Function(_SilverSoleRecordModel) _then) = __$SilverSoleRecordModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) String uuid,@JsonKey(name: 'user_id') String? userId,@JsonKey(name: 'device_id') String deviceId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'wear_status') bool wearStatus, int? pressure, double? pitch, double? roll, double? latitude, double? longitude
});




}
/// @nodoc
class __$SilverSoleRecordModelCopyWithImpl<$Res>
    implements _$SilverSoleRecordModelCopyWith<$Res> {
  __$SilverSoleRecordModelCopyWithImpl(this._self, this._then);

  final _SilverSoleRecordModel _self;
  final $Res Function(_SilverSoleRecordModel) _then;

/// Create a copy of SilverSoleRecordModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uuid = null,Object? userId = freezed,Object? deviceId = null,Object? createdAt = null,Object? wearStatus = null,Object? pressure = freezed,Object? pitch = freezed,Object? roll = freezed,Object? latitude = freezed,Object? longitude = freezed,}) {
  return _then(_SilverSoleRecordModel(
uuid: null == uuid ? _self.uuid : uuid // ignore: cast_nullable_to_non_nullable
as String,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,wearStatus: null == wearStatus ? _self.wearStatus : wearStatus // ignore: cast_nullable_to_non_nullable
as bool,pressure: freezed == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int?,pitch: freezed == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double?,roll: freezed == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
as double?,latitude: freezed == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double?,longitude: freezed == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
