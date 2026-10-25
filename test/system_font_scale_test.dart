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
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/person_page.dart';
import 'package:silversole/shared/pages/sign_in_page.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/pages/sign_up_page.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/app_navigation_bar.dart';

/// Seniors run the phone's font size at its largest. The app caps its own text
/// at [kMaxAppTextScale]; pages must not overflow at the cap, or when the
/// system asks for far more (2.0).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('systemFontScaleOf', () {
    test('no scaling is 1.0', () {
      expect(systemFontScaleOf(TextScaler.noScaling), 1.0);
    });

    test('a linear scaler gives its factor', () {
      expect(systemFontScaleOf(const TextScaler.linear(1.5)), 1.5);
      expect(systemFontScaleOf(const TextScaler.linear(2.0)), 2.0);
    });
  });

  testWidgets('the app text scaler is capped, the real scale is kept', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    late TextScaler seen;
    late double real;
    await tester.pumpWidget(
      MaterialApp(
        builder: applySystemFontScale,
        home: Builder(
          builder: (context) {
            seen = MediaQuery.textScalerOf(context);
            real = SystemFontScale.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(seen.scale(10), closeTo(10 * kMaxAppTextScale, 0.001));
    expect(real, 2.0);
  });

  testWidgets('a smaller system scale is passed through untouched', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    late TextScaler seen;
    await tester.pumpWidget(
      MaterialApp(
        builder: applySystemFontScale,
        home: Builder(
          builder: (context) {
            seen = MediaQuery.textScalerOf(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(seen.scale(10), closeTo(11, 0.001));
  });

  // 360 x 640: a small, common Android size. Every page is shown with the
  // system font at 1.3 (the cap) and at 2.0 (through the app's builder).
  // A RenderFlex overflow is reported as a framework exception, which
  // `takeException` returns.
  //
  // One mount for the whole run: EasyLocalization keeps global state, so a
  // second `pumpWidget(EasyLocalization(...))` in the same file stays blank.
  testWidgets('main pages do not overflow with a huge system font', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final repo = FakeFriendsRepository.seeded(
      latency: Duration.zero,
      simulateQrScan: false,
    );
    final router = ValueNotifier<GoRouter>(_single(const SizedBox()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(repo),
          // Signed in with a long address: the settings page shows the most.
          authUserProvider.overrideWith(_SignedIn.new),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('zh', 'TW'),
          child: Builder(
            builder: (context) => ValueListenableBuilder<GoRouter>(
              valueListenable: router,
              builder: (_, current, _) => MaterialApp.router(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appTheme(Brightness.light),
                builder: applySystemFontScale,
                routerConfig: current,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> show(String name, Widget page) async {
      router.value = _single(page);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      expect(find.byType(page.runtimeType), findsOneWidget, reason: name);
    }

    for (final system in [1.3, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = system;
      await tester.pumpAndSettle();
      final at = 'system font x$system';

      await show('$at sign in', const SignInPage());
      await show('$at sign up', const SignUpPage());
      await show('$at settings', const PersonPage());
      await show('$at home without a device', const HomeBody());
      await show(
        '$at bottom navigation',
        Scaffold(
          bottomNavigationBar: appNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            icons: const [
              Icons.home,
              Icons.map,
              Icons.gamepad,
              Icons.analytics,
              Icons.settings,
            ],
            labels: const ['home', 'map', 'game', 'analytics', 'settings'],
          ),
        ),
      );
    }

    // Friends: the name step, then the hub, requests and the code keypad.
    for (final system in [1.3, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = system;
      final at = 'system font x$system friends';
      final friends = GoRouter(
        initialLocation: '/friends',
        routes: [friendsRoute(enabled: true)],
      );
      router.value = friends;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$at name step');

      // Only the first visit asks for a name (it is remembered after).
      if (find.text('先取一個稱呼').evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), '王阿姨');
        final done = find.text('好了，去加朋友');
        await tester.scrollUntilVisible(
          done,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull, reason: '$at name step');
        await tester.tap(done);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: '$at hub');
      expect(find.textContaining('朋友（'), findsOneWidget, reason: '$at hub');

      await tester.tap(find.text('邀請'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$at requests');
      friends.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('輸入好友碼'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$at keypad');
    }
  });
}

GoRouter _single(Widget page) => GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => page)],
);

class _SignedIn extends AuthUserNotifier {
  @override
  UserData? build() => const UserData(
    email: 'grandma.wang.long.address@example.com',
    uuid: '123e4567-e89b-12d3-a456-426614174000',
  );
}
