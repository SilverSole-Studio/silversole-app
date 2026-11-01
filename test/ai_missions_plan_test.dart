import 'dart:async';

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

  final yes = {LocalSavableKey.aiMissionsConsent.value: 'yes'};

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
    // The sheet watches the plan for as long as it is open.
    c.listen(todayMissionPlanProvider, (_, _) {});
    return c;
  }

  /// The plan the sheet gets to draw first.
  Future<MissionPlan> plan(ProviderContainer c) =>
      c.read(todayMissionPlanProvider.future);

  /// What the sheet shows once the background ask has finished.
  Future<MissionPlan> settled(ProviderContainer c) async {
    await plan(c);
    await pumpEventQueue();
    return c.read(todayMissionPlanProvider).requireValue;
  }

  Future<void> sayConsent(ProviderContainer c, AiMissionsConsent v) =>
      c.read(aiMissionsConsentProvider.notifier).set(v);

  Future<MissionPlan?> storedPlan() async => MissionPlan.tryDecode(
    await loadLocalValue(LocalSavableKey.dailyMissionPlan),
  );

  Future<String?> failedDay() =>
      loadLocalValue(LocalSavableKey.aiMissionsFailedDay);

  final todayKey = gaitDateKey(clock.now());

  test(
    'flag off: rules only, the client is never asked, whatever was saved',
    () async {
      // Even a stored "yes" from an earlier build does nothing.
      SharedPreferences.setMockInitialValues(yes);
      final client = FakeAiMissionClient(answer: aiPlanFixture());
      final c = container(enabled: false, client: client);

      final p = await settled(c);
      expect(p.source, MissionPlanSource.rule);
      expect(p.items, hasLength(3));
      expect(client.calls, isEmpty);
      expect(c.exists(aiMissionsConsentProvider), isFalse);
    },
  );

  test(
    'flag off: an AI plan left by an earlier build is made again by rules',
    () async {
      final saved = MissionPlan(
        day: todayKey,
        source: MissionPlanSource.ai,
        greeting: 'old',
        items: aiPlanFixture().items,
      );
      SharedPreferences.setMockInitialValues({
        LocalSavableKey.dailyMissionPlan.value: saved.encode(),
      });
      final client = FakeAiMissionClient(answer: aiPlanFixture());
      final p = await settled(container(enabled: false, client: client));
      expect(p.source, MissionPlanSource.rule);
      expect(p.greeting, isNull);
      expect(client.calls, isEmpty);
    },
  );

  test('flag on, no answer yet: rules only, nothing sent', () async {
    final client = FakeAiMissionClient(answer: aiPlanFixture());
    final c = container(enabled: true, client: client);
    expect((await settled(c)).source, MissionPlanSource.rule);
    expect(client.calls, isEmpty);
  });

  test('consent no: rules only, nothing sent', () async {
    SharedPreferences.setMockInitialValues({
      LocalSavableKey.aiMissionsConsent.value: 'no',
    });
    final client = FakeAiMissionClient(answer: aiPlanFixture());
    final c = container(enabled: true, client: client);
    expect((await settled(c)).source, MissionPlanSource.rule);
    expect(client.calls, isEmpty);
  });

  test('consent yes: the rules plan comes first, the AI plan replaces it '
      'and is not asked for twice', () async {
    SharedPreferences.setMockInitialValues(yes);
    final gate = Completer<void>();
    final client = FakeAiMissionClient(answer: aiPlanFixture(), gate: gate);
    final first = container(enabled: true, client: client);

    // What the sheet draws first is the rules' plan, saved at once.
    final rules = await plan(first);
    expect(rules.source, MissionPlanSource.rule);
    expect(rules.items, hasLength(3));
    expect(await storedPlan(), rules);

    gate.complete();
    await pumpEventQueue();
    final p = first.read(todayMissionPlanProvider).requireValue;
    expect(p.source, MissionPlanSource.ai);
    expect(p.greeting, 'Good morning! A gentle day today.');
    expect(p.items.map((i) => i.id), ['fish', 'foot_check', 'laojie']);
    expect(p.items.first.reason, 'Easy and fun to start with');
    expect(client.calls, hasLength(1));
    expect(await storedPlan(), p);
    expect(await failedDay(), isNull);

    // The sheet closed and opened again: the saved plan, no new call.
    final second = container(enabled: true, client: client);
    expect(await plan(second), p);
    await pumpEventQueue();
    expect(client.calls, hasLength(1));
  });

  test('a slow server never holds the sheet back', () async {
    SharedPreferences.setMockInitialValues(yes);
    final gate = Completer<void>();
    final client = FakeAiMissionClient(answer: aiPlanFixture(), gate: gate);
    final c = container(enabled: true, client: client);

    final p = await plan(c);
    expect(p.source, MissionPlanSource.rule);
    expect(c.read(todayMissionPlanProvider).isLoading, isFalse);
    expect(client.calls, hasLength(1));

    gate.complete();
    await pumpEventQueue();
    expect(
      c.read(todayMissionPlanProvider).requireValue.source,
      MissionPlanSource.ai,
    );
  });

  test('the server answers without a plan: rules, marked, not asked again '
      'today', () async {
    SharedPreferences.setMockInitialValues(yes);
    final client = FakeAiMissionClient(); // refuses
    final first = container(enabled: true, client: client);
    final p = await settled(first);
    expect(p.source, MissionPlanSource.rule);
    expect(client.calls, hasLength(1));
    expect(await failedDay(), todayKey);

    // Even if the server could answer now, today is not retried.
    client.answer = aiPlanFixture();
    final second = container(enabled: true, client: client);
    expect(await settled(second), p);
    expect(client.calls, hasLength(1));
  });

  test(
    'offline or too slow: rules, not marked, asked again next time',
    () async {
      SharedPreferences.setMockInitialValues(yes);
      final client = FakeAiMissionClient(unreachable: true);
      final first = container(enabled: true, client: client);
      final p = await settled(first);
      expect(p.source, MissionPlanSource.rule);
      expect(client.calls, hasLength(1));
      expect(await failedDay(), isNull);

      // Back online the next time the sheet opens.
      client.unreachable = false;
      client.answer = aiPlanFixture();
      final second = container(enabled: true, client: client);
      expect((await settled(second)).source, MissionPlanSource.ai);
      expect(client.calls, hasLength(2));
    },
  );

  test('a client that throws counts as unreachable', () async {
    SharedPreferences.setMockInitialValues(yes);
    final client = FakeAiMissionClient(fail: true);
    final p = await settled(container(enabled: true, client: client));
    expect(p.source, MissionPlanSource.rule);
    expect(p.items, hasLength(3));
    expect(await failedDay(), isNull);
  });

  test(
    'saying yes after the rules plan was made asks for an AI plan',
    () async {
      final client = FakeAiMissionClient(answer: aiPlanFixture());
      final c = container(enabled: true, client: client);
      final rules = await settled(c);
      expect(rules.source, MissionPlanSource.rule);

      await sayConsent(c, AiMissionsConsent.yes);
      expect((await plan(c)), rules, reason: 'the same rules plan is kept');
      await pumpEventQueue();
      expect(
        c.read(todayMissionPlanProvider).requireValue.source,
        MissionPlanSource.ai,
      );
      expect(client.calls, hasLength(1));
    },
  );

  test(
    'a refused ask after saying yes keeps the rules plan already shown',
    () async {
      final client = FakeAiMissionClient();
      final c = container(enabled: true, client: client);
      final rules = await settled(c);

      await sayConsent(c, AiMissionsConsent.yes);
      expect(await settled(c), rules);
      expect(client.calls, hasLength(1));
      expect(await failedDay(), todayKey);
    },
  );

  test('switching off puts the rules back, switching on again asks the server '
      'once more', () async {
    SharedPreferences.setMockInitialValues(yes);
    final client = FakeAiMissionClient(answer: aiPlanFixture());
    final c = container(enabled: true, client: client);
    expect((await settled(c)).source, MissionPlanSource.ai);

    await sayConsent(c, AiMissionsConsent.no);
    final off = await settled(c);
    expect(off.source, MissionPlanSource.rule);
    expect(off.greeting, isNull);
    expect(client.calls, hasLength(1));

    // A success earlier in the day left no mark, so asking again is allowed
    // (the server hands back the plan it already wrote).
    await sayConsent(c, AiMissionsConsent.yes);
    expect((await settled(c)).source, MissionPlanSource.ai);
    expect(client.calls, hasLength(2));
  });

  test('a slow answer that lands after switching AI off is dropped: nothing '
      'AI is saved and nothing is marked', () async {
    SharedPreferences.setMockInitialValues(yes);
    final gate = Completer<void>();
    final client = FakeAiMissionClient(answer: aiPlanFixture(), gate: gate);
    final c = container(enabled: true, client: client);
    await plan(c);
    expect(client.calls, hasLength(1));

    await sayConsent(c, AiMissionsConsent.no);
    final off = await plan(c);
    expect(off.source, MissionPlanSource.rule);

    gate.complete();
    await pumpEventQueue();
    expect(
      c.read(todayMissionPlanProvider).requireValue.source,
      MissionPlanSource.rule,
    );
    expect((await storedPlan())!.source, MissionPlanSource.rule);
    expect(await failedDay(), isNull);
  });

  test(
    'a slow refusal that lands after switching AI off marks nothing',
    () async {
      SharedPreferences.setMockInitialValues(yes);
      final gate = Completer<void>();
      final client = FakeAiMissionClient(gate: gate); // refuses
      final c = container(enabled: true, client: client);
      await plan(c);

      await sayConsent(c, AiMissionsConsent.no);
      await plan(c);
      gate.complete();
      await pumpEventQueue();
      expect(await failedDay(), isNull);
      expect((await storedPlan())!.source, MissionPlanSource.rule);
    },
  );

  test('a slow answer for a sheet that was closed is dropped', () async {
    SharedPreferences.setMockInitialValues(yes);
    final gate = Completer<void>();
    final client = FakeAiMissionClient(answer: aiPlanFixture(), gate: gate);
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        aiMissionsEnabledProvider.overrideWithValue(true),
        aiMissionClientProvider.overrideWithValue(client),
        realGaitEnabledProvider.overrideWithValue(false),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(todayMissionPlanProvider, (_, _) {});
    await plan(c);
    sub.close(); // the sheet goes away
    await pumpEventQueue();

    gate.complete();
    await pumpEventQueue();
    expect((await storedPlan())!.source, MissionPlanSource.rule);
    expect(await failedDay(), isNull);
  });

  test('the gait numbers go along only while step tracking is on', () async {
    SharedPreferences.setMockInitialValues(yes);
    final off = FakeAiMissionClient(answer: aiPlanFixture());
    await settled(container(enabled: true, client: off, gait: false));
    expect(off.calls.single['gaitHistory'], isNull);

    SharedPreferences.setMockInitialValues(yes);
    final on = FakeAiMissionClient(answer: aiPlanFixture());
    await settled(container(enabled: true, client: on, gait: true));
    expect(on.calls.single['gaitHistory'], isNotNull);
  });
}
