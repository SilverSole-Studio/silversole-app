import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/shared/providers/daily_missions_bridge.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final today = DateTime(2026, 11, 13, 9);
  String titleOf(String id) => 'T:$id';

  test('the handler name is the one the town calls', () {
    expect(PlazaBridge.dailyMissions, 'dailyMissions');
  });

  group('dailyMissionsPayload', () {
    test('lists id, title and done, with the local day', () {
      final plan = MissionPlan(
        day: '2026-11-13',
        source: MissionPlanSource.rule,
        items: const [
          MissionPlanItem(MissionCatalog.footCheck),
          MissionPlanItem('bike'),
          MissionPlanItem('quiz', reason: 'secret wording'),
        ],
      );
      final activity = const GameActivityLog().add(
        GameActivity(slug: 'bike', seconds: 30, at: today),
        today: today,
      );
      final out = dailyMissionsPayload(
        plan: plan,
        today: today,
        activity: activity,
        lastFootCheck: null,
        titleOf: titleOf,
      );
      expect(out, {
        'day': '2026-11-13',
        'missions': [
          {'id': 'foot_check', 'title': 'T:foot_check', 'done': false},
          {'id': 'bike', 'title': 'T:bike', 'done': true},
          {'id': 'quiz', 'title': 'T:quiz', 'done': false},
        ],
      });
    });

    test('no plan gives an empty list for today', () {
      expect(
        dailyMissionsPayload(
          plan: null,
          today: today,
          activity: const GameActivityLog(),
          lastFootCheck: null,
          titleOf: titleOf,
        ),
        {'day': '2026-11-13', 'missions': <Object>[]},
      );
    });
  });

  testWidgets('dailyMissionsAnswer makes today\'s plan like the sheet does', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );
    await withClock(Clock.fixed(today), () async {
      final answer = (await tester.runAsync(() => dailyMissionsAnswer(ref)))!;
      expect(answer['day'], '2026-11-13');
      final missions = answer['missions']! as List;
      expect(missions, hasLength(3));
      for (final m in missions.cast<Map>()) {
        expect(m.keys.toSet(), {'id', 'title', 'done'});
        expect(MissionCatalog.isKnown(m['id'] as String), isTrue);
        expect(m['done'], isFalse);
      }
      expect((missions.first as Map)['id'], MissionCatalog.footCheck);

      // The saved plan is what the sheet would show: same ids on a second ask.
      final again = (await tester.runAsync(() => dailyMissionsAnswer(ref)))!;
      expect(
        [for (final m in (again['missions']! as List).cast<Map>()) m['id']],
        [for (final m in missions.cast<Map>()) m['id']],
      );
      expect(ref.read(gameActivityProvider).playedOn('bike', today), isFalse);
    });
  });
}
