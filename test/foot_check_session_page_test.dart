import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/shared/pages/foot_check_result_page.dart';
import 'package:silversole/shared/pages/foot_check_session_page.dart';

/// Fresh finders per call: Finder instances cache their results, so sharing one
/// across frames reads a stale tree.
Finder session() => find.text('One-minute foot check');
Finder result() => find.text('Check result');
Finder progressBar() => find.byType(LinearProgressIndicator);

void main() {
  // easy_localization persists the chosen locale through shared_preferences;
  // without the mock that channel call never answers and the test blocks
  // forever.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One test for the whole flow on purpose: EasyLocalization keeps global
  // state, so a second mount in the same file never leaves its loading state.
  testWidgets('a session guards both exits and ends on the report', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/foot-check'),
              child: const Text('start'),
            ),
          ),
        ),
        GoRoute(
          path: '/foot-check',
          builder: (_, _) => const FootCheckSessionPage(),
        ),
        GoRoute(
          path: '/foot-check-result',
          builder: (_, state) => FootCheckResultPage(
            report: (state.extra as FootCheckReport?) ?? FootCheckReport.empty,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp.router(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: appTheme(Brightness.light),
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(session(), findsOneWidget);
    expect(find.text('Collecting data…'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('/ 1:00'), findsOneWidget);
    // No sole and no sample clip, so both halves say so.
    expect(find.text('Waiting for sole data'), findsNWidgets(2));

    // Half a minute in: the clock and the bar both moved.
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('0:30'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(progressBar()).value,
      closeTo(0.5, 0.01),
    );

    // The back button abandons, so it asks — and cancelling stays put.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Leave the check?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session(), findsOneWidget, reason: 'cancel keeps collecting');

    // Ending early asks a different question and reports on what it has.
    await tester.tap(find.text('End early'));
    await tester.pumpAndSettle();
    expect(find.text('End the collection early?'), findsOneWidget);
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(session(), findsNothing);
    expect(result(), findsOneWidget);
    // Nothing fed this session, so the report is honest about having nothing
    // to analyse rather than inventing ratios.
    expect(find.text('Not enough data'), findsOneWidget);

    // The report's only way out lands back on the home screen.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result(), findsNothing);
    expect(find.text('start'), findsOneWidget);

    // Letting the minute run out reports on its own.
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    await tester.pump(FootCheckSessionPage.sessionLength);
    await tester.pumpAndSettle();
    expect(result(), findsOneWidget);
  });
}
