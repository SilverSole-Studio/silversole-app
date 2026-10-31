import 'package:silversole/core/gait/daily_gait.dart';

/// Weekly A–E "mobility" grades, each measured against the wearer's own
/// recent weeks — never against other people and never against a clinical
/// threshold. A grade says how this week compares with the wearer's usual,
/// not how healthy they are, so it must not be shown as a health or risk
/// level (see the spec in the company repo, `_行動力等級規格`).
enum MobilityGrade {
  /// Clearly better than usual.
  a,

  /// A little better.
  b,

  /// About as usual.
  c,

  /// A little worse.
  d,

  /// Clearly worse for at least two weeks in a row.
  e,
}

/// The weekly measures a grade is built from.
enum MobilityMetric {
  /// Steps per worn day. Higher is better.
  dailySteps,

  /// Steps per minute of walking. Higher is better.
  cadence,

  /// Shorter mean stance over the longer one, 0–1. Higher is better.
  symmetry,

  /// Coefficient of variation of stride time. Lower is better.
  strideVariation,

  /// Share of walking with both feet down. Lower is better.
  doubleSupport,
}

/// How much of a change counts as meaningful for each metric, and the other
/// knobs of the grader.
///
/// The defaults are working values picked for a first version, not
/// clinical cut-offs; they are meant to be tuned once real wearers' weeks
/// are in.
class MobilityGradeConfig {
  const MobilityGradeConfig({
    this.minWornDays = 3,
    this.minBaselineWeeks = 2,
    this.maxBaselineWeeks = 8,
    this.minMetrics = 2,
    this.relativeStep = const {
      MobilityMetric.dailySteps: 0.20,
      MobilityMetric.cadence: 0.05,
    },
    this.absoluteStep = const {
      MobilityMetric.symmetry: 0.03,
      MobilityMetric.strideVariation: 0.01,
      MobilityMetric.doubleSupport: 0.03,
    },
    this.aFrom = 1.0,
    this.bFrom = 0.4,
    this.lowFrom = -1.0,
  });

  /// Worn days a week needs before it is graded or used as a baseline.
  final int minWornDays;

  /// Earlier graded-eligible weeks needed before any grade is given.
  final int minBaselineWeeks;

  /// The baseline is the median of at most this many earlier weeks.
  final int maxBaselineWeeks;

  /// A main grade needs at least this many metrics with a score.
  final int minMetrics;

  /// Meaningful change as a share of the baseline.
  final Map<MobilityMetric, double> relativeStep;

  /// Meaningful change in the metric's own units.
  final Map<MobilityMetric, double> absoluteStep;

  /// Score from which a week is A, and from which it is B. C runs down to
  /// minus [bFrom]; at or below [lowFrom] a week is "clearly worse".
  final double aFrom;
  final double bFrom;
  final double lowFrom;
}

/// One metric's score for one week.
class MetricScore {
  const MetricScore({
    required this.metric,
    required this.value,
    required this.baseline,
    required this.score,
    required this.grade,
  });

  final MobilityMetric metric;
  final double value;
  final double baseline;

  /// Change from the baseline in meaningful steps, signed so that positive
  /// is better and clamped to ±2.
  final double score;
  final MobilityGrade grade;
}

/// The grades of one week.
class WeekMobility {
  const WeekMobility({
    required this.weekStart,
    required this.wornDays,
    required this.metrics,
    required this.score,
    required this.grade,
  });

  /// [gaitDateKey] of the week's Monday.
  final String weekStart;
  final int wornDays;
  final Map<MobilityMetric, MetricScore> metrics;

  /// Mean of the metric scores; null with too little data.
  final double? score;

  /// Null while there is too little data to compare with: too few worn
  /// days this week, too few earlier weeks, or too few metrics.
  final MobilityGrade? grade;

  /// Metrics that pulled this week down, worst first.
  List<MobilityMetric> get worse {
    final down = metrics.values.where((m) => m.grade.index >= 3).toList()
      ..sort((x, y) => x.score.compareTo(y.score));
    return [for (final m in down) m.metric];
  }

  /// Metrics that lifted this week, best first.
  List<MobilityMetric> get better {
    final up = metrics.values.where((m) => m.grade.index <= 1).toList()
      ..sort((x, y) => y.score.compareTo(x.score));
    return [for (final m in up) m.metric];
  }
}

