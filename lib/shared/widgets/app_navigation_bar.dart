import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget appNavigationBar({
  required int selectedIndex,
  required void Function(int index) onDestinationSelected,
}) {
  return Builder(
    builder: (context) {
      // Hairline divider above the bar (drawn over the bar's background so it
      // reads as a top outline), matching the card borders.
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            NavigationDestination(icon: Icon(Icons.home), label: 'home'.tr()),
            NavigationDestination(
              icon: Icon(LucideIcons.monitorSmartphone),
              label: 'devices'.tr(),
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics),
              label: 'analytics'.tr(),
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.footprints),
              label: 'pressure_visualization'.tr(),
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              label: 'settings'.tr(),
            ),
          ],
        ),
      );
    },
  );
}
