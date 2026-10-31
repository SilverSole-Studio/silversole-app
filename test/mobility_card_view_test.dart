import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/mobility_card.dart';
import 'package:silversole/shared/widgets/gait/gait_charts.dart';
import 'package:silversole/shared/widgets/gait/mobility_card_view.dart';
import 'helpers/translations.dart';

const _disclaimer =
    'This record is for health promotion and exercise participation and is '
    'not a medical diagnosis';

const _letters = ['A', 'B', 'C', 'D', 'E'];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount: EasyLocalization keeps global state between mounts.
  testWidgets('graded and pending cards, in both themes', (tester) async {
    await EasyLocalization.ensureInitialized();
    final shown = ValueNotifier<(MobilityCard, ThemeData)>((
      const MobilityGraded(
        weekStart: '2026-11-02',
        isCurrentWeek: true,
        grade: MobilityGrade.a,
        changes: [
          MobilityChange(metric: MobilityMetric.dailySteps, better: true),
          MobilityChange(metric: MobilityMetric.cadence, better: true),
        ],
        rows: [
          MobilityMetricRow(
            metric: MobilityMetric.dailySteps,
            grade: MobilityGrade.a,
            trend: [3000, 3100, 3900],
          ),
          MobilityMetricRow(
            metric: MobilityMetric.cadence,
            grade: MobilityGrade.b,
            trend: [],
          ),
        ],
      ),
      appTheme(Brightness.light),
    ));
    addTearDown(shown.dispose);

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
            home: ValueListenableBuilder(
              valueListenable: shown,
              builder: (_, value, _) => Theme(
                data: value.$2,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: MobilityCardView(card: value.$1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    // A graded current week: letter, line, the two changes, only the metrics
    // that have a grade, a trend line only where there is a trend.
    expect(find.byKey(MobilityCardView.cardKey), findsOneWidget);
    expect(find.text('Mobility'), findsOneWidget);
    expect(find.text('Compared with your own recent weeks'), findsOneWidget);
    expect(find.text('This week (in progress)'), findsOneWidget);
    expect(find.text('A'), findsNWidgets(2)); // main box and the steps row
    expect(find.text('Much better than usual'), findsOneWidget);
    expect(
      find.text('This week mainly: more steps each day and a quicker cadence'),
      findsOneWidget,
    );
    expect(find.text('Daily steps'), findsOneWidget);
    expect(find.text('Cadence'), findsOneWidget);
    expect(find.text('Left-right balance'), findsNothing);
    expect(find.text('Step timing variation'), findsNothing);
    expect(find.text('Double support time'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(GaitSparkline), findsOneWidget);
    expect(find.text(_disclaimer), findsOneWidget);

    // An earlier week that went down: dated label, its own wording.
    shown.value = (
      const MobilityGraded(
        weekStart: '2026-11-02',
        isCurrentWeek: false,
        grade: MobilityGrade.e,
        changes: [
          MobilityChange(metric: MobilityMetric.symmetry, better: false),
        ],
        rows: [
          MobilityMetricRow(
            metric: MobilityMetric.symmetry,
            grade: MobilityGrade.e,
            trend: [0.95, 0.9],
          ),
        ],
      ),
      appThemeT2(Brightness.light),
    );
    await tester.pumpAndSettle();
    expect(find.text('Week of 11/2'), findsOneWidget);
    expect(find.text('Less than usual two weeks running'), findsOneWidget);
    expect(
      find.text('This week mainly: a bigger gap between feet'),
      findsOneWidget,
    );
    expect(find.text('E'), findsNWidgets(2));
    expect(find.text('Left-right balance'), findsOneWidget);
    expect(find.text(_disclaimer), findsOneWidget);

    // Not enough weeks: the sentence and the disclaimer, no letter, no line.
    shown.value = (
      const MobilityPending(weeksSoFar: 2, weeksNeeded: 3),
      appTheme(Brightness.dark),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Comparisons start after 2 weeks with at least 3 worn days each · '
        '2 so far',
      ),
      findsOneWidget,
    );
    expect(find.text(_disclaimer), findsOneWidget);
    for (final letter in _letters) {
      expect(find.text(letter), findsNothing);
    }
    expect(find.byType(GaitSparkline), findsNothing);
    expect(find.textContaining('usual'), findsNothing);
  });
}
