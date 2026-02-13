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

@JsonKey(includeToJson: false) int get id;@JsonKey(name: 'device_id') String get deviceId;@JsonKey(name: 'received_at', includeToJson: false) DateTime get receivedAt;@JsonKey(name: 'client_ts') int? get clientTs;@JsonKey(name: 'wear_status') bool get wearStatus;@JsonKey(name: 'pressure') int get pressure; double? get pitch; double? get roll;
/// Create a copy of SilverSoleRecordModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SilverSoleRecordModelCopyWith<SilverSoleRecordModel> get copyWith => _$SilverSoleRecordModelCopyWithImpl<SilverSoleRecordModel>(this as SilverSoleRecordModel, _$identity);

  /// Serializes this SilverSoleRecordModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SilverSoleRecordModel&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.clientTs, clientTs) || other.clientTs == clientTs)&&(identical(other.wearStatus, wearStatus) || other.wearStatus == wearStatus)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.roll, roll) || other.roll == roll));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,receivedAt,clientTs,wearStatus,pressure,pitch,roll);

@override
String toString() {
  return 'SilverSoleRecordModel(id: $id, deviceId: $deviceId, receivedAt: $receivedAt, clientTs: $clientTs, wearStatus: $wearStatus, pressure: $pressure, pitch: $pitch, roll: $roll)';
}


}

/// @nodoc
abstract mixin class $SilverSoleRecordModelCopyWith<$Res>  {
  factory $SilverSoleRecordModelCopyWith(SilverSoleRecordModel value, $Res Function(SilverSoleRecordModel) _then) = _$SilverSoleRecordModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) int id,@JsonKey(name: 'device_id') String deviceId,@JsonKey(name: 'received_at', includeToJson: false) DateTime receivedAt,@JsonKey(name: 'client_ts') int? clientTs,@JsonKey(name: 'wear_status') bool wearStatus,@JsonKey(name: 'pressure') int pressure, double? pitch, double? roll
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = null,Object? receivedAt = null,Object? clientTs = freezed,Object? wearStatus = null,Object? pressure = null,Object? pitch = freezed,Object? roll = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,clientTs: freezed == clientTs ? _self.clientTs : clientTs // ignore: cast_nullable_to_non_nullable
as int?,wearStatus: null == wearStatus ? _self.wearStatus : wearStatus // ignore: cast_nullable_to_non_nullable
as bool,pressure: null == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int,pitch: freezed == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double?,roll: freezed == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  int id, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'received_at', includeToJson: false)  DateTime receivedAt, @JsonKey(name: 'client_ts')  int? clientTs, @JsonKey(name: 'wear_status')  bool wearStatus, @JsonKey(name: 'pressure')  int pressure,  double? pitch,  double? roll)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SilverSoleRecordModel() when $default != null:
return $default(_that.id,_that.deviceId,_that.receivedAt,_that.clientTs,_that.wearStatus,_that.pressure,_that.pitch,_that.roll);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  int id, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'received_at', includeToJson: false)  DateTime receivedAt, @JsonKey(name: 'client_ts')  int? clientTs, @JsonKey(name: 'wear_status')  bool wearStatus, @JsonKey(name: 'pressure')  int pressure,  double? pitch,  double? roll)  $default,) {final _that = this;
switch (_that) {
case _SilverSoleRecordModel():
return $default(_that.id,_that.deviceId,_that.receivedAt,_that.clientTs,_that.wearStatus,_that.pressure,_that.pitch,_that.roll);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  int id, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'received_at', includeToJson: false)  DateTime receivedAt, @JsonKey(name: 'client_ts')  int? clientTs, @JsonKey(name: 'wear_status')  bool wearStatus, @JsonKey(name: 'pressure')  int pressure,  double? pitch,  double? roll)?  $default,) {final _that = this;
switch (_that) {
case _SilverSoleRecordModel() when $default != null:
return $default(_that.id,_that.deviceId,_that.receivedAt,_that.clientTs,_that.wearStatus,_that.pressure,_that.pitch,_that.roll);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SilverSoleRecordModel implements SilverSoleRecordModel {
  const _SilverSoleRecordModel({@JsonKey(includeToJson: false) required this.id, @JsonKey(name: 'device_id') required this.deviceId, @JsonKey(name: 'received_at', includeToJson: false) required this.receivedAt, @JsonKey(name: 'client_ts') this.clientTs, @JsonKey(name: 'wear_status') required this.wearStatus, @JsonKey(name: 'pressure') required this.pressure, this.pitch, this.roll});
  factory _SilverSoleRecordModel.fromJson(Map<String, dynamic> json) => _$SilverSoleRecordModelFromJson(json);

@override@JsonKey(includeToJson: false) final  int id;
@override@JsonKey(name: 'device_id') final  String deviceId;
@override@JsonKey(name: 'received_at', includeToJson: false) final  DateTime receivedAt;
@override@JsonKey(name: 'client_ts') final  int? clientTs;
@override@JsonKey(name: 'wear_status') final  bool wearStatus;
@override@JsonKey(name: 'pressure') final  int pressure;
@override final  double? pitch;
@override final  double? roll;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SilverSoleRecordModel&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.clientTs, clientTs) || other.clientTs == clientTs)&&(identical(other.wearStatus, wearStatus) || other.wearStatus == wearStatus)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.roll, roll) || other.roll == roll));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,receivedAt,clientTs,wearStatus,pressure,pitch,roll);

@override
String toString() {
  return 'SilverSoleRecordModel(id: $id, deviceId: $deviceId, receivedAt: $receivedAt, clientTs: $clientTs, wearStatus: $wearStatus, pressure: $pressure, pitch: $pitch, roll: $roll)';
}


}

/// @nodoc
abstract mixin class _$SilverSoleRecordModelCopyWith<$Res> implements $SilverSoleRecordModelCopyWith<$Res> {
  factory _$SilverSoleRecordModelCopyWith(_SilverSoleRecordModel value, $Res Function(_SilverSoleRecordModel) _then) = __$SilverSoleRecordModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) int id,@JsonKey(name: 'device_id') String deviceId,@JsonKey(name: 'received_at', includeToJson: false) DateTime receivedAt,@JsonKey(name: 'client_ts') int? clientTs,@JsonKey(name: 'wear_status') bool wearStatus,@JsonKey(name: 'pressure') int pressure, double? pitch, double? roll
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = null,Object? receivedAt = null,Object? clientTs = freezed,Object? wearStatus = null,Object? pressure = null,Object? pitch = freezed,Object? roll = freezed,}) {
  return _then(_SilverSoleRecordModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,clientTs: freezed == clientTs ? _self.clientTs : clientTs // ignore: cast_nullable_to_non_nullable
as int?,wearStatus: null == wearStatus ? _self.wearStatus : wearStatus // ignore: cast_nullable_to_non_nullable
as bool,pressure: null == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as int,pitch: freezed == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double?,roll: freezed == roll ? _self.roll : roll // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
