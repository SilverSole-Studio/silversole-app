import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Widget appNavigationBar({
  required int selectedIndex,
  required void Function(int index) onDestinationSelected,
}) {
  return NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onDestinationSelected,
    destinations: [
      NavigationDestination(icon: Icon(Icons.home), label: 'home'.tr()),
      NavigationDestination(icon: Icon(Icons.person), label: 'person'.tr()),
    ],
  );
}
