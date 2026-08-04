import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/routing/router.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    final darkMode = settings.darkMode;
    final isMascot = settings.themeVariant == AppThemeVariant.mascot;

    ref.watch(bleForegroundControlProvider);

    return MaterialApp.router(
      title: 'Silver Sole',
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      locale: context.locale,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: isMascot
          ? appThemeT2(Brightness.light)
          : appTheme(Brightness.light),
      darkTheme: isMascot
          ? appThemeT2(Brightness.dark)
          : appTheme(Brightness.dark),
      // The mascot design is light-only for now, so pin it to light rather
      // than render a half-designed dark screen.
      themeMode: isMascot
          ? ThemeMode.light
          : (darkMode ? ThemeMode.dark : ThemeMode.light),
      routerConfig: router,
    );
  }
}
