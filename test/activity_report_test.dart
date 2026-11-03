import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/report/activity_report.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/shared/models/mobility_card.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// A Wednesday.
final _today = DateTime(2026, 11, 4, 20);

GameActivity _round(String slug, DateTime at, {int seconds = 120}) =>
    GameActivity(slug: slug, seconds: seconds, at: at);

GameActivityLog _log(List<GameActivity> rounds) =>
    const GameActivityLog().addAll(rounds, today: _today);

/// A day of walking with [steps] steps over [walkingMs] of walking.
DailyGait _walk(DateTime day, {required int steps, int walkingMs = 600000}) =>
    DailyGait(
      date: gaitDateKey(day),
      steps: steps,
      feet: {GaitFoot.left: FootGaitStats(walkingMs: walkingMs)},
    );

ActivityReport _build({
  FootCheckRecord? footCheck,
  GameActivityLog activity = const GameActivityLog(),
  Map<String, DailyGait>? gaitHistory,
  MobilityCard? mobility,
}) => buildActivityReport(
  today: _today,
  footCheck: footCheck,
  activity: activity,
  gaitHistory: gaitHistory,
  mobility: mobility,
);

void main() {
  group('FootCheckRecord with the load shares', () {
    final takenAt = DateTime(2026, 11, 2, 9);

    test('an old record without shares still reads, shares null', () {
      final old = FootCheckRecord.tryDecode(
        '{"rating":"veryGood","taken_at":${takenAt.millisecondsSinceEpoch}}',
      );
      expect(old, isNotNull);
      expect(old!.rating, FootCheckRating.veryGood);
      expect(old.foreRatio, isNull);
      expect(old.medialRatio, isNull);
    });

    test('a new record keeps both shares through a round trip', () {
      final record = FootCheckRecord(
        rating: FootCheckRating.excellent,
        takenAt: takenAt,
        foreRatio: 0.38,
        medialRatio: 0.55,
      );
      final back = FootCheckRecord.tryDecode(record.encode());
      expect(back, record);
      expect(back!.foreRatio, 0.38);
      expect(back.medialRatio, 0.55);
    });

    test('a record without shares does not write them', () {
      final encoded = FootCheckRecord(
        rating: FootCheckRating.good,
        takenAt: takenAt,
      ).encode();
      expect(encoded, isNot(contains('fore_ratio')));
    });

    test('a bad share is dropped but the band survives', () {
      final at = takenAt.millisecondsSinceEpoch;
      for (final bad in [
        '"fore_ratio":1.5,"medial_ratio":0.5',
        '"fore_ratio":"x","medial_ratio":0.5',
        '"fore_ratio":0.4',
        '"fore_ratio":-0.1,"medial_ratio":0.5',
      ]) {
        final record = FootCheckRecord.tryDecode(
          '{"rating":"good","taken_at":$at,$bad}',
        );
        expect(record, isNotNull, reason: bad);
        expect(record!.rating, FootCheckRating.good);
        expect(record.foreRatio, isNull, reason: bad);
        expect(record.medialRatio, isNull, reason: bad);
      }
    });

    test('fromReport carries the measured shares', () {
      final record = FootCheckRecord.fromReport(
        const FootCheckReport(
          balance: FootLoadBalance(foreRatio: 0.35, medialRatio: 0.6),
          samples: 300,
          collected: Duration(seconds: 60),
        ),
        takenAt,
      );
      expect(record!.foreRatio, 0.35);
      expect(record.medialRatio, 0.6);
    });

    test('fromReport of a heel-only check keeps the check\'s own medial', () {
      // No forefoot load: the tally reports an even split, and so do we.
      final record = FootCheckRecord.fromReport(
        const FootCheckReport(
          balance: FootLoadBalance(
            foreRatio: 0,
            medialRatio: FootLoadBalance.medialTarget,
          ),
          samples: 300,
          collected: Duration(seconds: 60),
        ),
        takenAt,
      );
      expect(record!.foreRatio, 0);
      expect(record.medialRatio, FootLoadBalance.medialTarget);
    });
  });

  group('buildActivityReport', () {
    test('nothing at all -> every section is null', () {
      final report = _build();
      expect(report.footCheck, isNull);
      expect(report.games, isNull);
      expect(report.gait, isNull);
      expect(report.mobility, isNull);
      expect(report.isEmpty, isTrue);
      expect(report.sections, isEmpty);
    });

    test('covers the seven days ending today', () {
      final report = _build();
      expect(report.generatedOn, DateTime(2026, 11, 4));
      expect(report.periodStart, DateTime(2026, 10, 29));
    });

    test('an old foot check gives only the band and the date', () {
      final report = _build(
        footCheck: FootCheckRecord(
          rating: FootCheckRating.veryGood,
          takenAt: DateTime(2026, 10, 1, 9),
        ),
      );
      final check = report.footCheck!;
      expect(check.rating, FootCheckRating.veryGood);
      expect(check.takenAt, DateTime(2026, 10, 1, 9));
      expect(check.hasRatios, isFalse);
      expect(check.forePercent, isNull);
      expect(report.sections, [ReportSection.footCheck]);
    });

    test('a foot check with shares gives percents that add up to 100', () {
      final check = _build(
        footCheck: FootCheckRecord(
          rating: FootCheckRating.excellent,
          takenAt: _today,
          foreRatio: 0.385,
          medialRatio: 0.504,
        ),
      ).footCheck!;
      expect(check.hasRatios, isTrue);
      expect(check.forePercent, 39);
      expect(check.rearPercent, 61);
      expect(check.medialPercent, 50);
      expect(check.lateralPercent, 50);
      expect(check.forePercent! + check.rearPercent!, 100);
      expect(check.medialPercent! + check.lateralPercent!, 100);
    });

    test('games: days, minutes and plays per game over the last 7 days', () {
      final report = _build(
        activity: _log([
          _round('fish', DateTime(2026, 11, 4, 9), seconds: 90),
          _round('fish', DateTime(2026, 11, 4, 10), seconds: 90),
          _round('bike', DateTime(2026, 11, 2, 9), seconds: 120),
          _round('fish', DateTime(2026, 10, 30, 9), seconds: 60),
        ]),
      );
      final games = report.games!;
      expect(games.activeDays, 3);
      expect(games.totalSeconds, 360);
      expect(games.totalMinutes, 6);
      expect(
        [for (final g in games.games) (g.slug, g.rounds)],
        [('fish', 3), ('bike', 1)],
      );
    });

    test('games: the day just outside the period does not count', () {
      // 28 Oct is the eighth day back, still in the stored log.
      final report = _build(
        activity: _log([
          _round('fish', DateTime(2026, 10, 28, 9)),
          _round('bike', DateTime(2026, 10, 29, 9)),
        ]),
      );
      expect(report.games!.activeDays, 1);
      expect([for (final g in report.games!.games) g.slug], ['bike']);
    });

    test('games: only rounds outside the period -> no section', () {
      final report = _build(
        activity: _log([_round('fish', DateTime(2026, 10, 28, 9))]),
      );
      expect(report.games, isNull);
    });

    test('games: unknown slugs merge into one trailing entry', () {
      final report = _build(
        activity: _log([
          _round('mystery', DateTime(2026, 11, 3, 9)),
          _round('other_game', DateTime(2026, 11, 3, 10)),
          _round('mystery', DateTime(2026, 11, 3, 11)),
          _round('quiz', DateTime(2026, 11, 3, 12)),
        ]),
      );
      final games = report.games!.games;
      expect(
        [for (final g in games) (g.slug, g.rounds)],
        [('quiz', 1), (null, 3)],
      );
    });

    test('games: a short session still counts as a minute', () {
      final report = _build(
        activity: _log([_round('hop', DateTime(2026, 11, 4, 9), seconds: 10)]),
      );
      expect(report.games!.totalMinutes, 1);
    });

    test('gait: only when the history is handed in', () {
      final history = {'2026-11-04': _walk(DateTime(2026, 11, 4), steps: 1000)};
      expect(_build().gait, isNull);
      expect(_build(gaitHistory: history).gait, isNotNull);
    });

    test('gait: an empty history -> no section', () {
      expect(_build(gaitHistory: const {}).gait, isNull);
    });

    test('gait: seven bars, a missing day is 0, older days are ignored', () {
      final report = _build(
        gaitHistory: {
          '2026-11-04': _walk(DateTime(2026, 11, 4), steps: 3000),
          '2026-11-02': _walk(DateTime(2026, 11, 2), steps: 5000),
          '2026-10-29': _walk(DateTime(2026, 10, 29), steps: 100),
          '2026-10-28': _walk(DateTime(2026, 10, 28), steps: 9999),
        },
      );
      final bars = report.gait!.days;
      expect(bars, hasLength(7));
      expect(bars.first.day, DateTime(2026, 10, 29));
      expect(bars.last.day, DateTime(2026, 11, 4));
      expect([for (final b in bars) b.steps], [100, 0, 0, 0, 5000, 0, 3000]);
    });

    test('gait: averages only count the days that have data', () {
      // 600 steps in 5 minutes = 120/min; 1000 steps in 10 minutes = 100/min.
      final report = _build(
        gaitHistory: {
          '2026-11-04': _walk(
            DateTime(2026, 11, 4),
            steps: 600,
            walkingMs: 300000,
          ),
          '2026-11-02': _walk(
            DateTime(2026, 11, 2),
            steps: 1000,
            walkingMs: 600000,
          ),
        },
      );
      final gait = report.gait!;
      expect(gait.averageCadence, closeTo(110, 0.001));
      // 15 minutes over the 2 days with data, not over 7.
      expect(gait.averageWalkingMinutes, 8);
    });

    test('mobility: pending card gives no section', () {
      final report = _build(
        mobility: const MobilityPending(weeksSoFar: 1, weeksNeeded: 3),
      );
      expect(report.mobility, isNull);
      expect(_build().mobility, isNull);
    });

    test(
      'mobility: the graded week, its sentence parts and metric letters',
      () {
        final report = _build(
          mobility: const MobilityGraded(
            weekStart: '2026-11-02',
            isCurrentWeek: true,
            grade: MobilityGrade.b,
            changes: [
              MobilityChange(metric: MobilityMetric.cadence, better: true),
            ],
            rows: [
              MobilityMetricRow(
                metric: MobilityMetric.dailySteps,
                grade: MobilityGrade.a,
                trend: [],
              ),
              MobilityMetricRow(
                metric: MobilityMetric.cadence,
                grade: MobilityGrade.c,
                trend: [1, 2],
              ),
            ],
          ),
        );
        final m = report.mobility!;
        expect(m.grade, MobilityGrade.b);
        expect(m.weekStart, DateTime(2026, 11, 2));
        expect(m.isCurrentWeek, isTrue);
        expect(m.changes.single.metric, MobilityMetric.cadence);
        expect(
          [for (final r in m.metrics) (r.metric, r.grade)],
          [
            (MobilityMetric.dailySteps, MobilityGrade.a),
            (MobilityMetric.cadence, MobilityGrade.c),
          ],
        );
      },
    );

    test('sections come back in layout order', () {
      final report = _build(
        footCheck: FootCheckRecord(
          rating: FootCheckRating.good,
          takenAt: _today,
        ),
        activity: _log([_round('fish', DateTime(2026, 11, 4, 9))]),
        gaitHistory: {'2026-11-04': _walk(DateTime(2026, 11, 4), steps: 10)},
        mobility: const MobilityGraded(
          weekStart: '2026-11-02',
          isCurrentWeek: true,
          grade: MobilityGrade.c,
          changes: [],
          rows: [],
        ),
      );
      expect(report.sections, ReportSection.values);
    });
  });
}
