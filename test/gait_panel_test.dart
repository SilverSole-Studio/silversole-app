import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/widgets/gait/gait_panel.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount, every scale: EasyLocalization keeps global state, so a second
  // mount in the same file never leaves its loading state.
  testWidgets('each scale lays out the groups its data supports', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();

    final scale = ValueNotifier(GaitScale.week);
    addTearDown(scale.dispose);

    await tester.pumpWidget(
      EasyLocalization(
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
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder(
                  valueListenable: scale,
                  builder: (_, value, _) => GaitAnalysisPanel(scale: value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both questions the page answers are always on screen as groups.
    expect(find.text('Walking ability'), findsOneWidget);
    expect(find.text('Walking stability'), findsOneWidget);

    // Week: averages only, and no per-step variability metric.
    expect(find.text('0.88'), findsOneWidget);
    expect(find.text('Stable'), findsOneWidget);
    expect(find.text('Daily speed'), findsOneWidget);
    expect(find.text('Cadence'), findsOneWidget);
    expect(find.text('Double support time'), findsOneWidget);
    expect(find.text('Left-right balance'), findsOneWidget);
    expect(find.text('Supporting'), findsOneWidget);
    expect(find.text('Step stability'), findsNothing);
    expect(find.text('Falls in the last 3 months'), findsOneWidget);
    expect(find.text('Suggested next steps'), findsNothing);

    // Month: step stability and the left/right chart appear.
    scale.value = GaitScale.month;
    await tester.pumpAndSettle();
    expect(find.text('Declining'), findsOneWidget);
    expect(find.text('Four-week trend'), findsOneWidget);
    expect(find.text('Step stability'), findsOneWidget);
    expect(find.text('Left and right stance time'), findsOneWidget);
    expect(find.text('Suggested next steps'), findsNothing);

    // Quarter: trajectory, phase timeline, small multiples and advice.
    scale.value = GaitScale.quarter;
    await tester.pumpAndSettle();
    // Twice over: the hero pill and the timeline span it labels.
    expect(find.text('Watch closely'), findsNWidgets(2));
    expect(find.text('Twelve-week trajectory'), findsOneWidget);
    expect(find.text('Phase'), findsOneWidget);
    expect(find.text('Four metrics moving together'), findsOneWidget);
    expect(find.text('Suggested next steps'), findsOneWidget);

    // Every metric can explain itself: the first ⓘ is the phase pill's.
    await tester.tap(find.byIcon(LucideIcons.circleHelp).first);
    await tester.pumpAndSettle();
    expect(find.text('How the phase is decided'), findsOneWidget);
    expect(
      find.text('Worth knowing'),
      findsOneWidget,
      reason: 'the caveat block is what keeps the label honest',
    );
    expect(find.text('Evidence'), findsOneWidget);
  });
}
