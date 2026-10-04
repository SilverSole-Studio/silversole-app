import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/shared/pages/foot_check_result_page.dart';

FootCheckReport _report(double foreRatio, double medialRatio) =>
    FootCheckReport(
      balance: FootLoadBalance(foreRatio: foreRatio, medialRatio: medialRatio),
      samples: 1234,
      collected: const Duration(seconds: 60),
    );

/// Only the three grade segments, not the two distribution bars.
int _filledSegments(WidgetTester tester) => tester
    .widgetList<LinearProgressIndicator>(
      find.descendant(
        of: find.byKey(FootCheckResultPage.gradeKey),
        matching: find.byType(LinearProgressIndicator),
      ),
    )
    .where((bar) => bar.value == 1)
    .length;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount, every case: EasyLocalization keeps global state, so a second
  // mount in the same file never leaves its loading state.
  testWidgets('the report names what was measured on both axes', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();

    final report = ValueNotifier(_report(0.40, 0.50));
    addTearDown(report.dispose);

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
            home: ValueListenableBuilder(
              valueListenable: report,
              builder: (_, value, _) => FootCheckResultPage(report: value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A textbook 40/60 split with an even forefoot: both axes balanced.
    expect(find.text('Excellent'), findsOneWidget);
    expect(_filledSegments(tester), FootCheckRating.excellent.level);
    expect(find.text('Forefoot 40%'), findsOneWidget);
    expect(find.text('60% Rearfoot'), findsOneWidget);
    expect(find.text('Medial 50%'), findsOneWidget);
    expect(find.text('50% Lateral'), findsOneWidget);
    expect(
      find.textContaining('Front-to-back load is even'),
      findsOneWidget,
      reason: 'the finding must be real copy and not a CSV key',
    );
    expect(find.textContaining('spread evenly'), findsOneWidget);
    expect(find.textContaining('samples'), findsNothing);

    // Forefoot-heavy: one axis off, and the finding says which way.
    report.value = _report(0.70, 0.50);
    await tester.pumpAndSettle();
    expect(find.text('Very good'), findsOneWidget);
    expect(_filledSegments(tester), FootCheckRating.veryGood.level);
    expect(find.text('Forefoot 70%'), findsOneWidget);
    expect(
      find.textContaining('More load sits on the forefoot'),
      findsOneWidget,
    );

    // Both axes off: the lowest band, naming both findings.
    report.value = _report(0.15, 0.85);
    await tester.pumpAndSettle();
    expect(find.text('Good'), findsOneWidget);
    expect(_filledSegments(tester), FootCheckRating.good.level);
    expect(find.textContaining('More load sits on the heel'), findsOneWidget);
    expect(find.textContaining('leans to the inner edge'), findsOneWidget);

    // Nothing collected: say so rather than show ratios of nothing.
    report.value = FootCheckReport.empty;
    await tester.pumpAndSettle();
    expect(find.text('Not enough data'), findsOneWidget);
    expect(find.byKey(FootCheckResultPage.gradeKey), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}
