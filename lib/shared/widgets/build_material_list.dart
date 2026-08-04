import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';

/// Renders a settings group.
///
/// [side] draws an outline around each row and, when set, rounds every corner
/// and spaces the rows apart so they read as separate outlined buttons rather
/// than one grouped slab. The mascot theme passes it; the classic theme leaves
/// it null and keeps the original grouped look.
Widget buildMaterialList(
  BuildContext context, {
  String? title,
  required List<ListTileData> raw,
  Color? themeColor,
  BorderSide? side,
}) {
  const outerRadius = AppRadius.banner;
  final innerRadius = side == null ? 4.0 : outerRadius;
  final scheme = Theme.of(context).colorScheme;
  final splashColor = scheme.primary.withValues(alpha: 0.08);
  final hoverColor = scheme.primary.withValues(alpha: 0.04);
  final list = raw.where((tile) => tile.enable).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: side == null ? 4 : 10,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(title, style: context.textTheme.titleMedium),
        ),
      for (var i = 0; i < list.length; i++)
        if (list[i].enable)
          Material(
            color:
                themeColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? outerRadius : innerRadius),
                bottom: Radius.circular(
                  i == list.length - 1 ? outerRadius : innerRadius,
                ),
              ),
              side: side ?? BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: list[i].map(
                normal: (data) => ListTile(
                  leading: Icon(data.icon),
                  title: Text(data.title),
                  subtitle: data.subtitle != null
                      ? Text(data.subtitle ?? '')
                      : null,
                  splashColor: splashColor,
                  hoverColor: hoverColor,
                  focusColor: hoverColor,
                  onTap: () => {
                    if (data.needCheck)
                      showConfirmLeaveDialog(
                        context,
                        title: data.checkTitle ?? '',
                        text: data.checkContent ?? '',
                        onDismiss: () => {},
                        onConfirm: data.onClick,
                      )
                    else
                      data.onClick(),
                  },
                  trailing: data.trailing
                      ? const Icon(LucideIcons.chevronRight)
                      : null,
                ),
                dropdown: (data) => ListTile(
                  leading: Icon(data.icon),
                  title: Text(data.title),
                  subtitle: data.selected != null
                      ? Text(data.optionsMap[data.selected] ?? '')
                      : null,
                  splashColor: splashColor,
                  hoverColor: hoverColor,
                  focusColor: hoverColor,
                  onTap: () {
                    showOptionsDialog(
                      context,
                      title: data.title,
                      optionsMap: data.optionsMap,
                      selectedKey: data.selected,
                      onChanged: (key) => data.onChanged(i, key),
                    );
                  },
                  trailing: const Icon(LucideIcons.chevronRight),
                ),
              ),
            ),
          ),
    ],
  );
}
