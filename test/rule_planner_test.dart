import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/missions/rule_planner.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

void main() {
  // Day 305 of the year: the rotation starts at `hop`.
  final today = DateTime(2026, 11, 1, 10);
  const none = GameActivityLog();

  FootCheckRecord checkedDaysAgo(int n, [DateTime? from]) {
    final base = from ?? today;
    return FootCheckRecord(
      rating: FootCheckRating.good,
      takenAt: DateTime(base.year, base.month, base.day - n, 8),
    );
  }

  GameActivity played(String slug, int daysAgo, [DateTime? from]) {
    final base = from ?? today;
    return GameActivity(
      slug: slug,
      seconds: 60,
      at: DateTime(base.year, base.month, base.day - daysAgo, 12),
    );
  }

  List<String> ids(MissionPlan plan) => [for (final i in plan.items) i.id];

  group('planByRules', () {
    test('never checked: the foot check comes first, then two games', () {
      final plan = planByRules(
        today: today,
        activity: none,
        lastFootCheck: null,
      );
      expect(ids(plan), ['foot_check', 'hop', 'rhythm']);
      expect(plan.source, MissionPlanSource.rule);
      expect(plan.greeting, isNull);
      expect(plan.items.every((i) => i.reason == null), isTrue);
      expect(plan.day, '2026-11-01');
    });

    test('a foot check in the last three days means no foot check mission', () {
      for (final n in [0, 1, 2]) {
        final plan = planByRules(
          today: today,
          activity: none,
          lastFootCheck: checkedDaysAgo(n),
        );
        expect(ids(plan), isNot(contains('foot_check')), reason: '$n days ago');
        expect(ids(plan), hasLength(3));
      }
      final plan = planByRules(
        today: today,
        activity: none,
        lastFootCheck: checkedDaysAgo(3),
      );
      expect(ids(plan).first, 'foot_check');
    });

    test('games played in the last three days are left for later', () {
      final plan = planByRules(
        today: today,
        activity: const GameActivityLog().addAll([
          played('hop', 1),
          played('rhythm', 2),
          played('quiz', 3), // not lately: three days ago
        ]),
        lastFootCheck: checkedDaysAgo(1),
      );
      expect(ids(plan), ['quiz', 'pool', 'laojie']);
    });

    test('when every game was played lately, the longest ago comes first', () {
      final plan = planByRules(
        today: today,
        activity: const GameActivityLog().addAll([
          for (final id in MissionCatalog.gameIds)
            played(id, const ['bike', 'canoe', 'fish'].contains(id) ? 2 : 1),
        ]),
        lastFootCheck: checkedDaysAgo(1),
      );
      // Two days ago, in the order the rotation reaches them.
      expect(ids(plan), ['bike', 'canoe', 'fish']);
    });

    test(
      'too few unplayed games: the rest are filled by who waited longest',
      () {
        final lately = [
          for (final id in MissionCatalog.gameIds)
            if (id != 'ski') played(id, id == 'pool' ? 0 : 2),
        ];
        final plan = planByRules(
          today: today,
          activity: const GameActivityLog().addAll(lately),
          lastFootCheck: checkedDaysAgo(1),
        );
        // ski was not played at all; then rotation order among the two-day-old.
        expect(ids(plan).first, 'ski');
        expect(ids(plan), hasLength(3));
        expect(ids(plan), isNot(contains('pool')));
      },
    );

    test('the same day always gives the same plan, a new day a new one', () {
      final a = planByRules(
        today: DateTime(2026, 11, 1, 6),
        activity: none,
        lastFootCheck: checkedDaysAgo(1),
      );
      final b = planByRules(
        today: DateTime(2026, 11, 1, 23, 50),
        activity: none,
        lastFootCheck: checkedDaysAgo(1),
      );
      final next = planByRules(
        today: DateTime(2026, 11, 2, 6),
        activity: none,
        lastFootCheck: checkedDaysAgo(2, DateTime(2026, 11, 1)),
      );
      expect(a, b);
      expect(ids(next), isNot(ids(a)));
    });

    test('always three distinct known missions, never racer or golf', () {
      var day = DateTime(2026, 1, 1, 9);
      for (var i = 0; i < 400; i++) {
        final activity = const GameActivityLog().addAll([
          played('racer', 0, day),
          played('golf', 1, day),
          if (i % 3 == 0) played(MissionCatalog.gameIds[i % 10], 1, day),
          if (i % 4 == 0) played(MissionCatalog.gameIds[(i + 3) % 10], 0, day),
          if (i % 5 == 0)
            for (final id in MissionCatalog.gameIds) played(id, i % 3, day),
        ]);
        final plan = planByRules(
          today: day,
          activity: activity,
          lastFootCheck: i % 2 == 0 ? null : checkedDaysAgo(i % 5, day),
        );
        final list = ids(plan);
        expect(list, hasLength(3), reason: 'day $i');
        expect(list.toSet(), hasLength(3), reason: 'day $i');
        expect(list.every(MissionCatalog.isKnown), isTrue);
        expect(list, isNot(contains('racer')));
        expect(list, isNot(contains('golf')));
        day = DateTime(day.year, day.month, day.day + 1, 9);
      }
    });
  });

  group('planByRules with step tracking on', () {
    // Day 302: with the foot check done, the games alone give canoe, fish, ski.
    final day = DateTime(2026, 10, 29, 9);
    String key(int daysAgo) =>
        gaitDateKey(DateTime(day.year, day.month, day.day - daysAgo));
    Map<String, DailyGait> steps(Map<int, int> byDaysAgo) => {
      for (final e in byDaysAgo.entries)
        key(e.key): DailyGait(date: key(e.key), steps: e.value),
    };
    final checked = checkedDaysAgo(1, day);

    MissionPlan plan({
      Map<String, DailyGait>? gait,
      List<WeekMobility>? mobility,
      bool footDone = true,
    }) => planByRules(
      today: day,
      activity: none,
      lastFootCheck: footDone ? checked : null,
      gaitHistory: gait,
      mobility: mobility,
    );

    WeekMobility week(
      String start, {
      MobilityGrade? grade,
      MobilityGrade? cadence,
    }) => WeekMobility(
      weekStart: start,
      wornDays: 5,
      values: const {},
      metrics: {
        if (cadence != null)
          MobilityMetric.cadence: MetricScore(
            metric: MobilityMetric.cadence,
            value: 90,
            baseline: 100,
            score: 0,
            grade: cadence,
          ),
      },
      score: 0,
      grade: grade,
    );

    test('without gait the games decide, and gait data is ignored', () {
      expect(ids(plan()), ['canoe', 'fish', 'ski']);
      // Matching data given, but tracking is off (history null): no G1, no G2.
      expect(
        ids(
          plan(
            gait: null,
            mobility: [
              week(
                '2026-10-19',
                grade: MobilityGrade.d,
                cadence: MobilityGrade.d,
              ),
            ],
          ),
        ),
        ['canoe', 'fish', 'ski'],
      );
    });

    test('G1: yesterday clearly under the week before brings in walkgroup', () {
      final low = steps({1: 600, 2: 1000, 3: 1000, 4: 1000});
      expect(ids(plan(gait: low)), ['walkgroup', 'canoe', 'fish']);
    });

    test('G1: exactly 0.7 times the mean does not count, just under does', () {
      expect(ids(plan(gait: steps({1: 700, 2: 1000, 3: 1000, 4: 1000}))), [
        'canoe',
        'fish',
        'ski',
      ]);
      expect(ids(plan(gait: steps({1: 699, 2: 1000, 3: 1000, 4: 1000}))), [
        'walkgroup',
        'canoe',
        'fish',
      ]);
    });

    test('G1: needs three earlier days with data and yesterday itself', () {
      expect(
        ids(plan(gait: steps({1: 100, 2: 1000, 3: 1000}))),
        isNot(contains('walkgroup')),
      );
      // Only days 2..8 before today count: day 9 is too old.
      expect(
        ids(plan(gait: steps({1: 100, 2: 1000, 3: 1000, 9: 1000}))),
        isNot(contains('walkgroup')),
      );
      expect(
        ids(plan(gait: steps({1: 100, 2: 1000, 3: 1000, 8: 1000}))),
        contains('walkgroup'),
      );
      // No data yesterday: nothing to compare.
      expect(
        ids(plan(gait: steps({2: 1000, 3: 1000, 4: 1000}))),
        isNot(contains('walkgroup')),
      );
      // Today's own steps are not yesterday's.
      expect(
        ids(plan(gait: steps({0: 10, 2: 1000, 3: 1000, 4: 1000}))),
        isNot(contains('walkgroup')),
      );
    });

    test(
      'G2: cadence graded D or E in the latest graded week brings in rhythm',
      () {
        for (final g in [MobilityGrade.d, MobilityGrade.e]) {
          expect(
            ids(
              plan(
                gait: const {},
                mobility: [
                  week('2026-10-19', grade: MobilityGrade.c, cadence: g),
                ],
              ),
            ),
            ['rhythm', 'canoe', 'fish'],
            reason: '$g',
          );
        }
      },
    );

    test('G2: C does not, and only the latest graded week counts', () {
      expect(
        ids(
          plan(
            gait: const {},
            mobility: [
              week(
                '2026-10-19',
                grade: MobilityGrade.c,
                cadence: MobilityGrade.c,
              ),
            ],
          ),
        ),
        ['canoe', 'fish', 'ski'],
      );
      expect(
        ids(
          plan(
            gait: const {},
            mobility: [
              week(
                '2026-10-12',
                grade: MobilityGrade.d,
                cadence: MobilityGrade.d,
              ),
              week(
                '2026-10-19',
                grade: MobilityGrade.c,
                cadence: MobilityGrade.c,
              ),
            ],
          ),
        ),
        ['canoe', 'fish', 'ski'],
      );
      // A newer week with no grade is skipped: the one before still counts.
      expect(
        ids(
          plan(
            gait: const {},
            mobility: [
              week(
                '2026-10-12',
                grade: MobilityGrade.c,
                cadence: MobilityGrade.d,
              ),
              week('2026-10-19'),
            ],
          ),
        ),
        contains('rhythm'),
      );
    });

    test(
      'priority: foot check, walkgroup, rhythm, then the games; always 3',
      () {
        final low = steps({1: 100, 2: 1000, 3: 1000, 4: 1000});
        final slow = [
          week('2026-10-19', grade: MobilityGrade.d, cadence: MobilityGrade.d),
        ];
        expect(ids(plan(gait: low, mobility: slow, footDone: false)), [
          'foot_check',
          'walkgroup',
          'rhythm',
        ]);
        expect(ids(plan(gait: low, mobility: slow)), [
          'walkgroup',
          'rhythm',
          'canoe',
        ]);
        expect(ids(plan(gait: low, footDone: false)), [
          'foot_check',
          'walkgroup',
          'canoe',
        ]);
      },
    );

    test(
      'a rule that names a game the rotation also picks does not repeat it',
      () {
        // Day 305 picks hop, rhythm: rhythm from G2 must not appear twice.
        final p = planByRules(
          today: today,
          activity: none,
          lastFootCheck: checkedDaysAgo(1),
          gaitHistory: const {},
          mobility: [
            week(
              '2026-10-26',
              grade: MobilityGrade.d,
              cadence: MobilityGrade.d,
            ),
          ],
        );
        expect(ids(p), ['rhythm', 'hop', 'quiz']);
      },
    );
  });
}
