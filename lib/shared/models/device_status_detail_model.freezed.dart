// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_status_detail_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceStatusDetailModel {

@JsonKey(name: 'last_heartbeat_at', includeToJson: false) DateTime? get lastHeartbeatAt;@JsonKey(name: 'last_battery_percent') int? get lastBatteryPercent;@JsonKey(name: 'last_battery_at', includeToJson: false) DateTime? get lastBatteryAt;@JsonKey(name: 'is_charging') bool? get isCharging;
/// Create a copy of DeviceStatusDetailModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceStatusDetailModelCopyWith<DeviceStatusDetailModel> get copyWith => _$DeviceStatusDetailModelCopyWithImpl<DeviceStatusDetailModel>(this as DeviceStatusDetailModel, _$identity);

  /// Serializes this DeviceStatusDetailModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceStatusDetailModel&&(identical(other.lastHeartbeatAt, lastHeartbeatAt) || other.lastHeartbeatAt == lastHeartbeatAt)&&(identical(other.lastBatteryPercent, lastBatteryPercent) || other.lastBatteryPercent == lastBatteryPercent)&&(identical(other.lastBatteryAt, lastBatteryAt) || other.lastBatteryAt == lastBatteryAt)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastHeartbeatAt,lastBatteryPercent,lastBatteryAt,isCharging);

@override
String toString() {
  return 'DeviceStatusDetailModel(lastHeartbeatAt: $lastHeartbeatAt, lastBatteryPercent: $lastBatteryPercent, lastBatteryAt: $lastBatteryAt, isCharging: $isCharging)';
}


}

