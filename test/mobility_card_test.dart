import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/shared/models/mobility_card.dart';

final _monday = DateTime(2026, 11, 2);

DateTime _date(int week, int dayInWeek) =>
    DateTime(_monday.year, _monday.month, _monday.day + week * 7 + dayInWeek);

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
    gaitDateKey(_date(week, i)): _day(
      _date(week, i),
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

MobilityCard _card(Map<String, DailyGait> history, DateTime today) =>
    mobilityCard(gradeMobility(history), today: today);

void main() {
  test('no data at all is pending with no weeks', () {
    final card = _card({}, _date(0, 2));
    expect(card, isA<MobilityPending>());
    card as MobilityPending;
    expect(card.weeksSoFar, 0);
    expect(card.weeksNeeded, 3);
  });

  test('two qualifying weeks are still pending', () {
    final card = _card(_usual(2), _date(1, 4));
    card as MobilityPending;
    expect(card.weeksSoFar, 2);
    expect(card.weeksNeeded, 3);
  });

  test('a week with too few worn days does not count towards pending', () {
    final card = _card({..._week(0), ..._week(1, days: 2)}, _date(1, 4));
    card as MobilityPending;
    expect(card.weeksSoFar, 1);
  });

  test('this week is shown once it has a grade', () {
    final card = _card(_usual(4), _date(3, 4));
    card as MobilityGraded;
    expect(card.isCurrentWeek, isTrue);
    expect(card.weekStart, gaitDateKey(_date(3, 0)));
    expect(card.grade, MobilityGrade.c);
  });

  test('a barely worn week falls back to the latest graded week', () {
    final card = _card({..._usual(4), ..._week(4, days: 1)}, _date(4, 3));
    card as MobilityGraded;
    expect(card.isCurrentWeek, isFalse);
    expect(card.weekStart, gaitDateKey(_date(3, 0)));
  });

  test('today on a Sunday still belongs to that week', () {
    final card = _card(_usual(4), _date(3, 6));
    card as MobilityGraded;
    expect(card.isCurrentWeek, isTrue);
  });

  test('an A week names its two best metrics as better', () {
    final card = _card({
      ..._usual(3),
      ..._week(
        3,
        steps: 3900,
        cadence: 106,
        symmetry: 0.99,
        cv: 0.02,
        doubleSupport: 0.21,
      ),
    }, _date(3, 4));
    card as MobilityGraded;
    expect(card.grade, MobilityGrade.a);
    expect(card.changes, hasLength(2));
    expect(card.changes.every((c) => c.better), isTrue);
    expect(card.changes.first.metric, MobilityMetric.dailySteps);
    expect(card.rows.map((r) => r.metric), MobilityMetric.values);
  });

  test('a D week names what pulled it down', () {
    final card = _card({
      ..._usual(3),
      ..._week(3, steps: 2100, cadence: 92, symmetry: 0.88, cv: 0.05),
    }, _date(3, 4));
    card as MobilityGraded;
    expect(card.grade, MobilityGrade.d);
    expect(card.changes, isNotEmpty);
    expect(card.changes.length, lessThanOrEqualTo(2));
    expect(card.changes.every((c) => !c.better), isTrue);
  });

  test('a C week has nothing to explain', () {
    final card = _card(_usual(4), _date(3, 4));
    card as MobilityGraded;
    expect(card.changes, isEmpty);
  });

  test('trend lines run oldest to newest and stop at eight weeks', () {
    final history = {
      for (var w = 0; w < 10; w++) ..._week(w, steps: 3000 + w * 10),
    };
    final card = _card(history, _date(9, 4));
    card as MobilityGraded;
    final steps = card.rows.firstWhere(
      (r) => r.metric == MobilityMetric.dailySteps,
    );
    expect(steps.trend, hasLength(8));
    expect(steps.trend.first, 3020);
    expect(steps.trend.last, 3090);
  });

  test('a trend line is never a single point', () {
    final card = _card(_usual(3), _date(2, 4));
    card as MobilityGraded;
    for (final row in card.rows) {
      expect(row.trend.length, anyOf(0, greaterThanOrEqualTo(2)));
    }
  });
}
