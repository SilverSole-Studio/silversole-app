// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_status_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceStatusBodyModel {

@JsonKey(name: 'battery_percent') int get batteryPercent;@JsonKey(name: 'is_charging') bool get isCharging;
/// Create a copy of DeviceStatusBodyModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceStatusBodyModelCopyWith<DeviceStatusBodyModel> get copyWith => _$DeviceStatusBodyModelCopyWithImpl<DeviceStatusBodyModel>(this as DeviceStatusBodyModel, _$identity);

  /// Serializes this DeviceStatusBodyModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceStatusBodyModel&&(identical(other.batteryPercent, batteryPercent) || other.batteryPercent == batteryPercent)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,batteryPercent,isCharging);

@override
String toString() {
  return 'DeviceStatusBodyModel(batteryPercent: $batteryPercent, isCharging: $isCharging)';
}


}

/// @nodoc
abstract mixin class $DeviceStatusBodyModelCopyWith<$Res>  {
  factory $DeviceStatusBodyModelCopyWith(DeviceStatusBodyModel value, $Res Function(DeviceStatusBodyModel) _then) = _$DeviceStatusBodyModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'battery_percent') int batteryPercent,@JsonKey(name: 'is_charging') bool isCharging
});




}
/// @nodoc
class _$DeviceStatusBodyModelCopyWithImpl<$Res>
    implements $DeviceStatusBodyModelCopyWith<$Res> {
  _$DeviceStatusBodyModelCopyWithImpl(this._self, this._then);

  final DeviceStatusBodyModel _self;
  final $Res Function(DeviceStatusBodyModel) _then;

/// Create a copy of DeviceStatusBodyModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? batteryPercent = null,Object? isCharging = null,}) {
  return _then(_self.copyWith(
batteryPercent: null == batteryPercent ? _self.batteryPercent : batteryPercent // ignore: cast_nullable_to_non_nullable
as int,isCharging: null == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceStatusBodyModel].
extension DeviceStatusBodyModelPatterns on DeviceStatusBodyModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceStatusBodyModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceStatusBodyModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceStatusBodyModel value)  $default,){
final _that = this;
switch (_that) {
case _DeviceStatusBodyModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceStatusBodyModel value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceStatusBodyModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'battery_percent')  int batteryPercent, @JsonKey(name: 'is_charging')  bool isCharging)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceStatusBodyModel() when $default != null:
return $default(_that.batteryPercent,_that.isCharging);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'battery_percent')  int batteryPercent, @JsonKey(name: 'is_charging')  bool isCharging)  $default,) {final _that = this;
switch (_that) {
case _DeviceStatusBodyModel():
return $default(_that.batteryPercent,_that.isCharging);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'battery_percent')  int batteryPercent, @JsonKey(name: 'is_charging')  bool isCharging)?  $default,) {final _that = this;
switch (_that) {
case _DeviceStatusBodyModel() when $default != null:
return $default(_that.batteryPercent,_that.isCharging);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceStatusBodyModel implements DeviceStatusBodyModel {
  const _DeviceStatusBodyModel({@JsonKey(name: 'battery_percent') required this.batteryPercent, @JsonKey(name: 'is_charging') required this.isCharging});
  factory _DeviceStatusBodyModel.fromJson(Map<String, dynamic> json) => _$DeviceStatusBodyModelFromJson(json);

@override@JsonKey(name: 'battery_percent') final  int batteryPercent;
@override@JsonKey(name: 'is_charging') final  bool isCharging;

/// Create a copy of DeviceStatusBodyModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceStatusBodyModelCopyWith<_DeviceStatusBodyModel> get copyWith => __$DeviceStatusBodyModelCopyWithImpl<_DeviceStatusBodyModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceStatusBodyModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceStatusBodyModel&&(identical(other.batteryPercent, batteryPercent) || other.batteryPercent == batteryPercent)&&(identical(other.isCharging, isCharging) || other.isCharging == isCharging));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,batteryPercent,isCharging);

@override
String toString() {
  return 'DeviceStatusBodyModel(batteryPercent: $batteryPercent, isCharging: $isCharging)';
}


}

/// @nodoc
abstract mixin class _$DeviceStatusBodyModelCopyWith<$Res> implements $DeviceStatusBodyModelCopyWith<$Res> {
  factory _$DeviceStatusBodyModelCopyWith(_DeviceStatusBodyModel value, $Res Function(_DeviceStatusBodyModel) _then) = __$DeviceStatusBodyModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'battery_percent') int batteryPercent,@JsonKey(name: 'is_charging') bool isCharging
});




}
/// @nodoc
class __$DeviceStatusBodyModelCopyWithImpl<$Res>
    implements _$DeviceStatusBodyModelCopyWith<$Res> {
  __$DeviceStatusBodyModelCopyWithImpl(this._self, this._then);

  final _DeviceStatusBodyModel _self;
  final $Res Function(_DeviceStatusBodyModel) _then;

/// Create a copy of DeviceStatusBodyModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? batteryPercent = null,Object? isCharging = null,}) {
  return _then(_DeviceStatusBodyModel(
batteryPercent: null == batteryPercent ? _self.batteryPercent : batteryPercent // ignore: cast_nullable_to_non_nullable
as int,isCharging: null == isCharging ? _self.isCharging : isCharging // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DeviceStatusModel {

 String get signature;@JsonKey(name: 'device_id') String get deviceId; int get timestamp; DeviceStatusBodyModel get body;
/// Create a copy of DeviceStatusModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceStatusModelCopyWith<DeviceStatusModel> get copyWith => _$DeviceStatusModelCopyWithImpl<DeviceStatusModel>(this as DeviceStatusModel, _$identity);

  /// Serializes this DeviceStatusModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceStatusModel&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,signature,deviceId,timestamp,body);

@override
String toString() {
  return 'DeviceStatusModel(signature: $signature, deviceId: $deviceId, timestamp: $timestamp, body: $body)';
}


}

/// @nodoc
abstract mixin class $DeviceStatusModelCopyWith<$Res>  {
  factory $DeviceStatusModelCopyWith(DeviceStatusModel value, $Res Function(DeviceStatusModel) _then) = _$DeviceStatusModelCopyWithImpl;
@useResult
$Res call({
 String signature,@JsonKey(name: 'device_id') String deviceId, int timestamp, DeviceStatusBodyModel body
});


$DeviceStatusBodyModelCopyWith<$Res> get body;

}
/// @nodoc
class _$DeviceStatusModelCopyWithImpl<$Res>
    implements $DeviceStatusModelCopyWith<$Res> {
  _$DeviceStatusModelCopyWithImpl(this._self, this._then);

  final DeviceStatusModel _self;
  final $Res Function(DeviceStatusModel) _then;

/// Create a copy of DeviceStatusModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? signature = null,Object? deviceId = null,Object? timestamp = null,Object? body = null,}) {
  return _then(_self.copyWith(
signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as DeviceStatusBodyModel,
  ));
}
/// Create a copy of DeviceStatusModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceStatusBodyModelCopyWith<$Res> get body {
  
  return $DeviceStatusBodyModelCopyWith<$Res>(_self.body, (value) {
    return _then(_self.copyWith(body: value));
  });
}
}


