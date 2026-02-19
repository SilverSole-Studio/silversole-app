// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppSettings {

 String? get identity; String? get deviceId; bool get darkMode; TransmissionMethod get transmissionMethod; List<BlePairedDevice> get pairedDevicesList;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.darkMode, darkMode) || other.darkMode == darkMode)&&(identical(other.transmissionMethod, transmissionMethod) || other.transmissionMethod == transmissionMethod)&&const DeepCollectionEquality().equals(other.pairedDevicesList, pairedDevicesList));
}


@override
int get hashCode => Object.hash(runtimeType,identity,deviceId,darkMode,transmissionMethod,const DeepCollectionEquality().hash(pairedDevicesList));

@override
String toString() {
  return 'AppSettings(identity: $identity, deviceId: $deviceId, darkMode: $darkMode, transmissionMethod: $transmissionMethod, pairedDevicesList: $pairedDevicesList)';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 String? identity, String? deviceId, bool darkMode, TransmissionMethod transmissionMethod, List<BlePairedDevice> pairedDevicesList
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? identity = freezed,Object? deviceId = freezed,Object? darkMode = null,Object? transmissionMethod = null,Object? pairedDevicesList = null,}) {
  return _then(_self.copyWith(
identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as String?,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,darkMode: null == darkMode ? _self.darkMode : darkMode // ignore: cast_nullable_to_non_nullable
as bool,transmissionMethod: null == transmissionMethod ? _self.transmissionMethod : transmissionMethod // ignore: cast_nullable_to_non_nullable
as TransmissionMethod,pairedDevicesList: null == pairedDevicesList ? _self.pairedDevicesList : pairedDevicesList // ignore: cast_nullable_to_non_nullable
as List<BlePairedDevice>,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? identity,  String? deviceId,  bool darkMode,  TransmissionMethod transmissionMethod,  List<BlePairedDevice> pairedDevicesList)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.identity,_that.deviceId,_that.darkMode,_that.transmissionMethod,_that.pairedDevicesList);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? identity,  String? deviceId,  bool darkMode,  TransmissionMethod transmissionMethod,  List<BlePairedDevice> pairedDevicesList)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.identity,_that.deviceId,_that.darkMode,_that.transmissionMethod,_that.pairedDevicesList);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? identity,  String? deviceId,  bool darkMode,  TransmissionMethod transmissionMethod,  List<BlePairedDevice> pairedDevicesList)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.identity,_that.deviceId,_that.darkMode,_that.transmissionMethod,_that.pairedDevicesList);case _:
  return null;

}
}

}

/// @nodoc


class _AppSettings extends AppSettings {
  const _AppSettings({this.identity, this.deviceId, this.darkMode = true, this.transmissionMethod = TransmissionMethod.bluetooth, final  List<BlePairedDevice> pairedDevicesList = const <BlePairedDevice>[]}): _pairedDevicesList = pairedDevicesList,super._();
  

@override final  String? identity;
@override final  String? deviceId;
@override@JsonKey() final  bool darkMode;
@override@JsonKey() final  TransmissionMethod transmissionMethod;
 final  List<BlePairedDevice> _pairedDevicesList;
@override@JsonKey() List<BlePairedDevice> get pairedDevicesList {
  if (_pairedDevicesList is EqualUnmodifiableListView) return _pairedDevicesList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pairedDevicesList);
}


/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.darkMode, darkMode) || other.darkMode == darkMode)&&(identical(other.transmissionMethod, transmissionMethod) || other.transmissionMethod == transmissionMethod)&&const DeepCollectionEquality().equals(other._pairedDevicesList, _pairedDevicesList));
}


@override
int get hashCode => Object.hash(runtimeType,identity,deviceId,darkMode,transmissionMethod,const DeepCollectionEquality().hash(_pairedDevicesList));

@override
String toString() {
  return 'AppSettings(identity: $identity, deviceId: $deviceId, darkMode: $darkMode, transmissionMethod: $transmissionMethod, pairedDevicesList: $pairedDevicesList)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 String? identity, String? deviceId, bool darkMode, TransmissionMethod transmissionMethod, List<BlePairedDevice> pairedDevicesList
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? identity = freezed,Object? deviceId = freezed,Object? darkMode = null,Object? transmissionMethod = null,Object? pairedDevicesList = null,}) {
  return _then(_AppSettings(
identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as String?,deviceId: freezed == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String?,darkMode: null == darkMode ? _self.darkMode : darkMode // ignore: cast_nullable_to_non_nullable
as bool,transmissionMethod: null == transmissionMethod ? _self.transmissionMethod : transmissionMethod // ignore: cast_nullable_to_non_nullable
as TransmissionMethod,pairedDevicesList: null == pairedDevicesList ? _self._pairedDevicesList : pairedDevicesList // ignore: cast_nullable_to_non_nullable
as List<BlePairedDevice>,
  ));
}


}

// dart format on
