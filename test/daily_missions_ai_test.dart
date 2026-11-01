import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/ai_missions_provider.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';

import 'helpers/fake_ai_mission_client.dart';
import 'helpers/translations.dart';

final _switch = find.byKey(const Key('ai_missions_switch'));
final _yes = find.byKey(const Key('ai_consent_yes'));
final _no = find.byKey(const Key('ai_consent_no'));
final _consentTitle = find.text('Let AI plan your missions?');
final _badge = find.text('AI picks');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One EasyLocalization mount for the whole file (a second mount in the same
  // file never leaves its loading state); each case swaps in its own
  // container and a freshly keyed sheet beneath it.
  testWidgets('AI missions: off by default, asked once, shown only when '
      'written', (tester) async {
    await EasyLocalization.ensureInitialized();
    var mounts = 0;

    Future<ProviderContainer> mount({
      required bool enabled,
      required FakeAiMissionClient client,
      Map<String, Object> stored = const {},
    }) async {
      SharedPreferences.setMockInitialValues(stored);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          aiMissionsEnabledProvider.overrideWithValue(enabled),
          aiMissionClientProvider.overrideWithValue(client),
          realGaitEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      mounts++;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          key: ValueKey(mounts),
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
      return container;
    }

    Future<String?> stored(LocalSavableKey key) => loadLocalValue(key);

    // 1. Flag off: nothing about AI, the client is never asked.
    final off = FakeAiMissionClient(answer: aiPlanFixture());
    var c = await mount(
      enabled: false,
      client: off,
      stored: {LocalSavableKey.aiMissionsConsent.value: 'yes'},
    );
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(3));
    expect(_consentTitle, findsNothing);
    expect(_switch, findsNothing);
    expect(_badge, findsNothing);
    expect(find.textContaining('AI'), findsNothing);
    expect(off.calls, isEmpty);
    expect(
      c.read(todayMissionPlanProvider).requireValue.source,
      MissionPlanSource.rule,
    );

    // 2. Flag on, never answered: the question comes first, and says what is
    //    sent and where. "Not now" leaves the rules' plan, no label, nothing
    //    sent, and the switch off.
    final client = FakeAiMissionClient(answer: aiPlanFixture());
    c = await mount(enabled: true, client: client);
    expect(_consentTitle, findsOneWidget);
    for (final part in [
      'yesterday and for how many seconds',
      'last 7 days',
      'foot check was and its result',
      'Only when gait tracking is on',
      'steps and cadence and walking minutes and mobility grade',
      'Dongyu Tech server',
      'Claude from Anthropic',
      'Your name and account are not handed to Claude',
      'keeps only the text the AI wrote for that day',
      'not these raw numbers',
    ]) {
      expect(find.textContaining(part), findsOneWidget, reason: part);
    }
    expect(_yes, findsOneWidget);
    expect(_no, findsOneWidget);
    expect(client.calls, isEmpty);

    await tester.tap(_no);
    await tester.pumpAndSettle();
    expect(_consentTitle, findsNothing);
    expect(client.calls, isEmpty);
    expect(await stored(LocalSavableKey.aiMissionsConsent), 'no');
    expect(_badge, findsNothing);
    expect(find.textContaining('Good morning'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(3));
    expect(tester.widget<SwitchListTile>(_switch).value, isFalse);

    // 3. Turning the switch on shows the question again; agreeing asks the
    //    server and the sheet shows its wording with the label.
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(_consentTitle, findsOneWidget);
    await tester.tap(_yes);
    await tester.pumpAndSettle();
    expect(client.calls, hasLength(1));
    expect(await stored(LocalSavableKey.aiMissionsConsent), 'yes');
    expect(_badge, findsOneWidget);
    // The label is an icon and words, not one of them alone.
    final badgeRow = find
        .ancestor(of: _badge, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(
        of: badgeRow,
        matching: find.byIcon(LucideIcons.sparkles),
      ),
      findsOneWidget,
    );
    expect(find.text('Good morning! A gentle day today.'), findsOneWidget);
    expect(find.text('Easy and fun to start with'), findsOneWidget);
    expect(find.text('It has been a few days'), findsOneWidget);
    expect(find.text('A stroll through the old street'), findsOneWidget);
    expect(find.text('Play a round of Chu Fish Catch'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_switch).value, isTrue);

    // 4. Switching off puts the rules' plan back, without the label.
    await tester.tap(_switch);
    await tester.pumpAndSettle();
    expect(_badge, findsNothing);
    expect(find.textContaining('Good morning'), findsNothing);
    expect(find.text('Easy and fun to start with'), findsNothing);
    expect(await stored(LocalSavableKey.aiMissionsConsent), 'no');
    expect(tester.widget<SwitchListTile>(_switch).value, isFalse);

    // 5. Already agreed: no question, the written plan shows at once, and the
    //    switch is on.
    final again = FakeAiMissionClient(answer: aiPlanFixture());
    c = await mount(
      enabled: true,
      client: again,
      stored: {LocalSavableKey.aiMissionsConsent.value: 'yes'},
    );
    expect(_consentTitle, findsNothing);
    expect(again.calls, hasLength(1));
    expect(_badge, findsOneWidget);
    expect(find.text('Good morning! A gentle day today.'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_switch).value, isTrue);
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(3));
    expect(find.text('Easy and fun to start with'), findsOneWidget);

    // A finished row says "Done" instead of the AI's reason.
    await c
        .read(gameActivityProvider.notifier)
        .record(GameActivity(slug: 'fish', seconds: 30, at: DateTime.now()));
    await tester.pumpAndSettle();
    expect(find.text('Easy and fun to start with'), findsNothing);
    expect(find.text('It has been a few days'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(2));

    // 6. Agreed but the server has nothing: the rules' plan, no label.
    final empty = FakeAiMissionClient();
    c = await mount(
      enabled: true,
      client: empty,
      stored: {LocalSavableKey.aiMissionsConsent.value: 'yes'},
    );
    expect(empty.calls, hasLength(1));
    expect(_badge, findsNothing);
    expect(find.textContaining('Good morning'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Go'), findsNWidgets(3));
    expect(
      c.read(todayMissionPlanProvider).requireValue.source,
      MissionPlanSource.rule,
    );
    expect(tester.widget<SwitchListTile>(_switch).value, isTrue);

    expect(tester.takeException(), isNull);
  });
}
