// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fall_detect_event_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FallDetectEvent {

 DateTime get timestamp; String get deviceId; bool get detect;
/// Create a copy of FallDetectEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FallDetectEventCopyWith<FallDetectEvent> get copyWith => _$FallDetectEventCopyWithImpl<FallDetectEvent>(this as FallDetectEvent, _$identity);

  /// Serializes this FallDetectEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FallDetectEvent&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.detect, detect) || other.detect == detect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,deviceId,detect);

@override
String toString() {
  return 'FallDetectEvent(timestamp: $timestamp, deviceId: $deviceId, detect: $detect)';
}


}

/// @nodoc
abstract mixin class $FallDetectEventCopyWith<$Res>  {
  factory $FallDetectEventCopyWith(FallDetectEvent value, $Res Function(FallDetectEvent) _then) = _$FallDetectEventCopyWithImpl;
@useResult
$Res call({
 DateTime timestamp, String deviceId, bool detect
});




}
/// @nodoc
class _$FallDetectEventCopyWithImpl<$Res>
    implements $FallDetectEventCopyWith<$Res> {
  _$FallDetectEventCopyWithImpl(this._self, this._then);

  final FallDetectEvent _self;
  final $Res Function(FallDetectEvent) _then;

/// Create a copy of FallDetectEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? deviceId = null,Object? detect = null,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,detect: null == detect ? _self.detect : detect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FallDetectEvent].
extension FallDetectEventPatterns on FallDetectEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FallDetectEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FallDetectEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FallDetectEvent value)  $default,){
final _that = this;
switch (_that) {
case _FallDetectEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FallDetectEvent value)?  $default,){
final _that = this;
switch (_that) {
case _FallDetectEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime timestamp,  String deviceId,  bool detect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FallDetectEvent() when $default != null:
return $default(_that.timestamp,_that.deviceId,_that.detect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime timestamp,  String deviceId,  bool detect)  $default,) {final _that = this;
switch (_that) {
case _FallDetectEvent():
return $default(_that.timestamp,_that.deviceId,_that.detect);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime timestamp,  String deviceId,  bool detect)?  $default,) {final _that = this;
switch (_that) {
case _FallDetectEvent() when $default != null:
return $default(_that.timestamp,_that.deviceId,_that.detect);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FallDetectEvent implements FallDetectEvent {
  const _FallDetectEvent({required this.timestamp, required this.deviceId, required this.detect});
  factory _FallDetectEvent.fromJson(Map<String, dynamic> json) => _$FallDetectEventFromJson(json);

@override final  DateTime timestamp;
@override final  String deviceId;
@override final  bool detect;

/// Create a copy of FallDetectEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FallDetectEventCopyWith<_FallDetectEvent> get copyWith => __$FallDetectEventCopyWithImpl<_FallDetectEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FallDetectEventToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FallDetectEvent&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.detect, detect) || other.detect == detect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,deviceId,detect);

@override
String toString() {
  return 'FallDetectEvent(timestamp: $timestamp, deviceId: $deviceId, detect: $detect)';
}


}

/// @nodoc
abstract mixin class _$FallDetectEventCopyWith<$Res> implements $FallDetectEventCopyWith<$Res> {
  factory _$FallDetectEventCopyWith(_FallDetectEvent value, $Res Function(_FallDetectEvent) _then) = __$FallDetectEventCopyWithImpl;
@override @useResult
$Res call({
 DateTime timestamp, String deviceId, bool detect
});




}
/// @nodoc
class __$FallDetectEventCopyWithImpl<$Res>
    implements _$FallDetectEventCopyWith<$Res> {
  __$FallDetectEventCopyWithImpl(this._self, this._then);

  final _FallDetectEvent _self;
  final $Res Function(_FallDetectEvent) _then;

/// Create a copy of FallDetectEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? deviceId = null,Object? detect = null,}) {
  return _then(_FallDetectEvent(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,detect: null == detect ? _self.detect : detect // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
