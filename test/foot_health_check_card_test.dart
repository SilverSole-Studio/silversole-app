import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/widgets/foot_health_check_card.dart';

Future<void> _pumpCard(WidgetTester tester) async {
  // A real router, because the CTA navigates. The destination is a stand-in:
  // where '/foot-check' leads is the router's business, not the card's, and the
  // real session page would leave its minute-long timer running.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: FootHealthCheckCard()),
      ),
      GoRoute(
        path: '/foot-check',
        builder: (_, _) => const Scaffold(body: Text('session')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    EasyLocalization(
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
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders score and a round play CTA that starts a session', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pumpCard(tester);

    // Static placeholder score is shown.
    expect(find.text('81'), findsOneWidget);

    // The single CTA is a round play button, and it opens the check session.
    final button = find.byType(IconButton);
    expect(button, findsOneWidget);
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('session'), findsOneWidget);
  });
}
