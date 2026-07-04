import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';

Future<void> _pumpSheet(WidgetTester tester) async {
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
          home: const Scaffold(body: DailyMissionsSheet()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('incomplete missions show a gray Go button, not a reward amount',
      (tester) async {
    await EasyLocalization.ensureInitialized();
    await _pumpSheet(tester);

    // Two incomplete missions → two "Go" buttons; one completed → "Claimed".
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(2));
    expect(find.text('Claimed'), findsOneWidget);

    // The reward amounts from the mock-up are intentionally NOT rendered.
    expect(find.text('+50'), findsNothing);
    expect(find.text('+30'), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
