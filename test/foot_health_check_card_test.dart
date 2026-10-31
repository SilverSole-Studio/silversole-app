import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/widgets/foot_health_check_card.dart';
import 'helpers/translations.dart';

/// Every text inside [card] that contains a digit.
Finder _digitsIn(Finder card) => find.descendant(
  of: card,
  matching: find.byWidgetPredicate(
    (w) => w is Text && RegExp(r'\d').hasMatch(w.data ?? ''),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount for both home cards and every case: EasyLocalization keeps
  // global state, so a second mount in the same file never leaves its loading
  // state.
  testWidgets('both home foot-check cards show the last real result or none', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // A real router, because the CTA navigates. The destination is a
    // stand-in: where '/foot-check' leads is the router's business, not the
    // card's, and the real session page would leave its minute-long timer
    // running.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [FootHealthCheckCard(), FootCheckCardT2()],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/foot-check',
          builder: (_, _) => const Scaffold(body: Text('session')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    await settleTranslations(tester);

    final classic = find.byType(FootHealthCheckCard);
    final mascot = find.byType(FootCheckCardT2);

    // Never checked: an honest empty state in both, and no number anywhere.
    expect(find.text('No foot check yet'), findsNWidgets(2));
    expect(_digitsIn(classic), findsNothing);
    expect(_digitsIn(mascot), findsNothing);

    // A finished check shows its band and when it was taken.
    final takenAt = DateTime(2026, 3, 9, 8, 15);
    await container
        .read(lastFootCheckProvider.notifier)
        .record(
          FootCheckRecord(rating: FootCheckRating.veryGood, takenAt: takenAt),
        );
    await tester.pumpAndSettle();
    expect(find.text('No foot check yet'), findsNothing);
    expect(
      find.descendant(of: classic, matching: find.text('Very good')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mascot, matching: find.text('Very good')),
      findsOneWidget,
    );
    expect(find.text('Last check: Mar 9'), findsNWidgets(2));

    // The classic card's single CTA is a round play button that opens the
    // check session.
    final button = find.descendant(
      of: classic,
      matching: find.byType(IconButton),
    );
    expect(button, findsOneWidget);
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('session'), findsOneWidget);
  });
}
