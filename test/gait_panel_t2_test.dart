import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/widgets/gait/gait_panel_t2.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the mascot panel renders the same sections on every scale', (
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
            theme: appThemeT2(Brightness.light),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder(
                  valueListenable: scale,
                  builder: (_, value, _) => GaitAnalysisPanelT2(scale: value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Walking ability'), findsOneWidget);
    expect(find.text('Walking stability'), findsOneWidget);
    expect(find.text('0.88'), findsOneWidget);
    expect(find.text('Stable'), findsOneWidget);
    expect(find.text('Step stability'), findsNothing);

    scale.value = GaitScale.month;
    await tester.pumpAndSettle();
    expect(find.text('Step stability'), findsOneWidget);
    expect(find.text('Left and right stance time'), findsOneWidget);

    scale.value = GaitScale.quarter;
    await tester.pumpAndSettle();
    expect(find.text('Four metrics moving together'), findsOneWidget);
    expect(find.text('Suggested next steps'), findsOneWidget);
  });
}
