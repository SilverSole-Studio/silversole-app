// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_location_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceLocationModel {

@JsonKey(includeToJson: false) int? get id;@JsonKey(name: 'device_id') String get deviceId;@JsonKey(name: 'received_at', includeToJson: false) DateTime get receivedAt;@JsonKey(name: 'client_ts') DateTime? get clientCreatedAt; double get lat; double get lng;@JsonKey(name: 'accuracy_m') double? get accuracy;
/// Create a copy of DeviceLocationModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceLocationModelCopyWith<DeviceLocationModel> get copyWith => _$DeviceLocationModelCopyWithImpl<DeviceLocationModel>(this as DeviceLocationModel, _$identity);

  /// Serializes this DeviceLocationModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceLocationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.clientCreatedAt, clientCreatedAt) || other.clientCreatedAt == clientCreatedAt)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,receivedAt,clientCreatedAt,lat,lng,accuracy);

@override
String toString() {
  return 'DeviceLocationModel(id: $id, deviceId: $deviceId, receivedAt: $receivedAt, clientCreatedAt: $clientCreatedAt, lat: $lat, lng: $lng, accuracy: $accuracy)';
}


}

/// @nodoc
abstract mixin class $DeviceLocationModelCopyWith<$Res>  {
  factory $DeviceLocationModelCopyWith(DeviceLocationModel value, $Res Function(DeviceLocationModel) _then) = _$DeviceLocationModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(includeToJson: false) int? id,@JsonKey(name: 'device_id') String deviceId,@JsonKey(name: 'received_at', includeToJson: false) DateTime receivedAt,@JsonKey(name: 'client_ts') DateTime? clientCreatedAt, double lat, double lng,@JsonKey(name: 'accuracy_m') double? accuracy
});




}
/// @nodoc
class _$DeviceLocationModelCopyWithImpl<$Res>
    implements $DeviceLocationModelCopyWith<$Res> {
  _$DeviceLocationModelCopyWithImpl(this._self, this._then);

  final DeviceLocationModel _self;
  final $Res Function(DeviceLocationModel) _then;

/// Create a copy of DeviceLocationModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? deviceId = null,Object? receivedAt = null,Object? clientCreatedAt = freezed,Object? lat = null,Object? lng = null,Object? accuracy = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,clientCreatedAt: freezed == clientCreatedAt ? _self.clientCreatedAt : clientCreatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,accuracy: freezed == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceLocationModel].
extension DeviceLocationModelPatterns on DeviceLocationModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceLocationModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceLocationModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceLocationModel value)  $default,){
final _that = this;
switch (_that) {
case _DeviceLocationModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceLocationModel value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceLocationModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  int? id, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'received_at', includeToJson: false)  DateTime receivedAt, @JsonKey(name: 'client_ts')  DateTime? clientCreatedAt,  double lat,  double lng, @JsonKey(name: 'accuracy_m')  double? accuracy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceLocationModel() when $default != null:
return $default(_that.id,_that.deviceId,_that.receivedAt,_that.clientCreatedAt,_that.lat,_that.lng,_that.accuracy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(includeToJson: false)  int? id, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'received_at', includeToJson: false)  DateTime receivedAt, @JsonKey(name: 'client_ts')  DateTime? clientCreatedAt,  double lat,  double lng, @JsonKey(name: 'accuracy_m')  double? accuracy)  $default,) {final _that = this;
switch (_that) {
case _DeviceLocationModel():
return $default(_that.id,_that.deviceId,_that.receivedAt,_that.clientCreatedAt,_that.lat,_that.lng,_that.accuracy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(includeToJson: false)  int? id, @JsonKey(name: 'device_id')  String deviceId, @JsonKey(name: 'received_at', includeToJson: false)  DateTime receivedAt, @JsonKey(name: 'client_ts')  DateTime? clientCreatedAt,  double lat,  double lng, @JsonKey(name: 'accuracy_m')  double? accuracy)?  $default,) {final _that = this;
switch (_that) {
case _DeviceLocationModel() when $default != null:
return $default(_that.id,_that.deviceId,_that.receivedAt,_that.clientCreatedAt,_that.lat,_that.lng,_that.accuracy);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceLocationModel implements DeviceLocationModel {
  const _DeviceLocationModel({@JsonKey(includeToJson: false) this.id, @JsonKey(name: 'device_id') required this.deviceId, @JsonKey(name: 'received_at', includeToJson: false) required this.receivedAt, @JsonKey(name: 'client_ts') this.clientCreatedAt, required this.lat, required this.lng, @JsonKey(name: 'accuracy_m') this.accuracy});
  factory _DeviceLocationModel.fromJson(Map<String, dynamic> json) => _$DeviceLocationModelFromJson(json);

@override@JsonKey(includeToJson: false) final  int? id;
@override@JsonKey(name: 'device_id') final  String deviceId;
@override@JsonKey(name: 'received_at', includeToJson: false) final  DateTime receivedAt;
@override@JsonKey(name: 'client_ts') final  DateTime? clientCreatedAt;
@override final  double lat;
@override final  double lng;
@override@JsonKey(name: 'accuracy_m') final  double? accuracy;

/// Create a copy of DeviceLocationModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceLocationModelCopyWith<_DeviceLocationModel> get copyWith => __$DeviceLocationModelCopyWithImpl<_DeviceLocationModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceLocationModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceLocationModel&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.clientCreatedAt, clientCreatedAt) || other.clientCreatedAt == clientCreatedAt)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,receivedAt,clientCreatedAt,lat,lng,accuracy);

@override
String toString() {
  return 'DeviceLocationModel(id: $id, deviceId: $deviceId, receivedAt: $receivedAt, clientCreatedAt: $clientCreatedAt, lat: $lat, lng: $lng, accuracy: $accuracy)';
}


}

/// @nodoc
abstract mixin class _$DeviceLocationModelCopyWith<$Res> implements $DeviceLocationModelCopyWith<$Res> {
  factory _$DeviceLocationModelCopyWith(_DeviceLocationModel value, $Res Function(_DeviceLocationModel) _then) = __$DeviceLocationModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(includeToJson: false) int? id,@JsonKey(name: 'device_id') String deviceId,@JsonKey(name: 'received_at', includeToJson: false) DateTime receivedAt,@JsonKey(name: 'client_ts') DateTime? clientCreatedAt, double lat, double lng,@JsonKey(name: 'accuracy_m') double? accuracy
});




}
/// @nodoc
class __$DeviceLocationModelCopyWithImpl<$Res>
    implements _$DeviceLocationModelCopyWith<$Res> {
  __$DeviceLocationModelCopyWithImpl(this._self, this._then);

  final _DeviceLocationModel _self;
  final $Res Function(_DeviceLocationModel) _then;

/// Create a copy of DeviceLocationModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? deviceId = null,Object? receivedAt = null,Object? clientCreatedAt = freezed,Object? lat = null,Object? lng = null,Object? accuracy = freezed,}) {
  return _then(_DeviceLocationModel(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,clientCreatedAt: freezed == clientCreatedAt ? _self.clientCreatedAt : clientCreatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,accuracy: freezed == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
