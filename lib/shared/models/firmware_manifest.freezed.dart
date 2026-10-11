// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'firmware_manifest.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FirmwareManifest {

/// Format version; anything but `firmwareManifestSchema` is not understood.
 int get schema; String get channel; String get version; int get size;/// SHA-256 of `fw.bin`, lowercase hex.
 String get sha256;@JsonKey(name: 'bin_path') String get binPath;@JsonKey(name: 'sig_path') String get sigPath; String get notes;@JsonKey(name: 'published_at') DateTime? get publishedAt;
/// Create a copy of FirmwareManifest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirmwareManifestCopyWith<FirmwareManifest> get copyWith => _$FirmwareManifestCopyWithImpl<FirmwareManifest>(this as FirmwareManifest, _$identity);

  /// Serializes this FirmwareManifest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirmwareManifest&&(identical(other.schema, schema) || other.schema == schema)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.version, version) || other.version == version)&&(identical(other.size, size) || other.size == size)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.binPath, binPath) || other.binPath == binPath)&&(identical(other.sigPath, sigPath) || other.sigPath == sigPath)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schema,channel,version,size,sha256,binPath,sigPath,notes,publishedAt);

@override
String toString() {
  return 'FirmwareManifest(schema: $schema, channel: $channel, version: $version, size: $size, sha256: $sha256, binPath: $binPath, sigPath: $sigPath, notes: $notes, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class $FirmwareManifestCopyWith<$Res>  {
  factory $FirmwareManifestCopyWith(FirmwareManifest value, $Res Function(FirmwareManifest) _then) = _$FirmwareManifestCopyWithImpl;
@useResult
$Res call({
 int schema, String channel, String version, int size, String sha256,@JsonKey(name: 'bin_path') String binPath,@JsonKey(name: 'sig_path') String sigPath, String notes,@JsonKey(name: 'published_at') DateTime? publishedAt
});




}
/// @nodoc
class _$FirmwareManifestCopyWithImpl<$Res>
    implements $FirmwareManifestCopyWith<$Res> {
  _$FirmwareManifestCopyWithImpl(this._self, this._then);

  final FirmwareManifest _self;
  final $Res Function(FirmwareManifest) _then;

/// Create a copy of FirmwareManifest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schema = null,Object? channel = null,Object? version = null,Object? size = null,Object? sha256 = null,Object? binPath = null,Object? sigPath = null,Object? notes = null,Object? publishedAt = freezed,}) {
  return _then(_self.copyWith(
schema: null == schema ? _self.schema : schema // ignore: cast_nullable_to_non_nullable
as int,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,binPath: null == binPath ? _self.binPath : binPath // ignore: cast_nullable_to_non_nullable
as String,sigPath: null == sigPath ? _self.sigPath : sigPath // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [FirmwareManifest].
extension FirmwareManifestPatterns on FirmwareManifest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FirmwareManifest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FirmwareManifest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FirmwareManifest value)  $default,){
final _that = this;
switch (_that) {
case _FirmwareManifest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FirmwareManifest value)?  $default,){
final _that = this;
switch (_that) {
case _FirmwareManifest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schema,  String channel,  String version,  int size,  String sha256, @JsonKey(name: 'bin_path')  String binPath, @JsonKey(name: 'sig_path')  String sigPath,  String notes, @JsonKey(name: 'published_at')  DateTime? publishedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FirmwareManifest() when $default != null:
return $default(_that.schema,_that.channel,_that.version,_that.size,_that.sha256,_that.binPath,_that.sigPath,_that.notes,_that.publishedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schema,  String channel,  String version,  int size,  String sha256, @JsonKey(name: 'bin_path')  String binPath, @JsonKey(name: 'sig_path')  String sigPath,  String notes, @JsonKey(name: 'published_at')  DateTime? publishedAt)  $default,) {final _that = this;
switch (_that) {
case _FirmwareManifest():
return $default(_that.schema,_that.channel,_that.version,_that.size,_that.sha256,_that.binPath,_that.sigPath,_that.notes,_that.publishedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schema,  String channel,  String version,  int size,  String sha256, @JsonKey(name: 'bin_path')  String binPath, @JsonKey(name: 'sig_path')  String sigPath,  String notes, @JsonKey(name: 'published_at')  DateTime? publishedAt)?  $default,) {final _that = this;
switch (_that) {
case _FirmwareManifest() when $default != null:
return $default(_that.schema,_that.channel,_that.version,_that.size,_that.sha256,_that.binPath,_that.sigPath,_that.notes,_that.publishedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FirmwareManifest implements FirmwareManifest {
  const _FirmwareManifest({required this.schema, required this.channel, required this.version, required this.size, required this.sha256, @JsonKey(name: 'bin_path') required this.binPath, @JsonKey(name: 'sig_path') required this.sigPath, this.notes = '', @JsonKey(name: 'published_at') this.publishedAt});
  factory _FirmwareManifest.fromJson(Map<String, dynamic> json) => _$FirmwareManifestFromJson(json);

/// Format version; anything but `firmwareManifestSchema` is not understood.
@override final  int schema;
@override final  String channel;
@override final  String version;
@override final  int size;
/// SHA-256 of `fw.bin`, lowercase hex.
@override final  String sha256;
@override@JsonKey(name: 'bin_path') final  String binPath;
@override@JsonKey(name: 'sig_path') final  String sigPath;
@override@JsonKey() final  String notes;
@override@JsonKey(name: 'published_at') final  DateTime? publishedAt;

/// Create a copy of FirmwareManifest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FirmwareManifestCopyWith<_FirmwareManifest> get copyWith => __$FirmwareManifestCopyWithImpl<_FirmwareManifest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FirmwareManifestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirmwareManifest&&(identical(other.schema, schema) || other.schema == schema)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.version, version) || other.version == version)&&(identical(other.size, size) || other.size == size)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.binPath, binPath) || other.binPath == binPath)&&(identical(other.sigPath, sigPath) || other.sigPath == sigPath)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.publishedAt, publishedAt) || other.publishedAt == publishedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schema,channel,version,size,sha256,binPath,sigPath,notes,publishedAt);

@override
String toString() {
  return 'FirmwareManifest(schema: $schema, channel: $channel, version: $version, size: $size, sha256: $sha256, binPath: $binPath, sigPath: $sigPath, notes: $notes, publishedAt: $publishedAt)';
}


}

/// @nodoc
abstract mixin class _$FirmwareManifestCopyWith<$Res> implements $FirmwareManifestCopyWith<$Res> {
  factory _$FirmwareManifestCopyWith(_FirmwareManifest value, $Res Function(_FirmwareManifest) _then) = __$FirmwareManifestCopyWithImpl;
@override @useResult
$Res call({
 int schema, String channel, String version, int size, String sha256,@JsonKey(name: 'bin_path') String binPath,@JsonKey(name: 'sig_path') String sigPath, String notes,@JsonKey(name: 'published_at') DateTime? publishedAt
});




}
/// @nodoc
class __$FirmwareManifestCopyWithImpl<$Res>
    implements _$FirmwareManifestCopyWith<$Res> {
  __$FirmwareManifestCopyWithImpl(this._self, this._then);

  final _FirmwareManifest _self;
  final $Res Function(_FirmwareManifest) _then;

/// Create a copy of FirmwareManifest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schema = null,Object? channel = null,Object? version = null,Object? size = null,Object? sha256 = null,Object? binPath = null,Object? sigPath = null,Object? notes = null,Object? publishedAt = freezed,}) {
  return _then(_FirmwareManifest(
schema: null == schema ? _self.schema : schema // ignore: cast_nullable_to_non_nullable
as int,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,binPath: null == binPath ? _self.binPath : binPath // ignore: cast_nullable_to_non_nullable
as String,sigPath: null == sigPath ? _self.sigPath : sigPath // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,publishedAt: freezed == publishedAt ? _self.publishedAt : publishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
