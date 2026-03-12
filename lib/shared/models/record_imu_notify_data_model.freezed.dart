// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'record_imu_notify_data_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RecordImuNotifyDataModel {

 int get timestamp; int get ax; int get ay; int get az; int get gx; int get gy; int get gz; int get pressure;@JsonKey(name: 'wear_status') bool get wearStatus;@JsonKey(name: 'battery_percent') int get batteryPercent;
/// Create a copy of RecordImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecordImuNotifyDataModelCopyWith<RecordImuNotifyDataModel> get copyWith => _$RecordImuNotifyDataModelCopyWithImpl<RecordImuNotifyDataModel>(this as RecordImuNotifyDataModel, _$identity);

  /// Serializes this RecordImuNotifyDataModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecordImuNotifyDataModel&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.ax, ax) || other.ax == ax)&&(identical(other.ay, ay) || other.ay == ay)&&(identical(other.az, az) || other.az == az)&&(identical(other.gx, gx) || other.gx == gx)&&(identical(other.gy, gy) || other.gy == gy)&&(identical(other.gz, gz) || other.gz == gz)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.wearStatus, wearStatus) || other.wearStatus == wearStatus)&&(identical(other.batteryPercent, batteryPercent) || other.batteryPercent == batteryPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,ax,ay,az,gx,gy,gz,pressure,wearStatus,batteryPercent);

@override
String toString() {
  return 'RecordImuNotifyDataModel(timestamp: $timestamp, ax: $ax, ay: $ay, az: $az, gx: $gx, gy: $gy, gz: $gz, pressure: $pressure, wearStatus: $wearStatus, batteryPercent: $batteryPercent)';
}


}

