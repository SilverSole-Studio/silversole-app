import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/widgets/foot_health_check_card.dart';

Future<void> _pumpCard(WidgetTester tester) async {
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
          home: const Scaffold(body: FootHealthCheckCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders score and a tappable round play CTA', (tester) async {
    await EasyLocalization.ensureInitialized();
    await _pumpCard(tester);

    // Static placeholder score is shown.
    expect(find.text('81'), findsOneWidget);

    // The single CTA is a round play button; tapping it builds without error.
    final button = find.byType(IconButton);
    expect(button, findsOneWidget);
    expect(find.byIcon(LucideIcons.play), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
