// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'list_tile_data_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ListTileData {

 String get title; IconData get icon; VoidCallback get onClick; bool get enable;
/// Create a copy of ListTileData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ListTileDataCopyWith<ListTileData> get copyWith => _$ListTileDataCopyWithImpl<ListTileData>(this as ListTileData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ListTileData&&(identical(other.title, title) || other.title == title)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.onClick, onClick) || other.onClick == onClick)&&(identical(other.enable, enable) || other.enable == enable));
}


@override
int get hashCode => Object.hash(runtimeType,title,icon,onClick,enable);

@override
String toString() {
  return 'ListTileData(title: $title, icon: $icon, onClick: $onClick, enable: $enable)';
}


}

/// @nodoc
abstract mixin class $ListTileDataCopyWith<$Res>  {
  factory $ListTileDataCopyWith(ListTileData value, $Res Function(ListTileData) _then) = _$ListTileDataCopyWithImpl;
@useResult
$Res call({
 String title, IconData icon, void Function() onClick, bool enable
});




}
/// @nodoc
class _$ListTileDataCopyWithImpl<$Res>
    implements $ListTileDataCopyWith<$Res> {
  _$ListTileDataCopyWithImpl(this._self, this._then);

  final ListTileData _self;
  final $Res Function(ListTileData) _then;

/// Create a copy of ListTileData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? icon = null,Object? onClick = null,Object? enable = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as IconData,onClick: null == onClick ? _self.onClick : onClick // ignore: cast_nullable_to_non_nullable
as void Function(),enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ListTileData].
extension ListTileDataPatterns on ListTileData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _ListTileNormal value)?  normal,TResult Function( _ListTileDropdown value)?  dropdown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ListTileNormal() when normal != null:
return normal(_that);case _ListTileDropdown() when dropdown != null:
return dropdown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _ListTileNormal value)  normal,required TResult Function( _ListTileDropdown value)  dropdown,}){
final _that = this;
switch (_that) {
case _ListTileNormal():
return normal(_that);case _ListTileDropdown():
return dropdown(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _ListTileNormal value)?  normal,TResult? Function( _ListTileDropdown value)?  dropdown,}){
final _that = this;
switch (_that) {
case _ListTileNormal() when normal != null:
return normal(_that);case _ListTileDropdown() when dropdown != null:
return dropdown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String title,  String? subtitle,  IconData icon,  VoidCallback onClick,  bool needCheck,  String? checkTitle,  String? checkContent,  bool enable,  bool trailing)?  normal,TResult Function( String title,  IconData icon,  VoidCallback onClick,  Map<String, String> optionsMap,  String? selected,  void Function(int, String) onChanged,  bool enable)?  dropdown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ListTileNormal() when normal != null:
return normal(_that.title,_that.subtitle,_that.icon,_that.onClick,_that.needCheck,_that.checkTitle,_that.checkContent,_that.enable,_that.trailing);case _ListTileDropdown() when dropdown != null:
return dropdown(_that.title,_that.icon,_that.onClick,_that.optionsMap,_that.selected,_that.onChanged,_that.enable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String title,  String? subtitle,  IconData icon,  VoidCallback onClick,  bool needCheck,  String? checkTitle,  String? checkContent,  bool enable,  bool trailing)  normal,required TResult Function( String title,  IconData icon,  VoidCallback onClick,  Map<String, String> optionsMap,  String? selected,  void Function(int, String) onChanged,  bool enable)  dropdown,}) {final _that = this;
switch (_that) {
case _ListTileNormal():
return normal(_that.title,_that.subtitle,_that.icon,_that.onClick,_that.needCheck,_that.checkTitle,_that.checkContent,_that.enable,_that.trailing);case _ListTileDropdown():
return dropdown(_that.title,_that.icon,_that.onClick,_that.optionsMap,_that.selected,_that.onChanged,_that.enable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String title,  String? subtitle,  IconData icon,  VoidCallback onClick,  bool needCheck,  String? checkTitle,  String? checkContent,  bool enable,  bool trailing)?  normal,TResult? Function( String title,  IconData icon,  VoidCallback onClick,  Map<String, String> optionsMap,  String? selected,  void Function(int, String) onChanged,  bool enable)?  dropdown,}) {final _that = this;
switch (_that) {
case _ListTileNormal() when normal != null:
return normal(_that.title,_that.subtitle,_that.icon,_that.onClick,_that.needCheck,_that.checkTitle,_that.checkContent,_that.enable,_that.trailing);case _ListTileDropdown() when dropdown != null:
return dropdown(_that.title,_that.icon,_that.onClick,_that.optionsMap,_that.selected,_that.onChanged,_that.enable);case _:
  return null;

}
}

}

/// @nodoc


class _ListTileNormal implements ListTileData {
  const _ListTileNormal({required this.title, this.subtitle, required this.icon, required this.onClick, this.needCheck = false, this.checkTitle, this.checkContent, this.enable = true, this.trailing = false});
  

@override final  String title;
 final  String? subtitle;
@override final  IconData icon;
@override final  VoidCallback onClick;
@JsonKey() final  bool needCheck;
 final  String? checkTitle;
 final  String? checkContent;
@override@JsonKey() final  bool enable;
@JsonKey() final  bool trailing;

/// Create a copy of ListTileData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ListTileNormalCopyWith<_ListTileNormal> get copyWith => __$ListTileNormalCopyWithImpl<_ListTileNormal>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ListTileNormal&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.onClick, onClick) || other.onClick == onClick)&&(identical(other.needCheck, needCheck) || other.needCheck == needCheck)&&(identical(other.checkTitle, checkTitle) || other.checkTitle == checkTitle)&&(identical(other.checkContent, checkContent) || other.checkContent == checkContent)&&(identical(other.enable, enable) || other.enable == enable)&&(identical(other.trailing, trailing) || other.trailing == trailing));
}


