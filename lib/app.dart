import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/routing/router.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
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
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