/// @nodoc
abstract mixin class $RecordImuNotifyDataModelCopyWith<$Res>  {
  factory $RecordImuNotifyDataModelCopyWith(RecordImuNotifyDataModel value, $Res Function(RecordImuNotifyDataModel) _then) = _$RecordImuNotifyDataModelCopyWithImpl;
@useResult
$Res call({
 int timestamp, int ax, int ay, int az, int gx, int gy, int gz, int pressure,@JsonKey(name: 'wear_status') bool wearStatus,@JsonKey(name: 'battery_percent') int batteryPercent
});




}
/// @nodoc
class _$RecordImuNotifyDataModelCopyWithImpl<$Res>
    implements $RecordImuNotifyDataModelCopyWith<$Res> {
  _$RecordImuNotifyDataModelCopyWithImpl(this._self, this._then);

  final RecordImuNotifyDataModel _self;
  final $Res Function(RecordImuNotifyDataModel) _then;

/// Create a copy of RecordImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? ax = null,Object? ay = null,Object? az = null,Object? gx = null,Object? gy = null,Object? gz = null,Object? pressure = null,Object? wearStatus = null,Object? batteryPercent = null,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,ax: null == ax ? _self.ax : ax // ignore: cast_nullable_to_non_nullable
as int,ay: null == ay ? _self.ay : ay // ignore: cast_nullable_to_non_nullable
as int,az: null == az ? _self.az : az // ignore: cast_nullable_to_non_nullable
as int,gx: null == gx ? _self.gx : gx // ignore: cast_nullable_to_non_nullable
as int,gy: null == gy ? _self.gy : gy // ignore: cast_nullable_to_non_nullable
as int,gz: null == gz ? _self.gz : gz // ignore: cast_nullable_to_non_nullable
as int,pressure: null == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int,wearStatus: null == wearStatus ? _self.wearStatus : wearStatus // ignore: cast_nullable_to_non_nullable
as bool,batteryPercent: null == batteryPercent ? _self.batteryPercent : batteryPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RecordImuNotifyDataModel].
extension RecordImuNotifyDataModelPatterns on RecordImuNotifyDataModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecordImuNotifyDataModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecordImuNotifyDataModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecordImuNotifyDataModel value)  $default,){
final _that = this;
switch (_that) {
case _RecordImuNotifyDataModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecordImuNotifyDataModel value)?  $default,){
final _that = this;
switch (_that) {
case _RecordImuNotifyDataModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int timestamp,  int ax,  int ay,  int az,  int gx,  int gy,  int gz,  int pressure, @JsonKey(name: 'wear_status')  bool wearStatus, @JsonKey(name: 'battery_percent')  int batteryPercent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecordImuNotifyDataModel() when $default != null:
return $default(_that.timestamp,_that.ax,_that.ay,_that.az,_that.gx,_that.gy,_that.gz,_that.pressure,_that.wearStatus,_that.batteryPercent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int timestamp,  int ax,  int ay,  int az,  int gx,  int gy,  int gz,  int pressure, @JsonKey(name: 'wear_status')  bool wearStatus, @JsonKey(name: 'battery_percent')  int batteryPercent)  $default,) {final _that = this;
switch (_that) {
case _RecordImuNotifyDataModel():
return $default(_that.timestamp,_that.ax,_that.ay,_that.az,_that.gx,_that.gy,_that.gz,_that.pressure,_that.wearStatus,_that.batteryPercent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int timestamp,  int ax,  int ay,  int az,  int gx,  int gy,  int gz,  int pressure, @JsonKey(name: 'wear_status')  bool wearStatus, @JsonKey(name: 'battery_percent')  int batteryPercent)?  $default,) {final _that = this;
switch (_that) {
case _RecordImuNotifyDataModel() when $default != null:
return $default(_that.timestamp,_that.ax,_that.ay,_that.az,_that.gx,_that.gy,_that.gz,_that.pressure,_that.wearStatus,_that.batteryPercent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecordImuNotifyDataModel implements RecordImuNotifyDataModel {
  const _RecordImuNotifyDataModel({required this.timestamp, required this.ax, required this.ay, required this.az, required this.gx, required this.gy, required this.gz, required this.pressure, @JsonKey(name: 'wear_status') required this.wearStatus, @JsonKey(name: 'battery_percent') required this.batteryPercent});
  factory _RecordImuNotifyDataModel.fromJson(Map<String, dynamic> json) => _$RecordImuNotifyDataModelFromJson(json);

@override final  int timestamp;
@override final  int ax;
@override final  int ay;
@override final  int az;
@override final  int gx;
@override final  int gy;
@override final  int gz;
@override final  int pressure;
@override@JsonKey(name: 'wear_status') final  bool wearStatus;
@override@JsonKey(name: 'battery_percent') final  int batteryPercent;

/// Create a copy of RecordImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecordImuNotifyDataModelCopyWith<_RecordImuNotifyDataModel> get copyWith => __$RecordImuNotifyDataModelCopyWithImpl<_RecordImuNotifyDataModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecordImuNotifyDataModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecordImuNotifyDataModel&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.ax, ax) || other.ax == ax)&&(identical(other.ay, ay) || other.ay == ay)&&(identical(other.az, az) || other.az == az)&&(identical(other.gx, gx) || other.gx == gx)&&(identical(other.gy, gy) || other.gy == gy)&&(identical(other.gz, gz) || other.gz == gz)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.wearStatus, wearStatus) || other.wearStatus == wearStatus)&&(identical(other.batteryPercent, batteryPercent) || other.batteryPercent == batteryPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,ax,ay,az,gx,gy,gz,pressure,wearStatus,batteryPercent);

@override
String toString() {
  return 'RecordImuNotifyDataModel(timestamp: $timestamp, ax: $ax, ay: $ay, az: $az, gx: $gx, gy: $gy, gz: $gz, pressure: $pressure, wearStatus: $wearStatus, batteryPercent: $batteryPercent)';
}


}

/// @nodoc
abstract mixin class _$RecordImuNotifyDataModelCopyWith<$Res> implements $RecordImuNotifyDataModelCopyWith<$Res> {
  factory _$RecordImuNotifyDataModelCopyWith(_RecordImuNotifyDataModel value, $Res Function(_RecordImuNotifyDataModel) _then) = __$RecordImuNotifyDataModelCopyWithImpl;
@override @useResult
$Res call({
 int timestamp, int ax, int ay, int az, int gx, int gy, int gz, int pressure,@JsonKey(name: 'wear_status') bool wearStatus,@JsonKey(name: 'battery_percent') int batteryPercent
});




}
/// @nodoc
class __$RecordImuNotifyDataModelCopyWithImpl<$Res>
    implements _$RecordImuNotifyDataModelCopyWith<$Res> {
  __$RecordImuNotifyDataModelCopyWithImpl(this._self, this._then);

  final _RecordImuNotifyDataModel _self;
  final $Res Function(_RecordImuNotifyDataModel) _then;

/// Create a copy of RecordImuNotifyDataModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? ax = null,Object? ay = null,Object? az = null,Object? gx = null,Object? gy = null,Object? gz = null,Object? pressure = null,Object? wearStatus = null,Object? batteryPercent = null,}) {
  return _then(_RecordImuNotifyDataModel(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,ax: null == ax ? _self.ax : ax // ignore: cast_nullable_to_non_nullable
as int,ay: null == ay ? _self.ay : ay // ignore: cast_nullable_to_non_nullable
as int,az: null == az ? _self.az : az // ignore: cast_nullable_to_non_nullable
as int,gx: null == gx ? _self.gx : gx // ignore: cast_nullable_to_non_nullable
as int,gy: null == gy ? _self.gy : gy // ignore: cast_nullable_to_non_nullable
as int,gz: null == gz ? _self.gz : gz // ignore: cast_nullable_to_non_nullable
as int,pressure: null == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int,wearStatus: null == wearStatus ? _self.wearStatus : wearStatus // ignore: cast_nullable_to_non_nullable
as bool,batteryPercent: null == batteryPercent ? _self.batteryPercent : batteryPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
