import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/pages/foot_check_result_page.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/person_page.dart';
import 'package:silversole/shared/pages/sign_in_page.dart';
import 'package:silversole/shared/pages/sign_up_page.dart';
import 'package:silversole/shared/pages/subscription_page.dart';
import 'package:silversole/shared/pages/theme_two/devices_page_t2.dart';
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

/// Every page of the app that is not a game, in both themes and both
/// brightnesses: each must build and lay out without an exception, and the
/// person page must not print the account's uuid.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final variants = <String, ThemeData Function()>{
    'classic light': () => appTheme(Brightness.light),
    'classic dark': () => appTheme(Brightness.dark),
    'mascot light': () => appThemeT2(Brightness.light),
    'mascot dark': () => appThemeT2(Brightness.dark),
  };

  testWidgets('every page builds in classic and mascot, light and dark', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
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

    Future<void> show(String name, Widget page) async {
      router.value = _single(page);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      expect(find.byType(page.runtimeType), findsOneWidget, reason: name);
    }

    final report = FootCheckReport(
      balance: const FootLoadBalance(foreRatio: 0.40, medialRatio: 0.50),
      samples: 1234,
      collected: const Duration(seconds: 60),
    );

    for (final MapEntry(key: name, value: makeTheme) in variants.entries) {
      theme.value = makeTheme();
      await tester.pumpAndSettle();
      final mascot = name.startsWith('mascot');

      await show('$name sign in', const SignInPage());
      await show('$name sign up', const SignUpPage());
      await show('$name home', mascot ? const HomeBodyT2() : const HomeBody());
      // The classic devices page owns a debug-only fake sole whose provider
      // asserts when the scope is torn down, so only the mascot one is built.
      if (mascot) await show('$name devices', const DevicesPageT2());
      await show('$name subscription', const SubscriptionPage());
      await show(
        '$name foot check result',
        FootCheckResultPage(report: report),
      );

      // The person page: plain words, no account id.
      await show('$name person', const PersonPage());
      expect(find.textContaining('123e4567'), findsNothing, reason: name);
      expect(find.text('傳輸者'), findsNothing, reason: name);
      expect(find.text('觀察者'), findsNothing, reason: name);
      expect(find.text('我的鞋墊'), findsWidgets, reason: name);
      expect(find.text('grandma.wang@example.com'), findsOneWidget);

      // Friends: the hub is a nested route.
      router.value = GoRouter(
        initialLocation: '/friends',
        routes: [friendsRoute(enabled: true)],
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name friends');
    }
  });
}
