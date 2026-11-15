import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/map_page.dart';
import 'package:silversole/shared/pages/person_page.dart';
import 'package:silversole/shared/pages/theme_b/home_body_b.dart';
import 'package:silversole/shared/pages/theme_c/home_body_c.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart';
import 'package:silversole/shared/pages/theme_two/map_page_t2.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'helpers/translations.dart';

class _SignedIn extends AuthUserNotifier {
  @override
  UserData? build() => const UserData(
    email: 'grandma.wang@example.com',
    uuid: '123e4567-e89b-12d3-a456-426614174000',
  );
}

/// A paired sole, so the pages that show a device have something to draw.
class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(
    pairedDevicesList: [
      BlePairedDevice(
        remoteId: 'r',
        name: 'SilverSole',
        deviceId: '00000000000000BB',
        isPreferred: true,
        lastBatteryPercent: 77,
      ),
    ],
  );
}

GoRouter _single(Widget page) => GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => page)],
);

/// Tablet screens (iPad landscape / portrait): the main tabs must lay out
/// without an overflow or any other exception. The test binding turns a
/// RenderFlex overflow into a thrown FlutterError, which `takeException`
/// catches.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const sizes = <String, Size>{
    'iPad landscape 1366x1024': Size(1366, 1024),
    'iPad landscape 1180x820': Size(1180, 820),
    'iPad portrait 1024x1366': Size(1024, 1366),
    // Stage Manager windows can be small and wide.
    'Stage Manager window 900x700': Size(900, 700),
  };

  // One test body: EasyLocalization's asset load only settles once per test
  // binding, so the sizes are looped inside it.
  testWidgets('main tabs lay out on tablet screens in all five looks', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeFriendsRepository.seeded(
      latency: Duration.zero,
      simulateQrScan: false,
    );
    final router = ValueNotifier<GoRouter>(_single(const SizedBox()));
    final theme = ValueNotifier<ThemeData>(appTheme(Brightness.light));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(repo),
          authUserProvider.overrideWith(_SignedIn.new),
          settingsProvider.overrideWith(_Settings.new),
          firmwareCheckProvider.overrideWith(
            (ref) async =>
                const FirmwareCheck(FirmwareCheckStatus.notConnected),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('zh', 'TW'),
          child: Builder(
            builder: (context) => ValueListenableBuilder<ThemeData>(
              valueListenable: theme,
              builder: (_, t, _) => ValueListenableBuilder<GoRouter>(
                valueListenable: router,
                builder: (_, current, _) => MaterialApp.router(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  theme: t,
                  builder: (context, child) => applySystemFontScale(
                    context,
                    child,
                    textSize: AppTextSize.normal,
                  ),
                  routerConfig: current,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    var label = '';
    Future<void> show(String name, Widget page) async {
      router.value = _single(page);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label $name');
    }

    for (final MapEntry(key: sizeLabel, value: size) in sizes.entries) {
      label = sizeLabel;
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      for (final MapEntry(key: variant, value: makeTheme) in {
        for (final v in AppThemeVariant.values) v: () => appThemeFor(v),
      }.entries) {
        final name = variant.name;
        theme.value = makeTheme();
        await tester.pumpAndSettle();
        final mascot = variant == AppThemeVariant.mascot;

        await show('$name home', switch (variant) {
          AppThemeVariant.mascot => const HomeBodyT2(),
          AppThemeVariant.dashboard => const HomeBodyB(),
          AppThemeVariant.journal => const HomeBodyC(),
          _ => const HomeBody(),
        });
        await show(
          '$name map',
          mascot
              ? MapPageT2(mapBuilder: (center, show) => const SizedBox())
              : MapPage(mapBuilder: (center, show) => const SizedBox()),
        );
        await show(
          '$name analytics',
          mascot ? const AnalyticsPageT2() : const AnalyticsPage(),
        );
        await show('$name person', const PersonPage());

        router.value = GoRouter(
          initialLocation: '/friends',
          routes: [friendsRoute(enabled: true)],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label $name friends');
      }
    }
  });
}
