// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'queued_telemetry_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$QueuedTelemetry {

 String get id; String get deviceId; String get type; Map<String, dynamic> get payload; DateTime get createAt; int get retryCount;
/// Create a copy of QueuedTelemetry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QueuedTelemetryCopyWith<QueuedTelemetry> get copyWith => _$QueuedTelemetryCopyWithImpl<QueuedTelemetry>(this as QueuedTelemetry, _$identity);

  /// Serializes this QueuedTelemetry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QueuedTelemetry&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.createAt, createAt) || other.createAt == createAt)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,type,const DeepCollectionEquality().hash(payload),createAt,retryCount);

@override
String toString() {
  return 'QueuedTelemetry(id: $id, deviceId: $deviceId, type: $type, payload: $payload, createAt: $createAt, retryCount: $retryCount)';
}


}

/// @nodoc
abstract mixin class $QueuedTelemetryCopyWith<$Res>  {
  factory $QueuedTelemetryCopyWith(QueuedTelemetry value, $Res Function(QueuedTelemetry) _then) = _$QueuedTelemetryCopyWithImpl;
@useResult
$Res call({
 String id, String deviceId, String type, Map<String, dynamic> payload, DateTime createAt, int retryCount
});




}
/// @nodoc
class _$QueuedTelemetryCopyWithImpl<$Res>
    implements $QueuedTelemetryCopyWith<$Res> {
  _$QueuedTelemetryCopyWithImpl(this._self, this._then);

  final QueuedTelemetry _self;
  final $Res Function(QueuedTelemetry) _then;

/// Create a copy of QueuedTelemetry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = null,Object? type = null,Object? payload = null,Object? createAt = null,Object? retryCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createAt: null == createAt ? _self.createAt : createAt // ignore: cast_nullable_to_non_nullable
as DateTime,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [QueuedTelemetry].
extension QueuedTelemetryPatterns on QueuedTelemetry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _QueuedTelemetry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _QueuedTelemetry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _QueuedTelemetry value)  $default,){
final _that = this;
switch (_that) {
case _QueuedTelemetry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _QueuedTelemetry value)?  $default,){
final _that = this;
switch (_that) {
case _QueuedTelemetry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deviceId,  String type,  Map<String, dynamic> payload,  DateTime createAt,  int retryCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _QueuedTelemetry() when $default != null:
return $default(_that.id,_that.deviceId,_that.type,_that.payload,_that.createAt,_that.retryCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deviceId,  String type,  Map<String, dynamic> payload,  DateTime createAt,  int retryCount)  $default,) {final _that = this;
switch (_that) {
case _QueuedTelemetry():
return $default(_that.id,_that.deviceId,_that.type,_that.payload,_that.createAt,_that.retryCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deviceId,  String type,  Map<String, dynamic> payload,  DateTime createAt,  int retryCount)?  $default,) {final _that = this;
switch (_that) {
case _QueuedTelemetry() when $default != null:
return $default(_that.id,_that.deviceId,_that.type,_that.payload,_that.createAt,_that.retryCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _QueuedTelemetry implements QueuedTelemetry {
  const _QueuedTelemetry({required this.id, required this.deviceId, required this.type, required final  Map<String, dynamic> payload, required this.createAt, this.retryCount = 0}): _payload = payload;
  factory _QueuedTelemetry.fromJson(Map<String, dynamic> json) => _$QueuedTelemetryFromJson(json);

@override final  String id;
@override final  String deviceId;
@override final  String type;
 final  Map<String, dynamic> _payload;
@override Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override final  DateTime createAt;
@override@JsonKey() final  int retryCount;

/// Create a copy of QueuedTelemetry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QueuedTelemetryCopyWith<_QueuedTelemetry> get copyWith => __$QueuedTelemetryCopyWithImpl<_QueuedTelemetry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QueuedTelemetryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _QueuedTelemetry&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.createAt, createAt) || other.createAt == createAt)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,type,const DeepCollectionEquality().hash(_payload),createAt,retryCount);

@override
String toString() {
  return 'QueuedTelemetry(id: $id, deviceId: $deviceId, type: $type, payload: $payload, createAt: $createAt, retryCount: $retryCount)';
}


}

/// @nodoc
abstract mixin class _$QueuedTelemetryCopyWith<$Res> implements $QueuedTelemetryCopyWith<$Res> {
  factory _$QueuedTelemetryCopyWith(_QueuedTelemetry value, $Res Function(_QueuedTelemetry) _then) = __$QueuedTelemetryCopyWithImpl;
@override @useResult
$Res call({
 String id, String deviceId, String type, Map<String, dynamic> payload, DateTime createAt, int retryCount
});




}
/// @nodoc
class __$QueuedTelemetryCopyWithImpl<$Res>
    implements _$QueuedTelemetryCopyWith<$Res> {
  __$QueuedTelemetryCopyWithImpl(this._self, this._then);

  final _QueuedTelemetry _self;
  final $Res Function(_QueuedTelemetry) _then;

/// Create a copy of QueuedTelemetry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = null,Object? type = null,Object? payload = null,Object? createAt = null,Object? retryCount = null,}) {
  return _then(_QueuedTelemetry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createAt: null == createAt ? _self.createAt : createAt // ignore: cast_nullable_to_non_nullable
as DateTime,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
