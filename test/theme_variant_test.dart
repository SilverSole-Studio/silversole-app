import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/theme_picker_page.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';
import 'package:silversole/shared/providers/theme_variant_provider.dart';

import 'helpers/translations.dart';

ProviderContainer _container({required bool subscribed}) {
  final c = ProviderContainer(
    overrides: [subscriptionActiveProvider.overrideWithValue(subscribed)],
  );
  addTearDown(c.dispose);
  return c;
}

/// Lets the settings notifier finish loading what is stored on the phone:
/// waits until the look is [expect], or a moment when nothing is expected to
/// change.
Future<void> _loaded(ProviderContainer c, {AppThemeVariant? expect}) async {
  c.listen(settingsProvider, (_, _) {});
  if (expect == null) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return;
  }
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (c.read(settingsProvider).themeVariant == expect) return;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('which look is stored', () {
    test('nothing stored is the mascot look, A', () {
      expect(AppThemeVariant.fromStored(null), AppThemeVariant.mascot);
    });

    test('the old 插畫 theme becomes A', () {
      expect(AppThemeVariant.fromStored('mascot'), AppThemeVariant.mascot);
      expect(
        AppThemeVariant.fromStored('mascot', storedDarkMode: 'true'),
        AppThemeVariant.mascot,
      );
    });

    test('the old 經典 theme becomes 極簡科技 白 or 黑 by its dark switch', () {
      expect(AppThemeVariant.fromStored('classic'), AppThemeVariant.techLight);
      expect(
        AppThemeVariant.fromStored('classic', storedDarkMode: 'false'),
        AppThemeVariant.techLight,
      );
      expect(
        AppThemeVariant.fromStored('classic', storedDarkMode: 'true'),
        AppThemeVariant.techDark,
      );
    });

    test('every look reads back its own stored name', () {
      for (final v in AppThemeVariant.values) {
        expect(AppThemeVariant.fromStored(v.wireName), v);
      }
    });

    test('something unknown falls back to A', () {
      expect(AppThemeVariant.fromStored('neon'), AppThemeVariant.mascot);
    });

    test('three looks are free and two need a subscription', () {
      expect(AppThemeVariant.free, [
        AppThemeVariant.mascot,
        AppThemeVariant.techLight,
        AppThemeVariant.techDark,
      ]);
      expect(AppThemeVariant.values.where((v) => v.requiresSubscription), [
        AppThemeVariant.dashboard,
        AppThemeVariant.journal,
      ]);
    });

    test('light or dark belongs to the look', () {
      for (final v in AppThemeVariant.values) {
        final theme = appThemeFor(v);
        expect(theme.brightness, v.brightness, reason: v.name);
        expect(theme.extension<AppLook>()?.variant, v, reason: v.name);
      }
      expect(AppThemeVariant.techDark.brightness, Brightness.dark);
      expect(AppThemeVariant.techLight.brightness, Brightness.light);
    });
  });

  group('settings', () {
    test('a fresh phone starts on A', () async {
      final c = _container(subscribed: false);
      await _loaded(c);
      expect(c.read(settingsProvider).themeVariant, AppThemeVariant.mascot);
      expect(c.read(themeVariantProvider), AppThemeVariant.mascot);
    });

    test('an old 經典 + dark switch on opens as 極簡科技・黑 and is stored', () async {
      SharedPreferences.setMockInitialValues({
        'theme_variant': 'classic',
        'dark_mode_v2': 'true',
      });
      final c = _container(subscribed: false);
      await _loaded(c, expect: AppThemeVariant.techDark);
      expect(c.read(settingsProvider).themeVariant, AppThemeVariant.techDark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_variant'), 'tech_dark');
    });

    test('an old 經典 with the switch off opens as 極簡科技・白', () async {
      SharedPreferences.setMockInitialValues({'theme_variant': 'classic'});
      final c = _container(subscribed: false);
      await _loaded(c, expect: AppThemeVariant.techLight);
      expect(c.read(settingsProvider).themeVariant, AppThemeVariant.techLight);
    });

    test('an old 插畫 theme opens as A', () async {
      SharedPreferences.setMockInitialValues({'theme_variant': 'mascot'});
      final c = _container(subscribed: false);
      await _loaded(c);
      expect(c.read(settingsProvider).themeVariant, AppThemeVariant.mascot);
    });

    test('the three free looks can be picked without a subscription', () async {
      final c = _container(subscribed: false);
      await _loaded(c);
      final notifier = c.read(settingsProvider.notifier);
      for (final v in AppThemeVariant.free) {
        expect(await notifier.setThemeVariant(v), isTrue, reason: v.name);
        expect(c.read(themeVariantProvider), v);
      }
    });

    test('B and C can be picked by everyone during 限時免費', () async {
      final c = _container(subscribed: false);
      await _loaded(c);
      final notifier = c.read(settingsProvider.notifier);
      for (final v in [AppThemeVariant.dashboard, AppThemeVariant.journal]) {
        expect(await notifier.setThemeVariant(v), kPaidThemesFreeTrial);
        expect(c.read(themeVariantProvider) == v, kPaidThemesFreeTrial);
      }
    });

    test(
      'B and C are refused without a subscription',
      skip: kPaidThemesFreeTrial,
      () async {
        final c = _container(subscribed: false);
        await _loaded(c);
        final notifier = c.read(settingsProvider.notifier);
        await notifier.setThemeVariant(AppThemeVariant.techDark);
        for (final v in [AppThemeVariant.dashboard, AppThemeVariant.journal]) {
          expect(await notifier.setThemeVariant(v), isFalse, reason: v.name);
          expect(
            c.read(settingsProvider).themeVariant,
            AppThemeVariant.techDark,
          );
        }
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_variant'), 'tech_dark');
      },
    );

    test('B and C can be picked with a subscription', () async {
      final c = _container(subscribed: true);
      await _loaded(c);
      final notifier = c.read(settingsProvider.notifier);
      expect(await notifier.setThemeVariant(AppThemeVariant.dashboard), isTrue);
      expect(c.read(themeVariantProvider), AppThemeVariant.dashboard);
      expect(await notifier.setThemeVariant(AppThemeVariant.journal), isTrue);
      expect(c.read(themeVariantProvider), AppThemeVariant.journal);
    });

    test(
      'an expired subscription draws A again, and keeps the choice',
      skip: kPaidThemesFreeTrial,
      () async {
        SharedPreferences.setMockInitialValues({'theme_variant': 'dashboard'});
        final c = _container(subscribed: false);
        await _loaded(c, expect: AppThemeVariant.dashboard);
        // Chosen B, but nothing pays for it now.
        expect(
          c.read(settingsProvider).themeVariant,
          AppThemeVariant.dashboard,
        );
        expect(c.read(themeVariantProvider), AppThemeVariant.mascot);

        // Subscribed again: B is back.
        final again = _container(subscribed: true);
        await _loaded(again, expect: AppThemeVariant.dashboard);
        expect(again.read(themeVariantProvider), AppThemeVariant.dashboard);
      },
    );
  });

  group('the theme page', () {
    Future<(ProviderContainer, GoRouter)> pump(
      WidgetTester tester, {
      required bool subscribed,
    }) async {
      await EasyLocalization.ensureInitialized();
      tester.view
        ..physicalSize = const Size(412, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [subscriptionActiveProvider.overrideWithValue(subscribed)],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ThemePickerPage()),
          GoRoute(
            path: '/subscription',
            builder: (_, _) => const Scaffold(body: Text('subscription page')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
            path: 'assets/translations/strings.csv',
            assetLoader: CsvAssetLoader(),
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('zh', 'TW'),
            child: Builder(
              builder: (context) => MaterialApp.router(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appThemeFor(AppThemeVariant.mascot),
                routerConfig: router,
              ),
            ),
          ),
        ),
      );
      await settleTranslations(tester);
      return (container, router);
    }

    // One test, not four: easy_localization loads its strings once per test
    // binding, so a second testWidgets in this file would stay blank.
    testWidgets('free looks switch at once; B and C follow the subscription', (
      tester,
    ) async {
      const free = ['粗哥手繪小鎮', '極簡科技・白', '極簡科技・黑'];
      const forSubscribers = ['大數字儀表板', '紙本手帳'];
      final (container, _) = await pump(tester, subscribed: false);
      for (final name in free) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      if (kSubscriptionOffered || kPaidThemesFreeTrial) {
        for (final name in forSubscribers) {
          expect(find.text(name), findsOneWidget, reason: name);
        }
        expect(find.byType(ThemeThumb), findsNWidgets(5));
        expect(
          find.text('訂閱後可用'),
          kPaidThemesFreeTrial ? findsNothing : findsNWidgets(2),
        );
        expect(
          find.text('限時免費'),
          kPaidThemesFreeTrial ? findsNWidgets(2) : findsNothing,
        );
      } else {
        // Not sold yet: nothing on the page leads to the subscription.
        for (final name in forSubscribers) {
          expect(find.text(name), findsNothing, reason: name);
        }
        expect(find.byType(ThemeThumb), findsNWidgets(3));
        expect(find.text('訂閱後可用'), findsNothing);
      }

      // A free look switches at once.
      await tester.tap(find.text('極簡科技・黑'));
      await tester.pumpAndSettle();
      expect(container.read(themeVariantProvider), AppThemeVariant.techDark);

      if (kPaidThemesFreeTrial) {
        // 限時免費: B and C switch at once, no subscription needed.
        await tester.tap(find.text('大數字儀表板'));
        await tester.pumpAndSettle();
        expect(container.read(themeVariantProvider), AppThemeVariant.dashboard);
        await tester.tap(find.text('紙本手帳'));
        await tester.pumpAndSettle();
        expect(container.read(themeVariantProvider), AppThemeVariant.journal);
      } else if (kSubscriptionOffered) {
        // A locked look opens the subscription page instead, and nothing
        // changes.
        await tester.tap(find.text('大數字儀表板'));
        await tester.pumpAndSettle();
        expect(find.text('subscription page'), findsOneWidget);
        expect(container.read(themeVariantProvider), AppThemeVariant.techDark);
      }

      // A subscriber (an account opened by hand counts) sees all five, no lock.
      await pump(tester, subscribed: true);
      for (final name in [...free, ...forSubscribers]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('訂閱後可用'), findsNothing);
    });
  });
}
