import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';

final _monday = () {
  final d = DateTime(2026, 11, 2);
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}();

/// A two-sole day with the given steps, cadence (steps/min), symmetry
/// (shorter over longer stance), stride variation and double-support share.
DailyGait _day(
  DateTime date, {
  int steps = 3000,
  double cadence = 100,
  double symmetry = 0.95,
  double cv = 0.03,
  double doubleSupport = 0.25,
}) {
  final walkingMs = (steps / cadence * 60000).round();
  final contacts = steps ~/ 2;
  final strides = contacts - 1;
  const strideMs = 1200;
  final sd = cv * strideMs;
  FootGaitStats foot(double stanceMs) => FootGaitStats(
    contacts: contacts,
    walkingMs: walkingMs,
    stanceMs: (stanceMs * contacts).round(),
    swingMs: 450 * strides,
    strides: strides,
    strideMs: strideMs * strides,
    strideSqMs: (strides * (strideMs * strideMs + sd * sd)).round(),
  );
  return DailyGait(
    date: gaitDateKey(date),
    steps: steps,
    feet: {GaitFoot.left: foot(700), GaitFoot.right: foot(700 * symmetry)},
    doubleSupportMs: (doubleSupport * walkingMs).round(),
    bothFeetWalkingMs: walkingMs,
  );
}

/// [days] worn days in week [week] (0 = the first Monday), all alike.
Map<String, DailyGait> _week(
  int week, {
  int days = 5,
  int steps = 3000,
  double cadence = 100,
  double symmetry = 0.95,
  double cv = 0.03,
  double doubleSupport = 0.25,
}) => {
  for (var i = 0; i < days; i++)
    gaitDateKey(
      DateTime(_monday.year, _monday.month, _monday.day + week * 7 + i),
    ): _day(
      DateTime(_monday.year, _monday.month, _monday.day + week * 7 + i),
      steps: steps,
      cadence: cadence,
      symmetry: symmetry,
      cv: cv,
      doubleSupport: doubleSupport,
    ),
};

Map<String, DailyGait> _usual(int weeks) => {
  for (var w = 0; w < weeks; w++) ..._week(w),
};

void main() {
  test('no grade until two earlier weeks to compare with', () {
    final weeks = gradeMobility(_usual(3));
    expect(weeks.map((w) => w.grade), [null, null, MobilityGrade.c]);
    expect(weeks.first.weekStart, gaitDateKey(_monday));
  });

  test('a week clearly better on every metric is A', () {
    final weeks = gradeMobility({
      ..._usual(3),
      ..._week(
        3,
        steps: 3900,
        cadence: 106,
        symmetry: 0.99,
        cv: 0.02,
        doubleSupport: 0.21,
      ),
    });
    final last = weeks.last;
    expect(last.grade, MobilityGrade.a);
    expect(last.better.first, MobilityMetric.dailySteps);
    expect(last.worse, isEmpty);
  });

  test('one bad week is D, two in a row is E, then it recovers', () {
    Map<String, DailyGait> bad(int week) =>
        _week(week, steps: 2100, cadence: 92, symmetry: 0.88, cv: 0.05);
    final weeks = gradeMobility({
      ..._usual(3),
      ...bad(3),
      ...bad(4),
      ..._week(5),
    });
    expect(weeks[3].grade, MobilityGrade.d);
    expect(weeks[4].grade, MobilityGrade.e);
    expect(weeks[4].worse, contains(MobilityMetric.cadence));
    expect(weeks[3].metrics[MobilityMetric.cadence]!.grade, MobilityGrade.d);
    expect(weeks[4].metrics[MobilityMetric.cadence]!.grade, MobilityGrade.e);
    // The baseline now holds the two bad weeks, so a usual week reads as
    // no worse than usual.
    expect(weeks[5].grade, isNot(MobilityGrade.d));
    expect(weeks[5].grade, isNot(MobilityGrade.e));
  });

  test('a skipped week breaks the run, so a second bad week stays D', () {
    final weeks = gradeMobility({
      ..._usual(3),
      ..._week(3, steps: 2100, cadence: 92, cv: 0.05),
      ..._week(5, steps: 2100, cadence: 92, cv: 0.05),
    });
    expect(weeks.map((w) => w.grade).toList().sublist(3), [
      MobilityGrade.d,
      MobilityGrade.d,
    ]);
  });

  test('a week with too few worn days is not graded nor used as baseline', () {
    final weeks = gradeMobility({
      ..._week(0),
      ..._week(1, days: 2, steps: 9000),
      ..._week(2),
      ..._week(3),
    });
    expect(weeks[1].grade, isNull);
    expect(weeks[2].grade, isNull);
    expect(weeks[3].grade, MobilityGrade.c);
  });

  test('a few metrics up and the rest unchanged is only B', () {
    final weeks = gradeMobility({
      ..._usual(3),
      ..._week(3, steps: 3900, cadence: 106, cv: 0.02),
    });
    expect(weeks.last.grade, MobilityGrade.b);
  });

  test('a small change stays C', () {
    final weeks = gradeMobility({
      ..._usual(3),
      ..._week(3, steps: 3150, cadence: 101),
    });
    expect(weeks.last.grade, MobilityGrade.c);
  });
}
