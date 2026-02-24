// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ble_paired_device_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BlePairedDevice {

 String? get deviceId; String get remoteId; String get name; String? get displayModel; String? get modelCode; int? get lastRssi; DateTime? get lastConnectedAt; bool get isPreferred;
/// Create a copy of BlePairedDevice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BlePairedDeviceCopyWith<BlePairedDevice> get copyWith => _$BlePairedDeviceCopyWithImpl<BlePairedDevice>(this as BlePairedDevice, _$identity);

  /// Serializes this BlePairedDevice to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BlePairedDevice&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.remoteId, remoteId) || other.remoteId == remoteId)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayModel, displayModel) || other.displayModel == displayModel)&&(identical(other.modelCode, modelCode) || other.modelCode == modelCode)&&(identical(other.lastRssi, lastRssi) || other.lastRssi == lastRssi)&&(identical(other.lastConnectedAt, lastConnectedAt) || other.lastConnectedAt == lastConnectedAt)&&(identical(other.isPreferred, isPreferred) || other.isPreferred == isPreferred));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,remoteId,name,displayModel,modelCode,lastRssi,lastConnectedAt,isPreferred);

@override
String toString() {
  return 'BlePairedDevice(deviceId: $deviceId, remoteId: $remoteId, name: $name, displayModel: $displayModel, modelCode: $modelCode, lastRssi: $lastRssi, lastConnectedAt: $lastConnectedAt, isPreferred: $isPreferred)';
}


}

