import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/ble/sole_notification_text.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'helpers/translations.dart';

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
    await settleTranslations(tester);

    final now = DateTime(2026, 10, 11, 12);
    ({String title, String text}) at({
      required bool online,
      DateTime? lastSeen,
      int? live,
      int? lastKnown,
    }) => withClock(
      Clock.fixed(now),
      () => soleNotificationText([
        SoleNotice(
          name: 'Left sole',
          label: 'Left foot',
          online: online,
          lastSeen: lastSeen,
          battery: BatteryDisplay.resolve(live: live, lastKnown: lastKnown),
        ),
      ]),
    );

    SoleNotice notice({
      required String label,
      required bool online,
      DateTime? lastSeen,
      int? live,
      int? lastKnown,
    }) => SoleNotice(
      name: 'SilverSole',
      label: label,
      online: online,
      lastSeen: lastSeen,
      battery: BatteryDisplay.resolve(live: live, lastKnown: lastKnown),
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

    // Two soles: one line, one part per foot.
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          notice(label: 'Left foot', online: true, live: 85),
          notice(label: 'Right foot', online: true, live: 92),
        ]),
      ),
      (title: 'SilverSole', text: 'Left foot 85% · Right foot 92%'),
    );

    // One foot offline must read as offline — not as "the wearable is online".
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          notice(label: 'Left foot', online: true, live: 85),
          notice(label: 'Right foot', online: false, lastKnown: 40),
        ]),
      ).text,
      'Left foot 85% · Right foot Offline',
    );

    // The controller passes a non-null lastSeen in practice, so this is the
    // offline case that matters: the foot must still read plainly Offline,
    // not a relative-time phrase.
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          notice(label: 'Left foot', online: true, live: 85),
          notice(
            label: 'Right foot',
            online: false,
            lastSeen: now.subtract(const Duration(minutes: 5)),
            lastKnown: 40,
          ),
        ]),
      ).text,
      'Left foot 85% · Right foot Offline',
    );

    // A sole that never reported a level says its status instead of a dash.
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          notice(label: 'Left foot', online: true),
          notice(label: 'Right foot', online: true, live: 92),
        ]),
      ).text,
      'Left foot Online · Right foot 92%',
    );

    // Different names keep both, since the title is all the wearer sees.
    expect(
      withClock(
        Clock.fixed(now),
        () => soleNotificationText([
          SoleNotice(
            name: 'Left sole',
            label: 'Left foot',
            online: true,
            lastSeen: now,
            battery: BatteryDisplay.resolve(live: 85),
          ),
          SoleNotice(
            name: 'Right sole',
            label: 'Right foot',
            online: true,
            lastSeen: now,
            battery: BatteryDisplay.resolve(live: 92),
          ),
        ]),
      ).title,
      'Left sole / Right sole',
    );

    // No soles at all: nothing to say.
    expect(soleNotificationText(const []), (title: 'Silver Sole', text: ''));
  });
}
