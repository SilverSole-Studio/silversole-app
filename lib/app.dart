import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/routing/router.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/pages/foot_side_calibration_modal.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/dismiss_keyboard_on_tap_outside.dart';
import 'package:silversole/shared/widgets/fall_demo_overlay.dart';

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
    // Both run for the whole app session: gait totals and the fall count
    // must not start only when the gait tab is first opened.
    ref.watch(gaitTrackingProvider);
    ref.watch(fallCountSinceOpenProvider);

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
      // Both wrap every page in either theme. The fall panel is outermost on
      // purpose: it is a latching alarm and nothing, including the
      // calibration question, may cover it or steal its dismiss button.
      // Remove it together with FallDemoOverlay.
      //
      // The system font scale is capped (see [kMaxAppTextScale]) outside of
      // all of them, so the overlays are capped too.
      builder: (context, child) => applySystemFontScale(
        context,
        DismissKeyboardOnTapOutside(
          child: FallDemoOverlay(
            child: FootSideCalibrationOverlay(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
