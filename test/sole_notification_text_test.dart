import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/ble/sole_notification_text.dart';
import 'package:silversole/core/utils/battery_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One EasyLocalization mount per file: it keeps global state, so a second
  // mount never leaves its loading state.
  testWidgets('the notification reads like the home device card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
        path: 'assets/translations/strings.csv',
        assetLoader: CsvAssetLoader(),
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final now = DateTime(2026, 10, 11, 12);
    ({String title, String text}) at({
      required bool online,
      DateTime? lastSeen,
      int? live,
      int? lastKnown,
    }) => withClock(
      Clock.fixed(now),
      () => soleNotificationText(
        soleName: 'Left sole',
        online: online,
        lastSeen: lastSeen,
        battery: BatteryDisplay.resolve(live: live, lastKnown: lastKnown),
      ),
    );

    // Online with a live reading.
    expect(at(online: true, live: 85, lastKnown: 60), (
      title: 'Left sole',
      text: 'Online · Battery 85%',
    ));

    // Offline: when it was last seen, and the level it last reported.
    expect(
      at(
        online: false,
        lastSeen: now.subtract(const Duration(minutes: 5)),
        lastKnown: 62,
      ).text,
      'Last connected: 5 minutes ago · Battery 62%',
    );

    // Online but no valid reading yet keeps the remembered level.
    expect(
      at(online: true, live: BatteryPercentX.invalid, lastKnown: 62).text,
      'Online · Battery 62%',
    );

    // Never reported a level: no battery at all rather than a dash.
    expect(at(online: false).text, 'Offline');
  });
}
