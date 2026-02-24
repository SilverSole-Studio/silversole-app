// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'imu_notify_data_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ImuNotifyDataModel {

 int get ax; int get ay; int get az; int get gx; int get gy; int get gz; double? get pitch; double? get roll; int get pressure;@JsonKey(name: 'battery_percent') int get batteryPercent;@JsonKey(name: 'is_charging') bool get isCharging;
/// Create a copy of ImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImuNotifyDataModelCopyWith<ImuNotifyDataModel> get copyWith => _$ImuNotifyDataModelCopyWithImpl<ImuNotifyDataModel>(this as ImuNotifyDataModel, _$identity);

  /// Serializes this ImuNotifyDataModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImuNotifyDataModel&&(identical(other.ax, ax) || other.ax == ax)&&(identical(other.ay, ay) || other.ay == ay)&&(identical(other.az, az) || other.az == az)&&(identical(other.gx, gx) || other.gx == gx)&&(identical(other.gy, gy) || other.gy == gy)&&(identical(other.gz, gz) || other.gz == gz)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.roll, roll) || other.roll == roll)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.batteryPercent, batteryPercent) || other.batteryPercent == batteryPercent)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ax,ay,az,gx,gy,gz,pitch,roll,pressure,batteryPercent,isCharging);

@override
String toString() {
  return 'ImuNotifyDataModel(ax: $ax, ay: $ay, az: $az, gx: $gx, gy: $gy, gz: $gz, pitch: $pitch, roll: $roll, pressure: $pressure, batteryPercent: $batteryPercent, isCharging: $isCharging)';
}


}

