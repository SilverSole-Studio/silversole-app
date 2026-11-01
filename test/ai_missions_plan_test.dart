import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/shared/providers/ai_missions_provider.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';

import 'helpers/fake_ai_mission_client.dart';

/// What today's plan provider does with the AI switch, the consent and the
/// server, without any screen.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container({
    required bool enabled,
    required FakeAiMissionClient client,
    bool gait = false,
  }) {
    final c = ProviderContainer(
      // No automatic retry: it would leave a timer running past the test.
      retry: (_, _) => null,
      overrides: [
        aiMissionsEnabledProvider.overrideWithValue(enabled),
        aiMissionClientProvider.overrideWithValue(client),
        realGaitEnabledProvider.overrideWithValue(gait),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<MissionPlan> plan(ProviderContainer c) async {
    final p = await c.read(todayMissionPlanProvider.future);
    return p;
  }

  Future<void> sayConsent(ProviderContainer c, AiMissionsConsent v) =>
      c.read(aiMissionsConsentProvider.notifier).set(v);

  test(
    'flag off: rules only, the client is never asked, whatever was saved',
    () async {
      // Even a stored "yes" from an earlier build does nothing.
      SharedPreferences.setMockInitialValues({
        LocalSavableKey.aiMissionsConsent.value: 'yes',
      });
      final client = FakeAiMissionClient(answer: aiPlanFixture());
      final c = container(enabled: false, client: client);

      final p = await plan(c);
      expect(p.source, MissionPlanSource.rule);
      expect(p.items, hasLength(3));
      expect(client.calls, isEmpty);
      expect(c.exists(aiMissionsConsentProvider), isFalse);
    },
  );

  test(
    'flag off: an AI plan left by an earlier build is made again by rules',
    () async {
      final today = gaitDateKey(clock.now());
      final saved = MissionPlan(
        day: today,
        source: MissionPlanSource.ai,
        greeting: 'old',
        items: aiPlanFixture().items,
      );
      SharedPreferences.setMockInitialValues({
        LocalSavableKey.dailyMissionPlan.value: saved.encode(),
      });
      final client = FakeAiMissionClient(answer: aiPlanFixture());
      final p = await plan(container(enabled: false, client: client));
      expect(p.source, MissionPlanSource.rule);
      expect(p.greeting, isNull);
      expect(client.calls, isEmpty);
    },
  );

  test('flag on, no answer yet: rules only, nothing sent', () async {
    final client = FakeAiMissionClient(answer: aiPlanFixture());
    final c = container(enabled: true, client: client);
    expect((await plan(c)).source, MissionPlanSource.rule);
    expect(client.calls, isEmpty);
  });

  test('consent no: rules only, nothing sent', () async {
    SharedPreferences.setMockInitialValues({
      LocalSavableKey.aiMissionsConsent.value: 'no',
    });
    final client = FakeAiMissionClient(answer: aiPlanFixture());
    final c = container(enabled: true, client: client);
    expect((await plan(c)).source, MissionPlanSource.rule);
    expect(client.calls, isEmpty);
  });

  test(
    'consent yes: the server plan is used, saved and not asked twice',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalSavableKey.aiMissionsConsent.value: 'yes',
      });
      final client = FakeAiMissionClient(answer: aiPlanFixture());
      final first = container(enabled: true, client: client);

      final p = await plan(first);
      expect(p.source, MissionPlanSource.ai);
      expect(p.greeting, 'Good morning! A gentle day today.');
      expect(p.items.map((i) => i.id), ['fish', 'foot_check', 'laojie']);
      expect(p.items.first.reason, 'Easy and fun to start with');
      expect(client.calls, hasLength(1));
      expect(
        MissionPlan.tryDecode(
          await loadLocalValue(LocalSavableKey.dailyMissionPlan),
        ),
        p,
      );

      // The sheet closed and opened again: the saved plan, no new call.
      final second = container(enabled: true, client: client);
      expect(await plan(second), p);
      expect(client.calls, hasLength(1));
    },
  );

  test(
    'consent yes but the server has nothing: rules, and not asked again today',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalSavableKey.aiMissionsConsent.value: 'yes',
      });
      final client = FakeAiMissionClient(); // answer null
      final first = container(enabled: true, client: client);
      final p = await plan(first);
      expect(p.source, MissionPlanSource.rule);
      expect(client.calls, hasLength(1));
      expect(
        await loadLocalValue(LocalSavableKey.aiMissionsFailedDay),
        gaitDateKey(clock.now()),
      );

      // Even if the server could answer now, today is not retried.
      client.answer = aiPlanFixture();
      final second = container(enabled: true, client: client);
      expect(await plan(second), p);
      expect(client.calls, hasLength(1));
    },
  );

  test('a client that throws is the same as one that has nothing', () async {
    SharedPreferences.setMockInitialValues({
      LocalSavableKey.aiMissionsConsent.value: 'yes',
    });
    final client = FakeAiMissionClient(fail: true);
    final p = await plan(container(enabled: true, client: client));
    expect(p.source, MissionPlanSource.rule);
    expect(p.items, hasLength(3));
  });

  test(
    'saying yes after the rules plan was made asks for an AI plan',
    () async {
      final client = FakeAiMissionClient(answer: aiPlanFixture());
      final c = container(enabled: true, client: client);
      final rules = await plan(c);
      expect(rules.source, MissionPlanSource.rule);
      // The sheet keeps watching the plan.
      c.listen(todayMissionPlanProvider, (_, _) {});

      await sayConsent(c, AiMissionsConsent.yes);
      final p = await plan(c);
      expect(p.source, MissionPlanSource.ai);
      expect(client.calls, hasLength(1));
    },
  );

  test(
    'a failed ask after saying yes keeps the rules plan already shown',
    () async {
      final client = FakeAiMissionClient();
      final c = container(enabled: true, client: client);
      final rules = await plan(c);
      c.listen(todayMissionPlanProvider, (_, _) {});

      await sayConsent(c, AiMissionsConsent.yes);
      expect(await plan(c), rules);
      expect(client.calls, hasLength(1));
    },
  );

  test('switching off puts the rules back, switching on again asks the server '
      'once more', () async {
    SharedPreferences.setMockInitialValues({
      LocalSavableKey.aiMissionsConsent.value: 'yes',
    });
    final client = FakeAiMissionClient(answer: aiPlanFixture());
    final c = container(enabled: true, client: client);
    expect((await plan(c)).source, MissionPlanSource.ai);
    c.listen(todayMissionPlanProvider, (_, _) {});

    await sayConsent(c, AiMissionsConsent.no);
    final off = await plan(c);
    expect(off.source, MissionPlanSource.rule);
    expect(off.greeting, isNull);
    expect(client.calls, hasLength(1));

    // A success earlier in the day left no failure mark, so asking again is
    // allowed (the server hands back the plan it already wrote).
    await sayConsent(c, AiMissionsConsent.yes);
    expect((await plan(c)).source, MissionPlanSource.ai);
    expect(client.calls, hasLength(2));
  });

  test('the gait numbers go along only while step tracking is on', () async {
    SharedPreferences.setMockInitialValues({
      LocalSavableKey.aiMissionsConsent.value: 'yes',
    });
    final off = FakeAiMissionClient(answer: aiPlanFixture());
    await plan(container(enabled: true, client: off, gait: false));
    expect(off.calls.single['gaitHistory'], isNull);

    SharedPreferences.setMockInitialValues({
      LocalSavableKey.aiMissionsConsent.value: 'yes',
    });
    final on = FakeAiMissionClient(answer: aiPlanFixture());
    await plan(container(enabled: true, client: on, gait: true));
    expect(on.calls.single['gaitHistory'], isNotNull);
  });
}
