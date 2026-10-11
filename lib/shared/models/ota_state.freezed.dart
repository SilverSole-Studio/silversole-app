// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ota_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OtaState {

 OtaPhase get phase; int get committed; int get size; String? get fromVersion; String? get toVersion;/// The version the sole reported after it came back.
 String? get readVersion;/// The sole was found by elimination, not by its ID (old firmware).
 bool get probable; DfuFailure? get failure;
/// Create a copy of OtaState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OtaStateCopyWith<OtaState> get copyWith => _$OtaStateCopyWithImpl<OtaState>(this as OtaState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OtaState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.committed, committed) || other.committed == committed)&&(identical(other.size, size) || other.size == size)&&(identical(other.fromVersion, fromVersion) || other.fromVersion == fromVersion)&&(identical(other.toVersion, toVersion) || other.toVersion == toVersion)&&(identical(other.readVersion, readVersion) || other.readVersion == readVersion)&&(identical(other.probable, probable) || other.probable == probable)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,phase,committed,size,fromVersion,toVersion,readVersion,probable,failure);

@override
String toString() {
  return 'OtaState(phase: $phase, committed: $committed, size: $size, fromVersion: $fromVersion, toVersion: $toVersion, readVersion: $readVersion, probable: $probable, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $OtaStateCopyWith<$Res>  {
  factory $OtaStateCopyWith(OtaState value, $Res Function(OtaState) _then) = _$OtaStateCopyWithImpl;
@useResult
$Res call({
 OtaPhase phase, int committed, int size, String? fromVersion, String? toVersion, String? readVersion, bool probable, DfuFailure? failure
});




}
/// @nodoc
class _$OtaStateCopyWithImpl<$Res>
    implements $OtaStateCopyWith<$Res> {
  _$OtaStateCopyWithImpl(this._self, this._then);

  final OtaState _self;
  final $Res Function(OtaState) _then;

/// Create a copy of OtaState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? committed = null,Object? size = null,Object? fromVersion = freezed,Object? toVersion = freezed,Object? readVersion = freezed,Object? probable = null,Object? failure = freezed,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as OtaPhase,committed: null == committed ? _self.committed : committed // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,fromVersion: freezed == fromVersion ? _self.fromVersion : fromVersion // ignore: cast_nullable_to_non_nullable
as String?,toVersion: freezed == toVersion ? _self.toVersion : toVersion // ignore: cast_nullable_to_non_nullable
as String?,readVersion: freezed == readVersion ? _self.readVersion : readVersion // ignore: cast_nullable_to_non_nullable
as String?,probable: null == probable ? _self.probable : probable // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as DfuFailure?,
  ));
}

}


/// Adds pattern-matching-related methods to [OtaState].
extension OtaStatePatterns on OtaState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OtaState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OtaState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OtaState value)  $default,){
final _that = this;
switch (_that) {
case _OtaState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OtaState value)?  $default,){
final _that = this;
switch (_that) {
case _OtaState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OtaPhase phase,  int committed,  int size,  String? fromVersion,  String? toVersion,  String? readVersion,  bool probable,  DfuFailure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OtaState() when $default != null:
return $default(_that.phase,_that.committed,_that.size,_that.fromVersion,_that.toVersion,_that.readVersion,_that.probable,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OtaPhase phase,  int committed,  int size,  String? fromVersion,  String? toVersion,  String? readVersion,  bool probable,  DfuFailure? failure)  $default,) {final _that = this;
switch (_that) {
case _OtaState():
return $default(_that.phase,_that.committed,_that.size,_that.fromVersion,_that.toVersion,_that.readVersion,_that.probable,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OtaPhase phase,  int committed,  int size,  String? fromVersion,  String? toVersion,  String? readVersion,  bool probable,  DfuFailure? failure)?  $default,) {final _that = this;
switch (_that) {
case _OtaState() when $default != null:
return $default(_that.phase,_that.committed,_that.size,_that.fromVersion,_that.toVersion,_that.readVersion,_that.probable,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _OtaState extends OtaState {
  const _OtaState({this.phase = OtaPhase.idle, this.committed = 0, this.size = 0, this.fromVersion, this.toVersion, this.readVersion, this.probable = false, this.failure}): super._();
  

@override@JsonKey() final  OtaPhase phase;
@override@JsonKey() final  int committed;
@override@JsonKey() final  int size;
@override final  String? fromVersion;
@override final  String? toVersion;
/// The version the sole reported after it came back.
@override final  String? readVersion;
/// The sole was found by elimination, not by its ID (old firmware).
@override@JsonKey() final  bool probable;
@override final  DfuFailure? failure;

/// Create a copy of OtaState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OtaStateCopyWith<_OtaState> get copyWith => __$OtaStateCopyWithImpl<_OtaState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OtaState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.committed, committed) || other.committed == committed)&&(identical(other.size, size) || other.size == size)&&(identical(other.fromVersion, fromVersion) || other.fromVersion == fromVersion)&&(identical(other.toVersion, toVersion) || other.toVersion == toVersion)&&(identical(other.readVersion, readVersion) || other.readVersion == readVersion)&&(identical(other.probable, probable) || other.probable == probable)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,phase,committed,size,fromVersion,toVersion,readVersion,probable,failure);

@override
String toString() {
  return 'OtaState(phase: $phase, committed: $committed, size: $size, fromVersion: $fromVersion, toVersion: $toVersion, readVersion: $readVersion, probable: $probable, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$OtaStateCopyWith<$Res> implements $OtaStateCopyWith<$Res> {
  factory _$OtaStateCopyWith(_OtaState value, $Res Function(_OtaState) _then) = __$OtaStateCopyWithImpl;
@override @useResult
$Res call({
 OtaPhase phase, int committed, int size, String? fromVersion, String? toVersion, String? readVersion, bool probable, DfuFailure? failure
});




}
/// @nodoc
class __$OtaStateCopyWithImpl<$Res>
    implements _$OtaStateCopyWith<$Res> {
  __$OtaStateCopyWithImpl(this._self, this._then);

  final _OtaState _self;
  final $Res Function(_OtaState) _then;

/// Create a copy of OtaState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? committed = null,Object? size = null,Object? fromVersion = freezed,Object? toVersion = freezed,Object? readVersion = freezed,Object? probable = null,Object? failure = freezed,}) {
  return _then(_OtaState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as OtaPhase,committed: null == committed ? _self.committed : committed // ignore: cast_nullable_to_non_nullable
as int,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,fromVersion: freezed == fromVersion ? _self.fromVersion : fromVersion // ignore: cast_nullable_to_non_nullable
as String?,toVersion: freezed == toVersion ? _self.toVersion : toVersion // ignore: cast_nullable_to_non_nullable
as String?,readVersion: freezed == readVersion ? _self.readVersion : readVersion // ignore: cast_nullable_to_non_nullable
as String?,probable: null == probable ? _self.probable : probable // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as DfuFailure?,
  ));
}


}

// dart format on
