import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'list_tile_data_model.freezed.dart';


@freezed
abstract class ListTileData with _$ListTileData {
  const factory ListTileData.normal({
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onClick,
    @Default(false) bool needCheck,
    String? checkTitle,
    String? checkContent,
    @Default(true) bool enable,
    @Default(false) bool trailing,
  }) = _ListTileNormal;

  const factory ListTileData.dropdown({
    required String title,
    required IconData icon,
    required VoidCallback onClick,
    required Map<String, String> optionsMap,
    String? selected,
    required void Function(int, String) onChanged,
    @Default(true) bool enable,
  }) = _ListTileDropdown;

}