import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/pressure_visualization_page.dart';

Future<void> _pumpPage(WidgetTester tester) async {
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
              home: const PressureVisualizationPage(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the sample menu and waits out its reveal animation. Avoids
/// `pumpAndSettle`, which never returns once a clip is looping.
Future<void> _openSampleMenu(WidgetTester tester) async {
  await tester.tap(find.text('Sample'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows placeholder readouts while no telemetry has arrived', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpPage(tester);

    // Both feet by default: three sensors each, and nothing feeds either yet.
    expect(find.text('--'), findsNWidgets(6));
  });

  testWidgets('picking Walk from the sample menu replays the bundled clip', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpPage(tester);

    await _openSampleMenu(tester);
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<void>, 'Walk'));

    // Reading the bundled clip is real file I/O, which only completes outside
    // the fake-async zone. The fake clock stands still meanwhile, so playback
    // is still on frame 0 when we come back.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();

    // First frame of synthetic_walk_pair_30s.json — right foot...
    expect(find.text('600'), findsOneWidget);
    expect(find.text('380'), findsOneWidget);
    expect(find.text('2600'), findsOneWidget);
    // ...and the left foot of the same pair, on the same frame.
    expect(find.text('2300'), findsOneWidget);
    expect(find.text('2080'), findsOneWidget);
    expect(find.text('--'), findsNothing);

    // The 50 Hz clip is decimated to 25 Hz, so a frame lasts 40 ms.
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('600'), findsNothing);

    // The 750-frame clip is 30 s long: pumping the rest of it wraps back to
    // frame 0, and it keeps going for as many laps as we ask for.
    await tester.pump(const Duration(milliseconds: 40 * 749));
    expect(find.text('600'), findsOneWidget);
    expect(find.text('2600'), findsOneWidget);

    for (var lap = 0; lap < 5; lap++) {
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('600'), findsOneWidget, reason: 'lap ${lap + 2}');
      expect(find.text('2600'), findsOneWidget, reason: 'lap ${lap + 2}');
    }

    // Stopping falls back to live telemetry, which is empty in this test.
    await tester.pump(const Duration(milliseconds: 500));
    await _openSampleMenu(tester);
    await tester.tap(find.widgetWithText(PopupMenuItem<void>, 'Stop sample'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('--'), findsNWidgets(6));
  });
}
