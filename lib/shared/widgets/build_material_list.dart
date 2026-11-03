import 'package:flutter/material.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/widgets/settings_row.dart';

/// Renders a list of [ListTileData] as a [SettingsGroup] of [SettingsRow]
/// cards. Same look in both themes (the card comes from the theme).
Widget buildMaterialList(
  BuildContext context, {
  String? title,
  required List<ListTileData> raw,
}) {
  final list = raw.where((tile) => tile.enable).toList();

  return SettingsGroup(
    title: title,
    children: [
      for (var i = 0; i < list.length; i++)
        list[i].map(
          normal: (data) => SettingsRow(
            icon: data.icon,
            title: data.title,
            subtitle: data.subtitle,
            showChevron: data.trailing,
            onTap: () {
              if (data.needCheck) {
                showConfirmLeaveDialog(
                  context,
                  title: data.checkTitle ?? '',
                  text: data.checkContent ?? '',
                  onDismiss: () {},
                  onConfirm: data.onClick,
                );
              } else {
                data.onClick();
              }
            },
          ),
          dropdown: (data) => SettingsRow(
            icon: data.icon,
            title: data.title,
            subtitle: data.selected != null
                ? data.optionsMap[data.selected]
                : null,
            showChevron: true,
            onTap: () => showOptionsDialog(
              context,
              title: data.title,
              optionsMap: data.optionsMap,
              selectedKey: data.selected,
              onChanged: (key) => data.onChanged(i, key),
            ),
          ),
        ),
    ],
  );
}
