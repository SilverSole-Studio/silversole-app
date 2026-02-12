import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/widgets/basic_dialog.dart';

class ListTileData {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onClick;
  final bool needCheck;
  final String? checkTitle;
  final String? checkContent;
  final bool enable;
  final bool trailing;

  ListTileData({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onClick,
    this.needCheck = false,
    this.checkTitle,
    this.checkContent,
    this.enable = true,
    this.trailing = false,
  });
}

Widget buildMaterialList(BuildContext context, {String? title, required List<ListTileData> raw}) {
  const outerRadius = 16.0;
  const innerRadius = 4.0;
  final scheme = Theme
      .of(context)
      .colorScheme;
  final splashColor = scheme.primary.withValues(alpha: 0.08);
  final hoverColor = scheme.primary.withValues(alpha: 0.04);
  final list = raw.where((tile) => tile.enable).toList();

  // Future<void>

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 4,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      for (var i = 0; i < list.length; i++)
        if (list[i].enable)
          Material(
            color: Theme
                .of(context)
                .colorScheme
                .surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? outerRadius : innerRadius),
                bottom: Radius.circular(i == list.length - 1 ? outerRadius : innerRadius),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: Icon(list[i].icon),
                title: Text(list[i].title),
                subtitle: list[i].subtitle != null ? Text(list[i].subtitle ?? '') : null,
                splashColor: splashColor,
                hoverColor: hoverColor,
                focusColor: hoverColor,
                onTap: () =>
                {
                  if (list[i].needCheck)
                    showConfirmLeaveDialog(context,
                        title: list[i].checkTitle ?? '',
                        text: list[i].checkContent ?? '',
                        onDismiss: () => {},
                        onClick: list[i].onClick
                    )
                  else
                    list[i].onClick()
                },
                trailing: list[i].trailing ? const Icon(LucideIcons.chevronRight) : null,
              ),
            ),
          ),
    ],
  );
}