@override
int get hashCode => Object.hash(runtimeType,title,subtitle,icon,onClick,needCheck,checkTitle,checkContent,enable,trailing);

@override
String toString() {
  return 'ListTileData.normal(title: $title, subtitle: $subtitle, icon: $icon, onClick: $onClick, needCheck: $needCheck, checkTitle: $checkTitle, checkContent: $checkContent, enable: $enable, trailing: $trailing)';
}


}

/// @nodoc
abstract mixin class _$ListTileNormalCopyWith<$Res> implements $ListTileDataCopyWith<$Res> {
  factory _$ListTileNormalCopyWith(_ListTileNormal value, $Res Function(_ListTileNormal) _then) = __$ListTileNormalCopyWithImpl;
@override @useResult
$Res call({
 String title, String? subtitle, IconData icon, VoidCallback onClick, bool needCheck, String? checkTitle, String? checkContent, bool enable, bool trailing
});




}
/// @nodoc
class __$ListTileNormalCopyWithImpl<$Res>
    implements _$ListTileNormalCopyWith<$Res> {
  __$ListTileNormalCopyWithImpl(this._self, this._then);

  final _ListTileNormal _self;
  final $Res Function(_ListTileNormal) _then;

/// Create a copy of ListTileData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? subtitle = freezed,Object? icon = null,Object? onClick = null,Object? needCheck = null,Object? checkTitle = freezed,Object? checkContent = freezed,Object? enable = null,Object? trailing = null,}) {
  return _then(_ListTileNormal(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: freezed == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String?,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as IconData,onClick: null == onClick ? _self.onClick : onClick // ignore: cast_nullable_to_non_nullable
as VoidCallback,needCheck: null == needCheck ? _self.needCheck : needCheck // ignore: cast_nullable_to_non_nullable
as bool,checkTitle: freezed == checkTitle ? _self.checkTitle : checkTitle // ignore: cast_nullable_to_non_nullable
as String?,checkContent: freezed == checkContent ? _self.checkContent : checkContent // ignore: cast_nullable_to_non_nullable
as String?,enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,trailing: null == trailing ? _self.trailing : trailing // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class _ListTileDropdown implements ListTileData {
  const _ListTileDropdown({required this.title, required this.icon, required this.onClick, required final  Map<String, String> optionsMap, this.selected, required this.onChanged, this.enable = true}): _optionsMap = optionsMap;
  

@override final  String title;
@override final  IconData icon;
@override final  VoidCallback onClick;
 final  Map<String, String> _optionsMap;
 Map<String, String> get optionsMap {
  if (_optionsMap is EqualUnmodifiableMapView) return _optionsMap;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_optionsMap);
}

 final  String? selected;
 final  void Function(int, String) onChanged;
@override@JsonKey() final  bool enable;

/// Create a copy of ListTileData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ListTileDropdownCopyWith<_ListTileDropdown> get copyWith => __$ListTileDropdownCopyWithImpl<_ListTileDropdown>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ListTileDropdown&&(identical(other.title, title) || other.title == title)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.onClick, onClick) || other.onClick == onClick)&&const DeepCollectionEquality().equals(other._optionsMap, _optionsMap)&&(identical(other.selected, selected) || other.selected == selected)&&(identical(other.onChanged, onChanged) || other.onChanged == onChanged)&&(identical(other.enable, enable) || other.enable == enable));
}


@override
int get hashCode => Object.hash(runtimeType,title,icon,onClick,const DeepCollectionEquality().hash(_optionsMap),selected,onChanged,enable);

@override
String toString() {
  return 'ListTileData.dropdown(title: $title, icon: $icon, onClick: $onClick, optionsMap: $optionsMap, selected: $selected, onChanged: $onChanged, enable: $enable)';
}


}

/// @nodoc
abstract mixin class _$ListTileDropdownCopyWith<$Res> implements $ListTileDataCopyWith<$Res> {
  factory _$ListTileDropdownCopyWith(_ListTileDropdown value, $Res Function(_ListTileDropdown) _then) = __$ListTileDropdownCopyWithImpl;
@override @useResult
$Res call({
 String title, IconData icon, VoidCallback onClick, Map<String, String> optionsMap, String? selected, void Function(int, String) onChanged, bool enable
});




}
/// @nodoc
class __$ListTileDropdownCopyWithImpl<$Res>
    implements _$ListTileDropdownCopyWith<$Res> {
  __$ListTileDropdownCopyWithImpl(this._self, this._then);

  final _ListTileDropdown _self;
  final $Res Function(_ListTileDropdown) _then;

/// Create a copy of ListTileData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? icon = null,Object? onClick = null,Object? optionsMap = null,Object? selected = freezed,Object? onChanged = null,Object? enable = null,}) {
  return _then(_ListTileDropdown(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as IconData,onClick: null == onClick ? _self.onClick : onClick // ignore: cast_nullable_to_non_nullable
as VoidCallback,optionsMap: null == optionsMap ? _self._optionsMap : optionsMap // ignore: cast_nullable_to_non_nullable
as Map<String, String>,selected: freezed == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as String?,onChanged: null == onChanged ? _self.onChanged : onChanged // ignore: cast_nullable_to_non_nullable
as void Function(int, String),enable: null == enable ? _self.enable : enable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
