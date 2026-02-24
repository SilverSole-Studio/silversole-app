// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'live_telemetry_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LiveTelemetryState {

 TelemetrySource get source; List<ImuNotifyDataModel> get recent; DateTime? get updatedAt; bool get loading; String? get errorMessage;
/// Create a copy of LiveTelemetryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveTelemetryStateCopyWith<LiveTelemetryState> get copyWith => _$LiveTelemetryStateCopyWithImpl<LiveTelemetryState>(this as LiveTelemetryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveTelemetryState&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other.recent, recent)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,source,const DeepCollectionEquality().hash(recent),updatedAt,loading,errorMessage);

@override
String toString() {
  return 'LiveTelemetryState(source: $source, recent: $recent, updatedAt: $updatedAt, loading: $loading, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $LiveTelemetryStateCopyWith<$Res>  {
  factory $LiveTelemetryStateCopyWith(LiveTelemetryState value, $Res Function(LiveTelemetryState) _then) = _$LiveTelemetryStateCopyWithImpl;
@useResult
$Res call({
 TelemetrySource source, List<ImuNotifyDataModel> recent, DateTime? updatedAt, bool loading, String? errorMessage
});




}
/// @nodoc
class _$LiveTelemetryStateCopyWithImpl<$Res>
    implements $LiveTelemetryStateCopyWith<$Res> {
  _$LiveTelemetryStateCopyWithImpl(this._self, this._then);

  final LiveTelemetryState _self;
  final $Res Function(LiveTelemetryState) _then;

/// Create a copy of LiveTelemetryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? recent = null,Object? updatedAt = freezed,Object? loading = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TelemetrySource,recent: null == recent ? _self.recent : recent // ignore: cast_nullable_to_non_nullable
as List<ImuNotifyDataModel>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveTelemetryState].
extension LiveTelemetryStatePatterns on LiveTelemetryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveTelemetryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveTelemetryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveTelemetryState value)  $default,){
final _that = this;
switch (_that) {
case _LiveTelemetryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveTelemetryState value)?  $default,){
final _that = this;
switch (_that) {
case _LiveTelemetryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TelemetrySource source,  List<ImuNotifyDataModel> recent,  DateTime? updatedAt,  bool loading,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveTelemetryState() when $default != null:
return $default(_that.source,_that.recent,_that.updatedAt,_that.loading,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TelemetrySource source,  List<ImuNotifyDataModel> recent,  DateTime? updatedAt,  bool loading,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _LiveTelemetryState():
return $default(_that.source,_that.recent,_that.updatedAt,_that.loading,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TelemetrySource source,  List<ImuNotifyDataModel> recent,  DateTime? updatedAt,  bool loading,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _LiveTelemetryState() when $default != null:
return $default(_that.source,_that.recent,_that.updatedAt,_that.loading,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _LiveTelemetryState implements LiveTelemetryState {
  const _LiveTelemetryState({this.source = TelemetrySource.none, final  List<ImuNotifyDataModel> recent = const <ImuNotifyDataModel>[], this.updatedAt, this.loading = false, this.errorMessage}): _recent = recent;
  

@override@JsonKey() final  TelemetrySource source;
 final  List<ImuNotifyDataModel> _recent;
@override@JsonKey() List<ImuNotifyDataModel> get recent {
  if (_recent is EqualUnmodifiableListView) return _recent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recent);
}

@override final  DateTime? updatedAt;
@override@JsonKey() final  bool loading;
@override final  String? errorMessage;

/// Create a copy of LiveTelemetryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveTelemetryStateCopyWith<_LiveTelemetryState> get copyWith => __$LiveTelemetryStateCopyWithImpl<_LiveTelemetryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveTelemetryState&&(identical(other.source, source) || other.source == source)&&const DeepCollectionEquality().equals(other._recent, _recent)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,source,const DeepCollectionEquality().hash(_recent),updatedAt,loading,errorMessage);

@override
String toString() {
  return 'LiveTelemetryState(source: $source, recent: $recent, updatedAt: $updatedAt, loading: $loading, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$LiveTelemetryStateCopyWith<$Res> implements $LiveTelemetryStateCopyWith<$Res> {
  factory _$LiveTelemetryStateCopyWith(_LiveTelemetryState value, $Res Function(_LiveTelemetryState) _then) = __$LiveTelemetryStateCopyWithImpl;
@override @useResult
$Res call({
 TelemetrySource source, List<ImuNotifyDataModel> recent, DateTime? updatedAt, bool loading, String? errorMessage
});




}
/// @nodoc
class __$LiveTelemetryStateCopyWithImpl<$Res>
    implements _$LiveTelemetryStateCopyWith<$Res> {
  __$LiveTelemetryStateCopyWithImpl(this._self, this._then);

  final _LiveTelemetryState _self;
  final $Res Function(_LiveTelemetryState) _then;

/// Create a copy of LiveTelemetryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? recent = null,Object? updatedAt = freezed,Object? loading = null,Object? errorMessage = freezed,}) {
  return _then(_LiveTelemetryState(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as TelemetrySource,recent: null == recent ? _self._recent : recent // ignore: cast_nullable_to_non_nullable
as List<ImuNotifyDataModel>,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
