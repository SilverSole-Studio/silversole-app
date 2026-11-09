import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/home_page.dart';
import 'package:silversole/shared/pages/map_page.dart';
import 'package:silversole/shared/pages/theme_b/home_body_b.dart';
import 'package:silversole/shared/pages/theme_c/home_body_c.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/pages/theme_two/map_page_t2.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/widgets/app_navigation_bar.dart';
import 'package:silversole/shared/widgets/fall_guard_card.dart';
import 'helpers/translations.dart';

class _SignedOut extends AuthUserNotifier {
  @override
  UserData? build() => null;
}

GoRouter _single(Widget page) => GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => page)],
);

/// The five tabs are 今天／地圖／遊戲／報告／我的 with one icon family and
/// labels that stay readable at the default 「標準」 text size; fall detection
/// lives on the map tab and no longer on the home page.
Widget _homeFor(AppThemeVariant v) => switch (v) {
  AppThemeVariant.mascot => const HomeBodyT2(),
  AppThemeVariant.dashboard => const HomeBodyB(),
  AppThemeVariant.journal => const HomeBodyC(),
  _ => const HomeBody(),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('nav names, readable labels, and where the fall card lives', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [authUserProvider.overrideWith(_SignedOut.new)],
    );
    addTearDown(container.dispose);
    final router = ValueNotifier<GoRouter>(_single(const SizedBox()));
    final theme = ValueNotifier<ThemeData>(appTheme(Brightness.light));

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
            builder: (context) => ValueListenableBuilder<ThemeData>(
              valueListenable: theme,
              builder: (_, t, _) => ValueListenableBuilder<GoRouter>(
                valueListenable: router,
                builder: (_, current, _) => MaterialApp.router(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  theme: t,
                  // The default text size: 「標準」 scales everything by 0.9.
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

    Future<void> show(Widget page) async {
      router.value = _single(page);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    final themes = {
      for (final v in AppThemeVariant.values) v.name: appThemeFor(v),
    };

    for (final MapEntry(key: name, value: t) in themes.entries) {
      theme.value = t;
      await tester.pumpAndSettle();

      // ── Five tabs, in order, named for what the person does there. ──────
      await show(
        Scaffold(
          bottomNavigationBar: appNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            icons: kHomeNavIcons,
            labels: kHomeNavLabels,
          ),
        ),
      );
      final labels = ['今天', '地圖', '遊戲', '報告', '我的'];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget, reason: '$name: $label');
      }
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      // The old names are gone.
      for (final old in ['主頁', '分析', '設定']) {
        expect(find.text(old), findsNothing, reason: '$name: $old');
      }
      // One icon family: every tab icon is a Lucide line icon.
      for (final icon in kHomeNavIcons) {
        expect(icon.fontFamily, 'Lucide', reason: name);
      }
      // Standard text size: the rendered label is still at least 12.
      for (final label in labels) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        final size = paragraph.textScaler.scale(
          paragraph.text.style!.fontSize!,
        );
        expect(
          size,
          greaterThanOrEqualTo(12),
          reason: '$name: nav label $label rendered at $size',
        );
      }

      // ── Fall card: map tab yes, home tab no. ────────────────────────────
      final mascot = name == AppThemeVariant.mascot.name;
      final home = _homeFor(AppThemeVariant.values.byName(name));
      await show(
        mascot
            ? MapPageT2(
                mapBuilder: (center, show) => const SizedBox(height: 200),
              )
            : MapPage(
                mapBuilder: (center, show) => const SizedBox(height: 200),
              ),
      );
      expect(find.byType(FallGuardCard), findsOneWidget, reason: name);
      expect(find.text('跌倒守護運作中'), findsOneWidget, reason: name);
      expect(find.text('開啟 App 以來未偵測到跌倒'), findsOneWidget);

      await show(home);
      expect(find.byType(FallGuardCard), findsNothing, reason: name);
      expect(find.text('跌倒守護運作中'), findsNothing, reason: name);
      // Nor the old classic "safety events" card.
      expect(find.text('件安全事件已偵測'), findsNothing, reason: name);
    }

    // The map page's card counts falls reported since the app opened.
    theme.value = appThemeT2();
    await show(MapPageT2(mapBuilder: (center, show) => const SizedBox()));
    container.read(fallCountSinceOpenProvider);
    container
        .read(fallEventBusProvider)
        .emit(
          FallDetectEvent(
            timestamp: DateTime(2026, 11, 3),
            deviceId: 'd',
            detect: true,
          ),
        );
    await tester.pumpAndSettle();
    expect(container.read(fallCountSinceOpenProvider), 1);
    expect(find.text('開啟 App 以來偵測到 1 次跌倒'), findsOneWidget);
  });
}
