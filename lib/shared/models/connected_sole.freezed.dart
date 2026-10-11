// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'connected_sole.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConnectedSole {

 BlePairedDevice get device;/// The DFU `version`, e.g. `0.4.0-rc.1`; null when it could not be read.
 String? get firmwareVersion;/// False on firmware without the DFU service (wired updates only).
 bool get dfuSupported;
/// Create a copy of ConnectedSole
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConnectedSoleCopyWith<ConnectedSole> get copyWith => _$ConnectedSoleCopyWithImpl<ConnectedSole>(this as ConnectedSole, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConnectedSole&&(identical(other.device, device) || other.device == device)&&(identical(other.firmwareVersion, firmwareVersion) || other.firmwareVersion == firmwareVersion)&&(identical(other.dfuSupported, dfuSupported) || other.dfuSupported == dfuSupported));
}


@override
int get hashCode => Object.hash(runtimeType,device,firmwareVersion,dfuSupported);

@override
String toString() {
  return 'ConnectedSole(device: $device, firmwareVersion: $firmwareVersion, dfuSupported: $dfuSupported)';
}


}

/// @nodoc
abstract mixin class $ConnectedSoleCopyWith<$Res>  {
  factory $ConnectedSoleCopyWith(ConnectedSole value, $Res Function(ConnectedSole) _then) = _$ConnectedSoleCopyWithImpl;
@useResult
$Res call({
 BlePairedDevice device, String? firmwareVersion, bool dfuSupported
});


$BlePairedDeviceCopyWith<$Res> get device;

}
/// @nodoc
class _$ConnectedSoleCopyWithImpl<$Res>
    implements $ConnectedSoleCopyWith<$Res> {
  _$ConnectedSoleCopyWithImpl(this._self, this._then);

  final ConnectedSole _self;
  final $Res Function(ConnectedSole) _then;

/// Create a copy of ConnectedSole
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? device = null,Object? firmwareVersion = freezed,Object? dfuSupported = null,}) {
  return _then(_self.copyWith(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as BlePairedDevice,firmwareVersion: freezed == firmwareVersion ? _self.firmwareVersion : firmwareVersion // ignore: cast_nullable_to_non_nullable
as String?,dfuSupported: null == dfuSupported ? _self.dfuSupported : dfuSupported // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ConnectedSole
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlePairedDeviceCopyWith<$Res> get device {
  
  return $BlePairedDeviceCopyWith<$Res>(_self.device, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}


/// Adds pattern-matching-related methods to [ConnectedSole].
extension ConnectedSolePatterns on ConnectedSole {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConnectedSole value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConnectedSole() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConnectedSole value)  $default,){
final _that = this;
switch (_that) {
case _ConnectedSole():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConnectedSole value)?  $default,){
final _that = this;
switch (_that) {
case _ConnectedSole() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BlePairedDevice device,  String? firmwareVersion,  bool dfuSupported)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConnectedSole() when $default != null:
return $default(_that.device,_that.firmwareVersion,_that.dfuSupported);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BlePairedDevice device,  String? firmwareVersion,  bool dfuSupported)  $default,) {final _that = this;
switch (_that) {
case _ConnectedSole():
return $default(_that.device,_that.firmwareVersion,_that.dfuSupported);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BlePairedDevice device,  String? firmwareVersion,  bool dfuSupported)?  $default,) {final _that = this;
switch (_that) {
case _ConnectedSole() when $default != null:
return $default(_that.device,_that.firmwareVersion,_that.dfuSupported);case _:
  return null;

}
}

}

/// @nodoc


class _ConnectedSole implements ConnectedSole {
  const _ConnectedSole({required this.device, this.firmwareVersion, required this.dfuSupported});
  

@override final  BlePairedDevice device;
/// The DFU `version`, e.g. `0.4.0-rc.1`; null when it could not be read.
@override final  String? firmwareVersion;
/// False on firmware without the DFU service (wired updates only).
@override final  bool dfuSupported;

/// Create a copy of ConnectedSole
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConnectedSoleCopyWith<_ConnectedSole> get copyWith => __$ConnectedSoleCopyWithImpl<_ConnectedSole>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConnectedSole&&(identical(other.device, device) || other.device == device)&&(identical(other.firmwareVersion, firmwareVersion) || other.firmwareVersion == firmwareVersion)&&(identical(other.dfuSupported, dfuSupported) || other.dfuSupported == dfuSupported));
}


@override
int get hashCode => Object.hash(runtimeType,device,firmwareVersion,dfuSupported);

@override
String toString() {
  return 'ConnectedSole(device: $device, firmwareVersion: $firmwareVersion, dfuSupported: $dfuSupported)';
}


}

/// @nodoc
abstract mixin class _$ConnectedSoleCopyWith<$Res> implements $ConnectedSoleCopyWith<$Res> {
  factory _$ConnectedSoleCopyWith(_ConnectedSole value, $Res Function(_ConnectedSole) _then) = __$ConnectedSoleCopyWithImpl;
@override @useResult
$Res call({
 BlePairedDevice device, String? firmwareVersion, bool dfuSupported
});


@override $BlePairedDeviceCopyWith<$Res> get device;

}
/// @nodoc
class __$ConnectedSoleCopyWithImpl<$Res>
    implements _$ConnectedSoleCopyWith<$Res> {
  __$ConnectedSoleCopyWithImpl(this._self, this._then);

  final _ConnectedSole _self;
  final $Res Function(_ConnectedSole) _then;

/// Create a copy of ConnectedSole
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? device = null,Object? firmwareVersion = freezed,Object? dfuSupported = null,}) {
  return _then(_ConnectedSole(
device: null == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as BlePairedDevice,firmwareVersion: freezed == firmwareVersion ? _self.firmwareVersion : firmwareVersion // ignore: cast_nullable_to_non_nullable
as String?,dfuSupported: null == dfuSupported ? _self.dfuSupported : dfuSupported // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ConnectedSole
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BlePairedDeviceCopyWith<$Res> get device {
  
  return $BlePairedDeviceCopyWith<$Res>(_self.device, (value) {
    return _then(_self.copyWith(device: value));
  });
}
}

// dart format on
