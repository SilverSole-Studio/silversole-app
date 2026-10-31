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
import 'package:silversole/shared/widgets/gait/gait_panel_t2.dart';
import 'package:silversole/shared/widgets/gait/mobility_card_view.dart';
import 'helpers/translations.dart';

class _NoHistory extends GaitHistoryNotifier {
  @override
  Map<String, DailyGait> build() => const {};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount of EasyLocalization: it keeps global state between mounts. The
  // provider scope is swapped by key instead.
  testWidgets('the mobility card is on both real panels, not the sample', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);

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
              body: ValueListenableBuilder(
                valueListenable: enabled,
                builder: (_, on, _) => ProviderScope(
                  key: ValueKey(on),
                  overrides: [
                    realGaitEnabledProvider.overrideWithValue(on),
                    gaitHistoryProvider.overrideWith(_NoHistory.new),
                  ],
                  child: SingleChildScrollView(
                    child: Consumer(
                      builder: (_, ref, _) => Column(
                        children: [
                          GaitAnalysisPanel(
                            snapshot: ref.watch(
                              gaitViewSnapshotProvider(GaitScale.week),
                            ),
                            mobility: ref.watch(mobilityCardProvider),
                          ),
                          Theme(
                            data: appThemeT2(Brightness.light),
                            child: GaitAnalysisPanelT2(
                              snapshot: ref.watch(
                                gaitViewSnapshotProvider(GaitScale.week),
                              ),
                              mobility: ref.watch(mobilityCardProvider),
                            ),
                          ),
                        ],
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

    // Sample page: banners are there, the mobility card is not.
    expect(find.byKey(GaitAnalysisPanel.sampleBannerKey), findsOneWidget);
    expect(find.byKey(GaitAnalysisPanelT2.sampleBannerKey), findsOneWidget);
    expect(find.byKey(MobilityCardView.cardKey), findsNothing);
    expect(find.text('Mobility'), findsNothing);

    // Real mode with no history: one card per panel, both still collecting.
    enabled.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(GaitAnalysisPanel.sampleBannerKey), findsNothing);
    expect(find.byKey(MobilityCardView.cardKey), findsNWidgets(2));
    expect(find.text('Mobility'), findsNWidgets(2));
    expect(find.textContaining('· 0 of 3 so far'), findsNWidgets(2));
  });
}