/// @nodoc
abstract mixin class $BlePairedDeviceCopyWith<$Res>  {
  factory $BlePairedDeviceCopyWith(BlePairedDevice value, $Res Function(BlePairedDevice) _then) = _$BlePairedDeviceCopyWithImpl;
@useResult
$Res call({
 String? deviceId, String remoteId, String name, String? displayModel, String? modelCode, int? lastRssi, DateTime? lastConnectedAt, bool isPreferred
});




}
/// @nodoc
class _$BlePairedDeviceCopyWithImpl<$Res>
    implements $BlePairedDeviceCopyWith<$Res> {
  _$BlePairedDeviceCopyWithImpl(this._self, this._then);

  final BlePairedDevice _self;
  final $Res Function(BlePairedDevice) _then;

/// Create a copy of BlePairedDevice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceId = freezed,Object? remoteId = null,Object? name = null,Object? displayModel = freezed,Object? modelCode = freezed,Object? lastRssi = freezed,Object? lastConnectedAt = freezed,Object? isPreferred = null,}) {
  return _then(_self.copyWith(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,remoteId: null == remoteId ? _self.remoteId : remoteId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayModel: freezed == displayModel ? _self.displayModel : displayModel // ignore: cast_nullable_to_non_nullable
as String?,modelCode: freezed == modelCode ? _self.modelCode : modelCode // ignore: cast_nullable_to_non_nullable
as String?,lastRssi: freezed == lastRssi ? _self.lastRssi : lastRssi // ignore: cast_nullable_to_non_nullable
as int?,lastConnectedAt: freezed == lastConnectedAt ? _self.lastConnectedAt : lastConnectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isPreferred: null == isPreferred ? _self.isPreferred : isPreferred // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BlePairedDevice].
extension BlePairedDevicePatterns on BlePairedDevice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BlePairedDevice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BlePairedDevice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BlePairedDevice value)  $default,){
final _that = this;
switch (_that) {
case _BlePairedDevice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BlePairedDevice value)?  $default,){
final _that = this;
switch (_that) {
case _BlePairedDevice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? deviceId,  String remoteId,  String name,  String? displayModel,  String? modelCode,  int? lastRssi,  DateTime? lastConnectedAt,  bool isPreferred)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BlePairedDevice() when $default != null:
return $default(_that.deviceId,_that.remoteId,_that.name,_that.displayModel,_that.modelCode,_that.lastRssi,_that.lastConnectedAt,_that.isPreferred);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? deviceId,  String remoteId,  String name,  String? displayModel,  String? modelCode,  int? lastRssi,  DateTime? lastConnectedAt,  bool isPreferred)  $default,) {final _that = this;
switch (_that) {
case _BlePairedDevice():
return $default(_that.deviceId,_that.remoteId,_that.name,_that.displayModel,_that.modelCode,_that.lastRssi,_that.lastConnectedAt,_that.isPreferred);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? deviceId,  String remoteId,  String name,  String? displayModel,  String? modelCode,  int? lastRssi,  DateTime? lastConnectedAt,  bool isPreferred)?  $default,) {final _that = this;
switch (_that) {
case _BlePairedDevice() when $default != null:
return $default(_that.deviceId,_that.remoteId,_that.name,_that.displayModel,_that.modelCode,_that.lastRssi,_that.lastConnectedAt,_that.isPreferred);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BlePairedDevice implements BlePairedDevice {
  const _BlePairedDevice({this.deviceId, required this.remoteId, required this.name, this.displayModel, this.modelCode, this.lastRssi, this.lastConnectedAt, this.isPreferred = false});
  factory _BlePairedDevice.fromJson(Map<String, dynamic> json) => _$BlePairedDeviceFromJson(json);

@override final  String? deviceId;
@override final  String remoteId;
@override final  String name;
@override final  String? displayModel;
@override final  String? modelCode;
@override final  int? lastRssi;
@override final  DateTime? lastConnectedAt;
@override@JsonKey() final  bool isPreferred;

/// Create a copy of BlePairedDevice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BlePairedDeviceCopyWith<_BlePairedDevice> get copyWith => __$BlePairedDeviceCopyWithImpl<_BlePairedDevice>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BlePairedDeviceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BlePairedDevice&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.remoteId, remoteId) || other.remoteId == remoteId)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayModel, displayModel) || other.displayModel == displayModel)&&(identical(other.modelCode, modelCode) || other.modelCode == modelCode)&&(identical(other.lastRssi, lastRssi) || other.lastRssi == lastRssi)&&(identical(other.lastConnectedAt, lastConnectedAt) || other.lastConnectedAt == lastConnectedAt)&&(identical(other.isPreferred, isPreferred) || other.isPreferred == isPreferred));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,deviceId,remoteId,name,displayModel,modelCode,lastRssi,lastConnectedAt,isPreferred);

@override
String toString() {
  return 'BlePairedDevice(deviceId: $deviceId, remoteId: $remoteId, name: $name, displayModel: $displayModel, modelCode: $modelCode, lastRssi: $lastRssi, lastConnectedAt: $lastConnectedAt, isPreferred: $isPreferred)';
}


}

/// @nodoc
abstract mixin class _$BlePairedDeviceCopyWith<$Res> implements $BlePairedDeviceCopyWith<$Res> {
  factory _$BlePairedDeviceCopyWith(_BlePairedDevice value, $Res Function(_BlePairedDevice) _then) = __$BlePairedDeviceCopyWithImpl;
@override @useResult
$Res call({
 String? deviceId, String remoteId, String name, String? displayModel, String? modelCode, int? lastRssi, DateTime? lastConnectedAt, bool isPreferred
});




}
/// @nodoc
class __$BlePairedDeviceCopyWithImpl<$Res>
    implements _$BlePairedDeviceCopyWith<$Res> {
  __$BlePairedDeviceCopyWithImpl(this._self, this._then);

  final _BlePairedDevice _self;
  final $Res Function(_BlePairedDevice) _then;

/// Create a copy of BlePairedDevice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceId = freezed,Object? remoteId = null,Object? name = null,Object? displayModel = freezed,Object? modelCode = freezed,Object? lastRssi = freezed,Object? lastConnectedAt = freezed,Object? isPreferred = null,}) {
  return _then(_BlePairedDevice(
deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,remoteId: null == remoteId ? _self.remoteId : remoteId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayModel: freezed == displayModel ? _self.displayModel : displayModel // ignore: cast_nullable_to_non_nullable
as String?,modelCode: freezed == modelCode ? _self.modelCode : modelCode // ignore: cast_nullable_to_non_nullable
as String?,lastRssi: freezed == lastRssi ? _self.lastRssi : lastRssi // ignore: cast_nullable_to_non_nullable
as int?,lastConnectedAt: freezed == lastConnectedAt ? _self.lastConnectedAt : lastConnectedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isPreferred: null == isPreferred ? _self.isPreferred : isPreferred // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