/// @nodoc
abstract mixin class $DeviceStatusDetailModelCopyWith<$Res>  {
  factory $DeviceStatusDetailModelCopyWith(DeviceStatusDetailModel value, $Res Function(DeviceStatusDetailModel) _then) = _$DeviceStatusDetailModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'last_heartbeat_at', includeToJson: false) DateTime? lastHeartbeatAt,@JsonKey(name: 'last_battery_percent') int? lastBatteryPercent,@JsonKey(name: 'last_battery_at', includeToJson: false) DateTime? lastBatteryAt,@JsonKey(name: 'is_charging') bool? isCharging
});




}
/// @nodoc
class _$DeviceStatusDetailModelCopyWithImpl<$Res>
    implements $DeviceStatusDetailModelCopyWith<$Res> {
  _$DeviceStatusDetailModelCopyWithImpl(this._self, this._then);

  final DeviceStatusDetailModel _self;
  final $Res Function(DeviceStatusDetailModel) _then;

/// Create a copy of DeviceStatusDetailModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lastHeartbeatAt = freezed,Object? lastBatteryPercent = freezed,Object? lastBatteryAt = freezed,Object? isCharging = freezed,}) {
  return _then(_self.copyWith(
lastHeartbeatAt: freezed == lastHeartbeatAt ? _self.lastHeartbeatAt : lastHeartbeatAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastBatteryPercent: freezed == lastBatteryPercent ? _self.lastBatteryPercent : lastBatteryPercent // ignore: cast_nullable_to_non_nullable
as int?,lastBatteryAt: freezed == lastBatteryAt ? _self.lastBatteryAt : lastBatteryAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isCharging: freezed == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceStatusDetailModel].
extension DeviceStatusDetailModelPatterns on DeviceStatusDetailModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceStatusDetailModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceStatusDetailModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceStatusDetailModel value)  $default,){
final _that = this;
switch (_that) {
case _DeviceStatusDetailModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceStatusDetailModel value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceStatusDetailModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_heartbeat_at', includeToJson: false)  DateTime? lastHeartbeatAt, @JsonKey(name: 'last_battery_percent')  int? lastBatteryPercent, @JsonKey(name: 'last_battery_at', includeToJson: false)  DateTime? lastBatteryAt, @JsonKey(name: 'is_charging')  bool? isCharging)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceStatusDetailModel() when $default != null:
return $default(_that.lastHeartbeatAt,_that.lastBatteryPercent,_that.lastBatteryAt,_that.isCharging);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'last_heartbeat_at', includeToJson: false)  DateTime? lastHeartbeatAt, @JsonKey(name: 'last_battery_percent')  int? lastBatteryPercent, @JsonKey(name: 'last_battery_at', includeToJson: false)  DateTime? lastBatteryAt, @JsonKey(name: 'is_charging')  bool? isCharging)  $default,) {final _that = this;
switch (_that) {
case _DeviceStatusDetailModel():
return $default(_that.lastHeartbeatAt,_that.lastBatteryPercent,_that.lastBatteryAt,_that.isCharging);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'last_heartbeat_at', includeToJson: false)  DateTime? lastHeartbeatAt, @JsonKey(name: 'last_battery_percent')  int? lastBatteryPercent, @JsonKey(name: 'last_battery_at', includeToJson: false)  DateTime? lastBatteryAt, @JsonKey(name: 'is_charging')  bool? isCharging)?  $default,) {final _that = this;
switch (_that) {
case _DeviceStatusDetailModel() when $default != null:
return $default(_that.lastHeartbeatAt,_that.lastBatteryPercent,_that.lastBatteryAt,_that.isCharging);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceStatusDetailModel implements DeviceStatusDetailModel {
  const _DeviceStatusDetailModel({@JsonKey(name: 'last_heartbeat_at', includeToJson: false) this.lastHeartbeatAt, @JsonKey(name: 'last_battery_percent') this.lastBatteryPercent, @JsonKey(name: 'last_battery_at', includeToJson: false) this.lastBatteryAt, @JsonKey(name: 'is_charging') this.isCharging});
  factory _DeviceStatusDetailModel.fromJson(Map<String, dynamic> json) => _$DeviceStatusDetailModelFromJson(json);

@override@JsonKey(name: 'last_heartbeat_at', includeToJson: false) final  DateTime? lastHeartbeatAt;
@override@JsonKey(name: 'last_battery_percent') final  int? lastBatteryPercent;
@override@JsonKey(name: 'last_battery_at', includeToJson: false) final  DateTime? lastBatteryAt;
@override@JsonKey(name: 'is_charging') final  bool? isCharging;

/// Create a copy of DeviceStatusDetailModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceStatusDetailModelCopyWith<_DeviceStatusDetailModel> get copyWith => __$DeviceStatusDetailModelCopyWithImpl<_DeviceStatusDetailModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceStatusDetailModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceStatusDetailModel&&(identical(other.lastHeartbeatAt, lastHeartbeatAt) || other.lastHeartbeatAt == lastHeartbeatAt)&&(identical(other.lastBatteryPercent, lastBatteryPercent) || other.lastBatteryPercent == lastBatteryPercent)&&(identical(other.lastBatteryAt, lastBatteryAt) || other.lastBatteryAt == lastBatteryAt)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lastHeartbeatAt,lastBatteryPercent,lastBatteryAt,isCharging);

@override
String toString() {
  return 'DeviceStatusDetailModel(lastHeartbeatAt: $lastHeartbeatAt, lastBatteryPercent: $lastBatteryPercent, lastBatteryAt: $lastBatteryAt, isCharging: $isCharging)';
}


}

/// @nodoc
abstract mixin class _$DeviceStatusDetailModelCopyWith<$Res> implements $DeviceStatusDetailModelCopyWith<$Res> {
  factory _$DeviceStatusDetailModelCopyWith(_DeviceStatusDetailModel value, $Res Function(_DeviceStatusDetailModel) _then) = __$DeviceStatusDetailModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'last_heartbeat_at', includeToJson: false) DateTime? lastHeartbeatAt,@JsonKey(name: 'last_battery_percent') int? lastBatteryPercent,@JsonKey(name: 'last_battery_at', includeToJson: false) DateTime? lastBatteryAt,@JsonKey(name: 'is_charging') bool? isCharging
});




}
/// @nodoc
class __$DeviceStatusDetailModelCopyWithImpl<$Res>
    implements _$DeviceStatusDetailModelCopyWith<$Res> {
  __$DeviceStatusDetailModelCopyWithImpl(this._self, this._then);

  final _DeviceStatusDetailModel _self;
  final $Res Function(_DeviceStatusDetailModel) _then;

/// Create a copy of DeviceStatusDetailModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lastHeartbeatAt = freezed,Object? lastBatteryPercent = freezed,Object? lastBatteryAt = freezed,Object? isCharging = freezed,}) {
  return _then(_DeviceStatusDetailModel(
lastHeartbeatAt: freezed == lastHeartbeatAt ? _self.lastHeartbeatAt : lastHeartbeatAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastBatteryPercent: freezed == lastBatteryPercent ? _self.lastBatteryPercent : lastBatteryPercent // ignore: cast_nullable_to_non_nullable
as int?,lastBatteryAt: freezed == lastBatteryAt ? _self.lastBatteryAt : lastBatteryAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isCharging: freezed == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
