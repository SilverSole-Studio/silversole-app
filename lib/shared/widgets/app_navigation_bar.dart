import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

Widget appNavigationBar({
  required int selectedIndex,
  required void Function(int index) onDestinationSelected,
}) {
  return NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onDestinationSelected,
    destinations: [
      NavigationDestination(icon: Icon(Icons.home), label: 'home'.tr()),
      NavigationDestination(icon: Icon(LucideIcons.monitorSmartphone), label: 'devices'.tr()),
      NavigationDestination(icon: Icon(Icons.analytics), label: 'analytics'.tr()),
      NavigationDestination(icon: Icon(Icons.settings), label: 'settings'.tr()),
    ],
  );
}
