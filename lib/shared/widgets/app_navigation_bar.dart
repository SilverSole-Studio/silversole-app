import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/widgets/town_icon.dart';

Widget appNavigationBar({
  required int selectedIndex,
  required void Function(int index) onDestinationSelected,
  required List<IconData> icons,
  required List<String> labels,
  List<String>? townIcons,
}) {
  assert(
    icons.length == labels.length,
    'icons and labels must have the same length',
  );
  return Builder(
    builder: (context) {
      // Hairline divider above the bar (drawn over the bar's background so it
      // reads as a top outline), matching the card borders.
      // Look A draws its own hand-made icons and a thick brown top edge.
      final isA =
          Theme.of(context).extension<AppLook>()?.variant ==
          AppThemeVariant.mascot;
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: isA ? AppPaletteT2.outlineWidth : 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (var i = 0; i < icons.length; i++)
              NavigationDestination(
                icon: isA && townIcons != null
                    ? TownIcon(townIcons[i])
                    : Icon(icons[i]),
                label: labels[i].tr(),
              ),
          ],
        ),
      );
    },
  );
}
