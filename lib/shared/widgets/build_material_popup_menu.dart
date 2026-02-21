import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';

Widget buildMaterialPopupMenu(
  BuildContext context, {
  String? title,
  required List<ListTileData> raw,
}) {
  return PopupMenuButton<ListTileData>(
    icon: const Icon(LucideIcons.moreVertical),
    onSelected: (selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        selected.map(
          normal: (data) {
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
          dropdown: (_) {},
        );
      });
    },
    itemBuilder: (_) => <PopupMenuEntry<ListTileData>>[
      for (var item in raw)
        item.map<PopupMenuEntry<ListTileData>>(
          normal: (data) => PopupMenuItem<ListTileData>(
            value: data,
            enabled: data.enable,
            child: ListTile(
              leading: Icon(data.icon),
              title: Text(data.title),
            ),
          ),
          dropdown: (data) => PopupMenuItem<ListTileData>(
            value: data,
            enabled: false,
            child: ListTile(
              leading: Icon(data.icon),
              title: Text(data.title),
            ),
          ),
        ),
    ],
  );
}
