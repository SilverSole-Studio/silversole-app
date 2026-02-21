import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/routing/router.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final darkMode = settings.darkMode;
    
    ref.watch(bleForegroundControlProvider);

    return MaterialApp.router(
      title: 'Silver Sole',
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