/// Adds pattern-matching-related methods to [DeviceStatusModel].
extension DeviceStatusModelPatterns on DeviceStatusModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceStatusModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceStatusModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceStatusModel value)  $default,){
final _that = this;
switch (_that) {
case _DeviceStatusModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceStatusModel value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceStatusModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String signature, @JsonKey(name: 'device_id')  String deviceId,  int timestamp,  DeviceStatusBodyModel body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceStatusModel() when $default != null:
return $default(_that.signature,_that.deviceId,_that.timestamp,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String signature, @JsonKey(name: 'device_id')  String deviceId,  int timestamp,  DeviceStatusBodyModel body)  $default,) {final _that = this;
switch (_that) {
case _DeviceStatusModel():
return $default(_that.signature,_that.deviceId,_that.timestamp,_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String signature, @JsonKey(name: 'device_id')  String deviceId,  int timestamp,  DeviceStatusBodyModel body)?  $default,) {final _that = this;
switch (_that) {
case _DeviceStatusModel() when $default != null:
return $default(_that.signature,_that.deviceId,_that.timestamp,_that.body);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceStatusModel implements DeviceStatusModel {
  const _DeviceStatusModel({required this.signature, @JsonKey(name: 'device_id') required this.deviceId, required this.timestamp, required this.body});
  factory _DeviceStatusModel.fromJson(Map<String, dynamic> json) => _$DeviceStatusModelFromJson(json);

@override final  String signature;
@override@JsonKey(name: 'device_id') final  String deviceId;
@override final  int timestamp;
@override final  DeviceStatusBodyModel body;

/// Create a copy of DeviceStatusModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceStatusModelCopyWith<_DeviceStatusModel> get copyWith => __$DeviceStatusModelCopyWithImpl<_DeviceStatusModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceStatusModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceStatusModel&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,signature,deviceId,timestamp,body);

@override
String toString() {
  return 'DeviceStatusModel(signature: $signature, deviceId: $deviceId, timestamp: $timestamp, body: $body)';
}


}

/// @nodoc
abstract mixin class _$DeviceStatusModelCopyWith<$Res> implements $DeviceStatusModelCopyWith<$Res> {
  factory _$DeviceStatusModelCopyWith(_DeviceStatusModel value, $Res Function(_DeviceStatusModel) _then) = __$DeviceStatusModelCopyWithImpl;
@override @useResult
$Res call({
 String signature,@JsonKey(name: 'device_id') String deviceId, int timestamp, DeviceStatusBodyModel body
});


@override $DeviceStatusBodyModelCopyWith<$Res> get body;

}
/// @nodoc
class __$DeviceStatusModelCopyWithImpl<$Res>
    implements _$DeviceStatusModelCopyWith<$Res> {
  __$DeviceStatusModelCopyWithImpl(this._self, this._then);

  final _DeviceStatusModel _self;
  final $Res Function(_DeviceStatusModel) _then;

/// Create a copy of DeviceStatusModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? signature = null,Object? deviceId = null,Object? timestamp = null,Object? body = null,}) {
  return _then(_DeviceStatusModel(
signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as DeviceStatusBodyModel,
  ));
}

/// Create a copy of DeviceStatusModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeviceStatusBodyModelCopyWith<$Res> get body {
  
  return $DeviceStatusBodyModelCopyWith<$Res>(_self.body, (value) {
    return _then(_self.copyWith(body: value));
  });
}
}

// dart format on
