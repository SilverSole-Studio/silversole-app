import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';

void main() {
  final today = DateTime(2026, 11, 1, 10);

  group('MissionCatalog', () {
    test('has the foot check and ten games, never the hidden stages', () {
      expect(MissionCatalog.ids, hasLength(11));
      expect(MissionCatalog.ids.first, 'foot_check');
      expect(MissionCatalog.ids, isNot(contains('racer')));
      expect(MissionCatalog.ids, isNot(contains('golf')));
      expect(MissionCatalog.isKnown('golf'), isFalse);
      expect(MissionCatalog.isGame('foot_check'), isFalse);
    });

    test('games open under game/<id>/, the foot check is not a web game', () {
      expect(MissionCatalog.gamePath('fish', today), 'game/fish/');
      expect(MissionCatalog.gamePath('foot_check', today), isNull);
      expect(MissionCatalog.gamePath('racer', today), isNull);
    });

    test('laojie rotates through five stages by day of the year', () {
      expect(dayOfYear(DateTime(2026, 1, 1)), 1);
      expect(dayOfYear(DateTime(2026, 11, 1)), 305);
      expect(dayOfYear(DateTime(2028, 12, 31)), 366);
      // 305 % 5 == 0
      expect(
        MissionCatalog.gamePath('laojie', today),
        'game/laojie/lantern/?theme=xinbei&from=world',
      );
      expect(
        MissionCatalog.gamePath('laojie', DateTime(2026, 11, 2)),
        'game/laojie/goldfish/?theme=taipei&from=world',
      );
      final seen = {
        for (var d = 0; d < 5; d++)
          MissionCatalog.gamePath('laojie', DateTime(2026, 11, 1 + d)),
      };
      expect(seen, hasLength(5));
      expect(
        MissionCatalog.gamePath('laojie', DateTime(2026, 11, 6)),
        MissionCatalog.gamePath('laojie', today),
      );
    });

    test('a game is done only by a round of that game today', () {
      final log = const GameActivityLog().addAll([
        GameActivity(slug: 'fish', seconds: 5, at: today),
        GameActivity(
          slug: 'bike',
          seconds: 5,
          at: today.subtract(const Duration(days: 1)),
        ),
      ]);
      bool done(String id) => MissionCatalog.isCompleted(
        id,
        today: today,
        activity: log,
        lastFootCheck: null,
      );
      expect(done('fish'), isTrue);
      expect(done('bike'), isFalse, reason: 'yesterday');
      expect(done('quiz'), isFalse);
      expect(done('foot_check'), isFalse);
    });

    test('the foot check is done only by a check finished today', () {
      bool done(DateTime takenAt) => MissionCatalog.isCompleted(
        'foot_check',
        today: today,
        activity: const GameActivityLog(),
        lastFootCheck: FootCheckRecord(
          rating: FootCheckRating.good,
          takenAt: takenAt,
        ),
      );
      expect(done(DateTime(2026, 11, 1, 0, 1)), isTrue);
      expect(done(DateTime(2026, 10, 31, 23, 59)), isFalse);
    });
  });

  group('MissionPlan', () {
    test('survives a JSON round trip', () {
      const plan = MissionPlan(
        day: '2026-11-01',
        source: MissionPlanSource.ai,
        greeting: 'hi',
        items: [
          MissionPlanItem('fish', reason: 'because'),
          MissionPlanItem('quiz'),
        ],
      );
      expect(MissionPlan.tryDecode(plan.encode()), plan);
    });

    test('unreadable or empty plans decode to null, unknown ids are dropped', () {
      expect(MissionPlan.tryDecode(null), isNull);
      expect(MissionPlan.tryDecode('nope'), isNull);
      expect(MissionPlan.tryDecode('{"day":"2026-11-01"}'), isNull);
      expect(
        MissionPlan.tryDecode(
          '{"day":"d","source":"rule","items":[{"id":"golf"}]}',
        ),
        isNull,
      );
      final kept = MissionPlan.tryDecode(
        '{"day":"d","source":"rule","items":[{"id":"golf"},{"id":"fish"},{"id":"fish"}]}',
      );
      expect([for (final i in kept!.items) i.id], ['fish']);
    });
  });

  group('todayMissionPlanProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<MissionPlan> read() async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c.read(todayMissionPlanProvider.future);
    }

    test(
      'the first open of the day makes a plan from the stored record and saves it',
      () async {
        final plan = await withClock(Clock.fixed(today), read);
        expect(plan.items, hasLength(3));
        expect(plan.items.first.id, 'foot_check');
        expect(plan.day, '2026-11-01');
        expect(
          MissionPlan.tryDecode(
            await loadLocalValue(LocalSavableKey.dailyMissionPlan),
          ),
          plan,
        );
      },
    );

    test(
      'playing a game later the same day does not change the list',
      () async {
        final first = await withClock(Clock.fixed(today), read);
        final c = ProviderContainer();
        addTearDown(c.dispose);
        for (final item in first.items) {
          if (MissionCatalog.isGame(item.id)) {
            await withClock(
              Clock.fixed(today),
              () => c
                  .read(gameActivityProvider.notifier)
                  .record(GameActivity(slug: item.id, seconds: 30, at: today)),
            );
          }
        }
        final again = await withClock(Clock.fixed(today), read);
        expect(again, first);
      },
    );

    test('a new day plans again', () async {
      final first = await withClock(Clock.fixed(today), read);
      final next = await withClock(
        Clock.fixed(today.add(const Duration(days: 1))),
        read,
      );
      expect(next.day, '2026-11-02');
      expect(next, isNot(first));
    });

    test(
      'plans from what is stored, not from a half-loaded provider',
      () async {
        SharedPreferences.setMockInitialValues({
          LocalSavableKey.lastFootCheck.value: FootCheckRecord(
            rating: FootCheckRating.good,
            takenAt: DateTime(2026, 10, 31, 9),
          ).encode(),
          LocalSavableKey.gameActivity.value: const GameActivityLog()
              .add(
                GameActivity(
                  slug: 'hop',
                  seconds: 9,
                  at: DateTime(2026, 10, 31),
                ),
              )
              .encode(),
        });
        final plan = await withClock(Clock.fixed(today), read);
        expect(plan.items.map((i) => i.id), isNot(contains('foot_check')));
        expect(plan.items.map((i) => i.id), isNot(contains('hop')));
      },
    );
  });
}
