import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/widgets/gait/gait_panel.dart';
import 'helpers/translations.dart';

/// Holds whatever history a test hands it, without touching storage.
class _FixedHistory extends GaitHistoryNotifier {
  _FixedHistory(this.days);

  final Map<String, DailyGait> days;

  @override
  Map<String, DailyGait> build() => days;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount: EasyLocalization keeps global state between mounts.
  testWidgets('real mode: no banner, collecting card, then the steps', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final today = gaitDateKey(DateTime.now());
    final scale = ValueNotifier(GaitScale.month);
    addTearDown(scale.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          realGaitEnabledProvider.overrideWithValue(true),
          gaitHistoryProvider.overrideWith(
            () => _FixedHistory({
              today: DailyGait(
                date: today,
                steps: 3200,
                feet: const {
                  GaitFoot.right: FootGaitStats(
                    contacts: 1600,
                    walkingMs: 1920000,
                    stanceMs: 1040000,
                    swingMs: 720000,
                    strides: 1600,
                    strideMs: 1760000,
                    strideSqMs: 1936000000,
                  ),
                },
              ),
            }),
          ),
        ],
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
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ValueListenableBuilder(
                    valueListenable: scale,
                    builder: (_, value, _) => Consumer(
                      builder: (_, ref, _) => GaitAnalysisPanel(
                        snapshot: ref.watch(gaitViewSnapshotProvider(value)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    // Month with one day of data: six more to go, no figures, no banner.
    expect(find.byKey(GaitAnalysisPanel.sampleBannerKey), findsNothing);
    expect(find.byKey(GaitAnalysisPanel.pendingKey), findsOneWidget);
    expect(find.text('Collecting data: 6 more day(s) needed'), findsOneWidget);
    expect(find.text('Falls since the app was opened'), findsOneWidget);

    // Week: today's steps, no phase, no speed, one sole so no balance row.
    scale.value = GaitScale.week;
    await tester.pumpAndSettle();
    expect(find.byKey(GaitAnalysisPanel.pendingKey), findsNothing);
    expect(find.text('3200'), findsOneWidget);
    expect(find.text('Daily walking steps · 7-day average'), findsOneWidget);
    expect(find.text('Walking steps per day'), findsOneWidget);
    expect(find.text('Cadence'), findsOneWidget);
    expect(find.text('Step timing variation'), findsOneWidget);
    expect(find.text('Left-right balance'), findsNothing);
    expect(find.text('Stable'), findsNothing);
    expect(find.text('m/s'), findsNothing);
  });

  test('switched off, the sample comes back', () {
    final container = ProviderContainer(
      overrides: [realGaitEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    final snapshot = container.read(gaitViewSnapshotProvider(GaitScale.week));
    expect(snapshot.isSample, isTrue);
    expect(snapshot.heroValue, gaitSnapshot(GaitScale.week).heroValue);
  });
}
