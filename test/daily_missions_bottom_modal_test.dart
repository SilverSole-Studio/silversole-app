import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'helpers/translations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount, every case: EasyLocalization keeps global state, so a second
  // mount in the same file never leaves its loading state.
  testWidgets('only real missions, done only when the app knows it happened', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final container = ProviderContainer();
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

    // No foot check yet: both missions wait, nothing reads as done.
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(2));
    expect(find.text('Done'), findsNothing);
    expect(find.text('2 left today'), findsOneWidget);

    // No pedometer, so no walking mission and no step counts; no rewards.
    expect(find.textContaining('steps'), findsNothing);
    expect(find.textContaining('+'), findsNothing);
    expect(find.textContaining('Coins'), findsNothing);

    // A foot check finished today completes the measuring mission.
    await container
        .read(lastFootCheckProvider.notifier)
        .record(
          FootCheckRecord(
            rating: FootCheckRating.good,
            takenAt: DateTime.now(),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Go'), findsOneWidget);
    expect(find.text('Done'), findsNWidgets(2), reason: 'subtitle + pill');
    expect(find.text('1 left today'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
