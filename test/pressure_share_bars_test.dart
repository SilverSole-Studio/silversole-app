import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/pressure_shares.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/pressure_share_bars.dart';

import 'helpers/translations.dart';

Future<void> _pump(
  WidgetTester tester, {
  FootView feet = FootView.right,
  PressureShares? right,
  PressureShares? left,
  bool rightConnected = true,
  bool leftConnected = false,
}) async {
  await tester.runAsync(
    () => tester.pumpWidget(
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
              body: PressureShareBars(
                feet: feet,
                right: right,
                left: left,
                rightConnected: rightConnected,
                leftConnected: leftConnected,
              ),
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

  testWidgets('a loaded foot shows both split bars', (tester) async {
    await EasyLocalization.ensureInitialized();
    await _pump(
      tester,
      right: const PressureShares(foreRatio: 0.38, medialRatio: 0.6),
    );
    expect(find.text('Forefoot 38%'), findsOneWidget);
    expect(find.text('62% Heel'), findsOneWidget);
    expect(find.text('Medial 60%'), findsOneWidget);
    expect(find.text('40% Lateral'), findsOneWidget);
    // One foot on its own: the tab above already says which.
    expect(find.text('Right foot'), findsNothing);
  });

  testWidgets('no inner-outer split without forefoot load', (tester) async {
    await EasyLocalization.ensureInitialized();
    await _pump(
      tester,
      right: const PressureShares(foreRatio: 0.01, medialRatio: null),
    );
    expect(find.text('Forefoot 1%'), findsOneWidget);
    expect(
      find.text('Inner and outer split shows once the forefoot is loaded'),
      findsOneWidget,
    );
    expect(find.textContaining('Medial'), findsNothing);
  });

  testWidgets('connected but not standing shows a hint and no numbers', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await _pump(tester);
    expect(find.text('Stand on the insole to see the split'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('not connected shows a hint and no numbers', (tester) async {
    await EasyLocalization.ensureInitialized();
    await _pump(tester, rightConnected: false);
    expect(find.text('No insole connected'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('both feet are titled left and right', (tester) async {
    await EasyLocalization.ensureInitialized();
    await _pump(
      tester,
      feet: FootView.both,
      right: const PressureShares(foreRatio: 0.4, medialRatio: 0.5),
      leftConnected: true,
    );
    expect(find.text('Left foot'), findsOneWidget);
    expect(find.text('Right foot'), findsOneWidget);
    // Left is connected but has nothing yet; right has bars.
    expect(find.text('Stand on the insole to see the split'), findsOneWidget);
    expect(find.text('Forefoot 40%'), findsOneWidget);
  });
}