/// @nodoc
abstract mixin class $ImuNotifyDataModelCopyWith<$Res>  {
  factory $ImuNotifyDataModelCopyWith(ImuNotifyDataModel value, $Res Function(ImuNotifyDataModel) _then) = _$ImuNotifyDataModelCopyWithImpl;
@useResult
$Res call({
 int ax, int ay, int az, int gx, int gy, int gz, double? pitch, double? roll, int pressure,@JsonKey(name: 'battery_percent') int batteryPercent,@JsonKey(name: 'is_charging') bool isCharging
});




}
/// @nodoc
class _$ImuNotifyDataModelCopyWithImpl<$Res>
    implements $ImuNotifyDataModelCopyWith<$Res> {
  _$ImuNotifyDataModelCopyWithImpl(this._self, this._then);

  final ImuNotifyDataModel _self;
  final $Res Function(ImuNotifyDataModel) _then;

/// Create a copy of ImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ax = null,Object? ay = null,Object? az = null,Object? gx = null,Object? gy = null,Object? gz = null,Object? pitch = freezed,Object? roll = freezed,Object? pressure = null,Object? batteryPercent = null,Object? isCharging = null,}) {
  return _then(_self.copyWith(
ax: null == ax ? _self.ax : ax // ignore: cast_nullable_to_non_nullable
as int,ay: null == ay ? _self.ay : ay // ignore: cast_nullable_to_non_nullable
as int,az: null == az ? _self.az : az // ignore: cast_nullable_to_non_nullable
as int,gx: null == gx ? _self.gx : gx // ignore: cast_nullable_to_non_nullable
as int,gy: null == gy ? _self.gy : gy // ignore: cast_nullable_to_non_nullable
as int,gz: null == gz ? _self.gz : gz // ignore: cast_nullable_to_non_nullable
as int,pitch: freezed == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double?,roll: freezed == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
as double?,pressure: null == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int,batteryPercent: null == batteryPercent ? _self.batteryPercent : batteryPercent // ignore: cast_nullable_to_non_nullable
as int,isCharging: null == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ImuNotifyDataModel].
extension ImuNotifyDataModelPatterns on ImuNotifyDataModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImuNotifyDataModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImuNotifyDataModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImuNotifyDataModel value)  $default,){
final _that = this;
switch (_that) {
case _ImuNotifyDataModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImuNotifyDataModel value)?  $default,){
final _that = this;
switch (_that) {
case _ImuNotifyDataModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int ax,  int ay,  int az,  int gx,  int gy,  int gz,  double? pitch,  double? roll,  int pressure, @JsonKey(name: 'battery_percent')  int batteryPercent, @JsonKey(name: 'is_charging')  bool isCharging)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImuNotifyDataModel() when $default != null:
return $default(_that.ax,_that.ay,_that.az,_that.gx,_that.gy,_that.gz,_that.pitch,_that.roll,_that.pressure,_that.batteryPercent,_that.isCharging);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int ax,  int ay,  int az,  int gx,  int gy,  int gz,  double? pitch,  double? roll,  int pressure, @JsonKey(name: 'battery_percent')  int batteryPercent, @JsonKey(name: 'is_charging')  bool isCharging)  $default,) {final _that = this;
switch (_that) {
case _ImuNotifyDataModel():
return $default(_that.ax,_that.ay,_that.az,_that.gx,_that.gy,_that.gz,_that.pitch,_that.roll,_that.pressure,_that.batteryPercent,_that.isCharging);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int ax,  int ay,  int az,  int gx,  int gy,  int gz,  double? pitch,  double? roll,  int pressure, @JsonKey(name: 'battery_percent')  int batteryPercent, @JsonKey(name: 'is_charging')  bool isCharging)?  $default,) {final _that = this;
switch (_that) {
case _ImuNotifyDataModel() when $default != null:
return $default(_that.ax,_that.ay,_that.az,_that.gx,_that.gy,_that.gz,_that.pitch,_that.roll,_that.pressure,_that.batteryPercent,_that.isCharging);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ImuNotifyDataModel implements ImuNotifyDataModel {
  const _ImuNotifyDataModel({required this.ax, required this.ay, required this.az, required this.gx, required this.gy, required this.gz, this.pitch, this.roll, required this.pressure, @JsonKey(name: 'battery_percent') required this.batteryPercent, @JsonKey(name: 'is_charging') required this.isCharging});
  factory _ImuNotifyDataModel.fromJson(Map<String, dynamic> json) => _$ImuNotifyDataModelFromJson(json);

@override final  int ax;
@override final  int ay;
@override final  int az;
@override final  int gx;
@override final  int gy;
@override final  int gz;
@override final  double? pitch;
@override final  double? roll;
@override final  int pressure;
@override@JsonKey(name: 'battery_percent') final  int batteryPercent;
@override@JsonKey(name: 'is_charging') final  bool isCharging;

/// Create a copy of ImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImuNotifyDataModelCopyWith<_ImuNotifyDataModel> get copyWith => __$ImuNotifyDataModelCopyWithImpl<_ImuNotifyDataModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImuNotifyDataModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImuNotifyDataModel&&(identical(other.ax, ax) || other.ax == ax)&&(identical(other.ay, ay) || other.ay == ay)&&(identical(other.az, az) || other.az == az)&&(identical(other.gx, gx) || other.gx == gx)&&(identical(other.gy, gy) || other.gy == gy)&&(identical(other.gz, gz) || other.gz == gz)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.roll, roll) || other.roll == roll)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.batteryPercent, batteryPercent) || other.batteryPercent == batteryPercent)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,ax,ay,az,gx,gy,gz,pitch,roll,pressure,batteryPercent,isCharging);

@override
String toString() {
  return 'ImuNotifyDataModel(ax: $ax, ay: $ay, az: $az, gx: $gx, gy: $gy, gz: $gz, pitch: $pitch, roll: $roll, pressure: $pressure, batteryPercent: $batteryPercent, isCharging: $isCharging)';
}


}

/// @nodoc
abstract mixin class _$ImuNotifyDataModelCopyWith<$Res> implements $ImuNotifyDataModelCopyWith<$Res> {
  factory _$ImuNotifyDataModelCopyWith(_ImuNotifyDataModel value, $Res Function(_ImuNotifyDataModel) _then) = __$ImuNotifyDataModelCopyWithImpl;
@override @useResult
$Res call({
 int ax, int ay, int az, int gx, int gy, int gz, double? pitch, double? roll, int pressure,@JsonKey(name: 'battery_percent') int batteryPercent,@JsonKey(name: 'is_charging') bool isCharging
});




}
/// @nodoc
class __$ImuNotifyDataModelCopyWithImpl<$Res>
    implements _$ImuNotifyDataModelCopyWith<$Res> {
  __$ImuNotifyDataModelCopyWithImpl(this._self, this._then);

  final _ImuNotifyDataModel _self;
  final $Res Function(_ImuNotifyDataModel) _then;

/// Create a copy of ImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ax = null,Object? ay = null,Object? az = null,Object? gx = null,Object? gy = null,Object? gz = null,Object? pitch = freezed,Object? roll = freezed,Object? pressure = null,Object? batteryPercent = null,Object? isCharging = null,}) {
  return _then(_ImuNotifyDataModel(
ax: null == ax ? _self.ax : ax // ignore: cast_nullable_to_non_nullable
as int,ay: null == ay ? _self.ay : ay // ignore: cast_nullable_to_non_nullable
as int,az: null == az ? _self.az : az // ignore: cast_nullable_to_non_nullable
as int,gx: null == gx ? _self.gx : gx // ignore: cast_nullable_to_non_nullable
as int,gy: null == gy ? _self.gy : gy // ignore: cast_nullable_to_non_nullable
as int,gz: null == gz ? _self.gz : gz // ignore: cast_nullable_to_non_nullable
as int,pitch: freezed == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double?,roll: freezed == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
as double?,pressure: null == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int,batteryPercent: null == batteryPercent ? _self.batteryPercent : batteryPercent // ignore: cast_nullable_to_non_nullable
as int,isCharging: null == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