/// Grades every week in [history], oldest first.
///
/// Weeks run Monday to Sunday. Each graded week is compared with the median
/// of up to [MobilityGradeConfig.maxBaselineWeeks] earlier weeks that had
/// enough worn days, so a slow drift moves the baseline with it — a grade
/// shows a change, not a level.
List<WeekMobility> gradeMobility(
  Map<String, DailyGait> history, {
  MobilityGradeConfig config = const MobilityGradeConfig(),
}) {
  final weeks = <String, List<DailyGait>>{};
  for (final day in history.values) {
    if (!day.hasData) continue;
    weeks.putIfAbsent(_weekStart(day.date), () => []).add(day);
  }
  final keys = weeks.keys.toList()..sort();

  final eligible = <String, Map<MobilityMetric, double>>{};
  final results = <WeekMobility>[];
  final lowWeeks = <String>{};
  final lowMetricWeeks = <MobilityMetric, Set<String>>{};

  for (final key in keys) {
    final days = weeks[key]!;
    final values = _weekValues(days);
    final baselines = <MobilityMetric, double>{};
    final earlier = eligible.keys.toList().reversed.take(
      config.maxBaselineWeeks,
    );
    if (earlier.length >= config.minBaselineWeeks) {
      for (final metric in MobilityMetric.values) {
        final past = [
          for (final k in earlier)
            if (eligible[k]![metric] != null) eligible[k]![metric]!,
        ];
        if (past.length >= config.minBaselineWeeks) {
          baselines[metric] = _median(past);
        }
      }
    }

    final enoughDays = days.length >= config.minWornDays;
    final scores = <MobilityMetric, MetricScore>{};
    if (enoughDays) {
      for (final entry in values.entries) {
        final baseline = baselines[entry.key];
        if (baseline == null) continue;
        final score = _score(entry.key, entry.value, baseline, config);
        if (score == null) continue;
        final low = score <= config.lowFrom;
        if (low) lowMetricWeeks.putIfAbsent(entry.key, () => {}).add(key);
        final persistent =
            low &&
            (lowMetricWeeks[entry.key]?.contains(_previousWeek(key)) ?? false);
        scores[entry.key] = MetricScore(
          metric: entry.key,
          value: entry.value,
          baseline: baseline,
          score: score,
          grade: _grade(score, persistent, config),
        );
      }
    }

    double? mean;
    MobilityGrade? grade;
    if (scores.length >= config.minMetrics) {
      mean = scores.values.fold(0.0, (n, m) => n + m.score) / scores.length;
      final low = mean <= config.lowFrom;
      if (low) lowWeeks.add(key);
      grade = _grade(
        mean,
        low && lowWeeks.contains(_previousWeek(key)),
        config,
      );
    }

    results.add(
      WeekMobility(
        weekStart: key,
        wornDays: days.length,
        metrics: scores,
        score: mean,
        grade: grade,
      ),
    );
    if (enoughDays) eligible[key] = values;
  }
  return results;
}

Map<MobilityMetric, double> _weekValues(List<DailyGait> days) {
  final week = days.skip(1).fold(days.first, (w, d) => w.merge(d));
  return {
    MobilityMetric.dailySteps: week.steps / days.length,
    if (week.cadence != null) MobilityMetric.cadence: week.cadence!,
    if (week.symmetry != null) MobilityMetric.symmetry: week.symmetry!,
    if (week.strideCv != null) MobilityMetric.strideVariation: week.strideCv!,
    if (week.doubleSupportRatio != null)
      MobilityMetric.doubleSupport: week.doubleSupportRatio!,
  };
}

const _lowerIsBetter = {
  MobilityMetric.strideVariation,
  MobilityMetric.doubleSupport,
};

double? _score(
  MobilityMetric metric,
  double value,
  double baseline,
  MobilityGradeConfig config,
) {
  final relative = config.relativeStep[metric];
  final step = relative != null
      ? relative * baseline
      : config.absoluteStep[metric];
  if (step == null || step <= 0) return null;
  var change = (value - baseline) / step;
  if (_lowerIsBetter.contains(metric)) change = -change;
  return change.clamp(-2.0, 2.0);
}

MobilityGrade _grade(
  double score,
  bool persistentLow,
  MobilityGradeConfig config,
) {
  if (score >= config.aFrom) return MobilityGrade.a;
  if (score >= config.bFrom) return MobilityGrade.b;
  if (score > -config.bFrom) return MobilityGrade.c;
  return persistentLow ? MobilityGrade.e : MobilityGrade.d;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

String _weekStart(String date) {
  final day = DateTime.parse(date);
  return gaitDateKey(
    DateTime(day.year, day.month, day.day - (day.weekday - 1)),
  );
}

String _previousWeek(String weekStart) {
  final day = DateTime.parse(weekStart);
  return gaitDateKey(DateTime(day.year, day.month, day.day - 7));
}
