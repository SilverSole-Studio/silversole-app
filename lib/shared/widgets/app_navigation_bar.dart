import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Widget appNavigationBar({
  required int selectedIndex,
  required void Function(int index) onDestinationSelected,
  required List<IconData> icons,
  required List<String> labels,
}) {
  assert(
    icons.length == labels.length,
    'icons and labels must have the same length',
  );
  return Builder(
    builder: (context) {
      // Hairline divider above the bar (drawn over the bar's background so it
      // reads as a top outline), matching the card borders.
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (var i = 0; i < icons.length; i++)
              NavigationDestination(
                icon: Icon(icons[i]),
                label: labels[i].tr(),
              ),
          ],
        ),
      );
    },
  );
}
