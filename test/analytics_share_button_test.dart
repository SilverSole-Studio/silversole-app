import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart';

import 'helpers/translations.dart';

Future<void> _pump(WidgetTester tester, Widget analytics) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => analytics),
      GoRoute(
        path: '/activity-report',
        builder: (_, _) => const Scaffold(body: Text('REPORT PAGE')),
      ),
    ],
  );
  await EasyLocalization.ensureInitialized();
  await tester.runAsync(
    () => tester.pumpWidget(
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
    ),
  );
  await settleTranslations(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('classic analytics: Share sits in the app bar and opens the '
      'record page', (tester) async {
    await _pump(tester, const AnalyticsPage());

    final share = find.byTooltip('Share record');
    expect(share, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: share),
      findsOneWidget,
    );

    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(find.text('REPORT PAGE'), findsOneWidget);
  });

  testWidgets('mascot analytics: Share sits at the right end of the title row '
      'and opens the record page', (tester) async {
    await _pump(tester, const AnalyticsPageT2());

    final share = find.byTooltip('Share record');
    expect(share, findsOneWidget);
    final title = tester.getRect(find.text('How is your walking?'));
    final button = tester.getRect(share);
    expect(button.left, greaterThan(title.right));
    expect((button.center.dy - title.center.dy).abs(), lessThan(24));

    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(find.text('REPORT PAGE'), findsOneWidget);
  });
}
