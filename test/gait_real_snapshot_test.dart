import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/models/gait_real_snapshot.dart';

final _today = DateTime(2026, 11, 2, 15);

/// A day [daysAgo] before today with [steps] walking steps on the right foot:
/// one minute of walking per 100 steps, 650 ms stance, 1100 ms strides.
DailyGait _day(int daysAgo, int steps, {bool bothFeet = false}) {
  final date = gaitDateKey(
    DateTime(_today.year, _today.month, _today.day - daysAgo),
  );
  final contacts = steps ~/ 2;
  final foot = FootGaitStats(
    contacts: contacts,
    walkingMs: steps * 600,
    stanceMs: contacts * 650,
    swingMs: contacts * 450,
    strides: contacts,
    strideMs: contacts * 1100,
    strideSqMs: contacts * 1100 * 1100,
  );
  return DailyGait(
    date: date,
    steps: steps,
    feet: {GaitFoot.right: foot, if (bothFeet) GaitFoot.left: foot},
    doubleSupportMs: bothFeet ? steps * 100 : 0,
    bothFeetWalkingMs: bothFeet ? steps * 600 : 0,
  );
}

/// A day with 20 strides that all last [strideMs]: its own variation is 0.
DailyGait _steadyDay(int daysAgo, int strideMs) {
  const strides = 20;
  return DailyGait(
    date: gaitDateKey(
      DateTime(_today.year, _today.month, _today.day - daysAgo),
    ),
    steps: 40,
    feet: {
      GaitFoot.right: FootGaitStats(
        contacts: strides,
        walkingMs: 40000,
        stanceMs: strides * 650,
        swingMs: strides * (strideMs - 650),
        strides: strides,
        strideMs: strides * strideMs,
        strideSqMs: strides * strideMs * strideMs,
      ),
    },
  );
}

Map<String, DailyGait> _history(List<DailyGait> days) => {
  for (final d in days) d.date: d,
};

String? _value(List<GaitMetric> metrics, String nameKey) =>
    metrics.where((m) => m.nameKey == nameKey).firstOrNull?.value;

void main() {
  test('no data at all: every scale is still collecting', () {
    for (final scale in GaitScale.values) {
      final s = realGaitSnapshot(
        scale: scale,
        history: const {},
        today: _today,
        fallCount: 0,
      );
      expect(s.isSample, isFalse);
      expect(s.pendingDays, gaitDaysNeeded(scale));
    }
  });

  test('week: averages the days worn and charts each day', () {
    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([_day(0, 3000), _day(2, 5000)]),
      today: _today,
      fallCount: 2,
    );

    expect(s.isPending, isFalse);
    expect(s.phase, isNull);
    expect(s.heroValue, '4000');
    expect(s.heroUnitKey, 'gait_unit_steps');
    expect(s.heroTopic, GaitTopic.steps);
    expect(s.series, [0, 0, 0, 0, 5000, 0, 3000]);
    expect(s.fallCount, 2);
    expect(s.fallLastKey, isNull);
    expect(s.referenceSpeed, isNull);
    expect(s.adviceKeys, isEmpty);
    // 8000 steps over 2 × 8000 × 600 ms → 8000 / (4800 s / 60) = 100 / min.
    expect(_value(s.ability, 'gait_metric_cadence'), '100');
    expect(_value(s.ability, 'gait_metric_stance'), '59');
    expect(_value(s.stability, 'gait_metric_stride_cv'), '0.0');
    expect(_value(s.stability, 'gait_metric_symmetry'), isNull);
    expect(_value(s.stability, 'gait_metric_double_support'), isNull);
  });

  test('stride variation is not inflated by days at different paces', () {
    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([_steadyDay(0, 1000), _steadyDay(1, 1200)]),
      today: _today,
      fallCount: 0,
    );
    // Pooled over both days the strides would spread about 9 %; each day on
    // its own is perfectly even.
    expect(_value(s.stability, 'gait_metric_stride_cv'), '0.0');
  });

  test('days outside the window do not count towards it', () {
    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([_day(8, 3000)]),
      today: _today,
      fallCount: 0,
    );
    expect(s.pendingDays, 1);
  });

  test('month needs seven days in the last four weeks', () {
    final six = _history([for (var i = 0; i < 6; i++) _day(i, 3000)]);
    expect(
      realGaitSnapshot(
        scale: GaitScale.month,
        history: six,
        today: _today,
        fallCount: 0,
      ).pendingDays,
      1,
    );

    final seven = _history([for (var i = 0; i < 7; i++) _day(i, 3000)]);
    final s = realGaitSnapshot(
      scale: GaitScale.month,
      history: seven,
      today: _today,
      fallCount: 0,
    );
    expect(s.isPending, isFalse);
    // The three weeks before the first one worn are not drawn.
    expect(s.series, [3000]);
  });

  test('both feet bring balance and double support', () {
    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([_day(0, 3000, bothFeet: true)]),
      today: _today,
      fallCount: 0,
    );
    expect(_value(s.stability, 'gait_metric_symmetry'), '100');
    expect(_value(s.stability, 'gait_metric_double_support'), '16.7');
  });

  test('quarter draws weekly lines once 28 days are in', () {
    final s = realGaitSnapshot(
      scale: GaitScale.quarter,
      history: _history([for (var i = 0; i < 28; i++) _day(i, 3000 + i * 10)]),
      today: _today,
      fallCount: 0,
    );
    expect(s.isPending, isFalse);
    // Eight empty weeks before the first one worn are not drawn.
    expect(s.series, hasLength(4));
    expect(s.smallMultiplesTitleKey, 'gait_sect_weekly_metrics');
    expect(
      s.smallMultiples.map((l) => l.nameKey),
      containsAll(['gait_metric_daily_steps', 'gait_metric_cadence']),
    );
    for (final line in s.smallMultiples) {
      expect(line.values, hasLength(4), reason: 'only weeks with data');
    }
  });

  test('a stored day whose figures are not finite leaves those rows out', () {
    // Parsable but corrupt: strides are counted yet carry no time at all, so
    // stance and stride variation come to 0 / 0.
    const broken = FootGaitStats(
      contacts: 10,
      walkingMs: 6000,
      stanceMs: 0,
      swingMs: 0,
      strides: 10,
      strideMs: 0,
      strideSqMs: 0,
    );
    final day = DailyGait(
      date: gaitDateKey(DateTime(_today.year, _today.month, _today.day)),
      steps: 20,
      feet: const {GaitFoot.right: broken},
    );

    final s = realGaitSnapshot(
      scale: GaitScale.week,
      history: _history([day]),
      today: _today,
      fallCount: 0,
    );

    expect(s.isPending, isFalse);
    expect(_value(s.ability, 'gait_metric_stance'), isNull);
    expect(_value(s.stability, 'gait_metric_stride_cv'), isNull);
    expect(_value(s.ability, 'gait_metric_cadence'), isNotNull);
  });
}
