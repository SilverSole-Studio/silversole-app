import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';

/// What the mobility card at the top of the gait tab shows.
sealed class MobilityCard {
  const MobilityCard();
}

/// Not enough weeks yet: how many qualifying weeks exist, out of how many
/// are needed. Carries no grade on purpose.
class MobilityPending extends MobilityCard {
  const MobilityPending({required this.weeksSoFar, required this.weeksNeeded});

  final int weeksSoFar;
  final int weeksNeeded;
}

class MobilityGraded extends MobilityCard {
  const MobilityGraded({
    required this.weekStart,
    required this.isCurrentWeek,
    required this.grade,
    required this.changes,
    required this.rows,
  });

  /// [gaitDateKey] of the Monday of the week shown.
  final String weekStart;
  final bool isCurrentWeek;
  final MobilityGrade grade;

  /// At most two items, for the explanation sentence.
  final List<MobilityChange> changes;

  /// Metrics that have a grade this week, in [MobilityMetric] order.
  final List<MobilityMetricRow> rows;
}

class MobilityChange {
  const MobilityChange({required this.metric, required this.better});

  final MobilityMetric metric;
  final bool better;
}

class MobilityMetricRow {
  const MobilityMetricRow({
    required this.metric,
    required this.grade,
    required this.trend,
  });

  final MobilityMetric metric;
  final MobilityGrade grade;

  /// Oldest to newest, at most [mobilityTrendWeeks] points; empty when there
  /// are fewer than two to draw.
  final List<double> trend;
}

/// Most weeks a trend line reaches back.
const mobilityTrendWeeks = 8;

/// Decides what the card shows from the graded [weeks] (oldest first).
///
/// The week containing [today] is shown when it already has a grade;
/// otherwise the latest graded week. With none graded, the card is pending.
MobilityCard mobilityCard(List<WeekMobility> weeks, {required DateTime today}) {
  const config = MobilityGradeConfig();
  final thisMonday = gaitDateKey(
    DateTime(today.year, today.month, today.day - (today.weekday - 1)),
  );

  final shown = weeks.lastIndexWhere((w) => w.grade != null);
  if (shown < 0) {
    return MobilityPending(
      weeksSoFar: weeks.where((w) => w.wornDays >= config.minWornDays).length,
      weeksNeeded: config.minBaselineWeeks + 1,
    );
  }

  // Weeks are sorted oldest first, so the latest graded week is the current
  // one exactly when it starts on this week's Monday.
  final week = weeks[shown];
  final grade = week.grade!;
  final changes = switch (grade) {
    MobilityGrade.a || MobilityGrade.b => [
      for (final m in week.better.take(2))
        MobilityChange(metric: m, better: true),
    ],
    MobilityGrade.d || MobilityGrade.e => [
      for (final m in week.worse.take(2))
        MobilityChange(metric: m, better: false),
    ],
    MobilityGrade.c => const <MobilityChange>[],
  };

  final rows = <MobilityMetricRow>[];
  for (final metric in MobilityMetric.values) {
    final score = week.metrics[metric];
    if (score == null) continue;
    final points = <double>[
      for (final w in weeks.take(shown + 1))
        if (w.values[metric] case final v?) v,
    ];
    final trend = points.length < 2
        ? const <double>[]
        : points.sublist(
            points.length > mobilityTrendWeeks
                ? points.length - mobilityTrendWeeks
                : 0,
          );
    rows.add(
      MobilityMetricRow(metric: metric, grade: score.grade, trend: trend),
    );
  }

  return MobilityGraded(
    weekStart: week.weekStart,
    isCurrentWeek: week.weekStart == thisMonday,
    grade: grade,
    changes: changes,
    rows: rows,
  );
}
