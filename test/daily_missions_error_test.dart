import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';
import 'helpers/translations.dart';

/// A plan provider that always fails, to see the sheet without it.
class _FailingPlan extends TodayMissionPlanNotifier {
  @override
  Future<MissionPlan> build() async => throw Exception('storage is gone');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a plan that fails to load shows the rules pick, not a spinner', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final container = ProviderContainer(
      // No automatic retry: it would leave a timer running past the test.
      retry: (_, _) => null,
      overrides: [todayMissionPlanProvider.overrideWith(_FailingPlan.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
              home: const Scaffold(body: DailyMissionsSheet()),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    expect(container.read(todayMissionPlanProvider).hasError, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(3));
    expect(find.text('Measure foot pressure once'), findsOneWidget);
    expect(find.text('3 left today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
