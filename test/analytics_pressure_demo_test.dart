import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';

Future<void> _pumpAnalytics(WidgetTester tester, Widget page) async {
  // Pumped through runAsync because easy_localization reads strings.csv off
  // disk, and the fake-async zone never settles on real file I/O.
  await tester.runAsync(
    () => tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: appTheme(Brightness.light),
              home: page,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Switches to the pressure tab, replays the walk clip and returns the
/// pressure the heat map is actually rendering.
Future<List<int>> _playWalkOnPressureTab(WidgetTester tester) async {
  await tester.tap(find.text('Pressure map'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Sample'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.widgetWithText(CheckedPopupMenuItem<void>, 'Walk'));

  // Reading the bundled clip is real file I/O, which only completes outside
  // the fake-async zone. The fake clock stands still meanwhile, so playback is
  // still on frame 0 when we come back.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();

  return tester
      .widget<FootPressureHeatmap>(find.byType(FootPressureHeatmap))
      .pressure;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('classic analytics replays the walk clip on the pressure tab', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpAnalytics(tester, const AnalyticsPage());

    // First frame of silversole_v1.1_walk_right.json.
    expect(await _playWalkOnPressureTab(tester), [600, 380, 2600]);

    // Leave playback stopped so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Sample'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(PopupMenuItem<void>, 'Stop sample'));
    await tester.pumpAndSettle();
  });

  testWidgets('mascot analytics replays the walk clip on the pressure tab', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpAnalytics(tester, const AnalyticsPageT2());

    expect(await _playWalkOnPressureTab(tester), [600, 380, 2600]);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Sample'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(PopupMenuItem<void>, 'Stop sample'));
    await tester.pumpAndSettle();
  });

  testWidgets('the demo scope falls back to live telemetry when idle', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpAnalytics(
      tester,
      Scaffold(
        body: PressureDemoScope(
          builder: (context, reading, header) => Column(
            children: [
              header,
              Text('p=${reading.right}'),
              Text('left=${reading.left}'),
              Text('has=${reading.hasData}'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('p=[0, 0, 0]'), findsOneWidget);
    expect(find.text('has=false'), findsOneWidget);
    // No left-foot source exists yet, real or sample.
    expect(find.text('left=null'), findsOneWidget);
  });
}
