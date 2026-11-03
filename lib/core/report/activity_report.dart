import 'dart:math' as math;

import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/shared/models/mobility_card.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// Days the shared record covers, counting today.
const activityReportDays = 7;

/// The parts of the shared record, in the order they are laid out. Each is
/// left out of the record when the wearer has no data for it, and each can be
/// unticked before sharing.
enum ReportSection { footCheck, games, gait, mobility }

/// The last foot check: the band, and the two load splits when the record kept
/// them (records written before they were stored have only the band).
class FootCheckSection {
  const FootCheckSection({
    required this.takenAt,
    required this.rating,
    this.foreRatio,
    this.medialRatio,
  });

  final DateTime takenAt;
  final FootCheckRating rating;

  /// Forefoot share of the load, 0 → 1; its rear share is the rest.
  final double? foreRatio;

  /// Inner share of the forefoot load, 0 → 1; its outer share is the rest.
  /// Null when the forefoot carried too little load to split.
  final double? medialRatio;

  /// Whether the front/back split was kept.
  bool get hasRatios => foreRatio != null;

  /// Whether the inner/outer split was kept.
  bool get hasMedial => medialRatio != null;

  /// A front/back split but no inner/outer one: the forefoot carried too
  /// little load.
  bool get lacksMedial => hasRatios && !hasMedial;

  /// Whole percent of the forefoot share; [rearPercent] is the rest so the two
  /// always add up to 100.
  int? get forePercent => foreRatio == null ? null : (foreRatio! * 100).round();
  int? get rearPercent => forePercent == null ? null : 100 - forePercent!;

  /// Whole percent of the inner share; [lateralPercent] is the rest.
  int? get medialPercent =>
      medialRatio == null ? null : (medialRatio! * 100).round();
  int? get lateralPercent =>
      medialPercent == null ? null : 100 - medialPercent!;
}

/// How often one game was played. A null [slug] stands for every game the app
/// has no name for.
class GameTally {
  const GameTally({required this.slug, required this.rounds});

  final String? slug;
  final int rounds;
}

/// The game rounds of the period.
class GameSection {
  const GameSection({
    required this.activeDays,
    required this.totalSeconds,
    required this.games,
  });

  /// Days with at least one round.
  final int activeDays;
  final int totalSeconds;

  /// Most played first, unnamed games last.
  final List<GameTally> games;

  /// Whole minutes, never 0 once anything was played.
  int get totalMinutes =>
      totalSeconds <= 0 ? 0 : math.max(1, (totalSeconds / 60).round());
}

class GaitDayBar {
  const GaitDayBar({required this.day, required this.steps});

  final DateTime day;
  final int steps;
}

/// Walking over the period: a bar per day and two averages.
class GaitSection {
  const GaitSection({
    required this.days,
    required this.averageCadence,
    required this.averageWalkingMinutes,
  });

  /// One per day of the period, oldest first; a day without data is 0.
  final List<GaitDayBar> days;

  /// Steps per minute, averaged over the days that have one.
  final double? averageCadence;

  /// Minutes of walking per day, averaged over the days with steps.
  final int? averageWalkingMinutes;
}

class MobilityMetricGrade {
  const MobilityMetricGrade({required this.metric, required this.grade});

  final MobilityMetric metric;
  final MobilityGrade grade;
}

/// The latest graded week of the mobility card.
class MobilitySection {
  const MobilitySection({
    required this.weekStart,
    required this.isCurrentWeek,
    required this.grade,
    required this.changes,
    required this.metrics,
  });

  final DateTime weekStart;
  final bool isCurrentWeek;
  final MobilityGrade grade;
  final List<MobilityChange> changes;
  final List<MobilityMetricGrade> metrics;
}

/// Everything the shared activity record can say, gathered from what the app
/// already keeps on the phone. A part with nothing to report is null.
class ActivityReport {
  const ActivityReport({
    required this.generatedOn,
    required this.periodStart,
    this.footCheck,
    this.games,
    this.gait,
    this.mobility,
  });

  /// Today, as a local date at midnight.
  final DateTime generatedOn;

  /// First day of the period, as a local date at midnight.
  final DateTime periodStart;

  final FootCheckSection? footCheck;
  final GameSection? games;
  final GaitSection? gait;
  final MobilitySection? mobility;

  /// The parts that have data, in layout order.
  List<ReportSection> get sections => [
    if (footCheck != null) ReportSection.footCheck,
    if (games != null) ReportSection.games,
    if (gait != null) ReportSection.gait,
    if (mobility != null) ReportSection.mobility,
  ];

  bool get isEmpty => sections.isEmpty;
}

/// Builds the record for the [activityReportDays] days ending [today].
///
/// [gaitHistory] and [mobility] are only read when given: the caller passes
/// them only while gait tracking is on, so a build that shows the sample gait
/// page never puts sample numbers in a record.
ActivityReport buildActivityReport({
  required DateTime today,
  required FootCheckRecord? footCheck,
  required GameActivityLog activity,
  Map<String, DailyGait>? gaitHistory,
  MobilityCard? mobility,
}) {
  final end = DateTime(today.year, today.month, today.day);
  final start = DateTime(
    end.year,
    end.month,
    end.day - (activityReportDays - 1),
  );
  final days = [
    for (var i = 0; i < activityReportDays; i++)
      DateTime(start.year, start.month, start.day + i),
  ];

  return ActivityReport(
    generatedOn: end,
    periodStart: start,
    footCheck: footCheck == null
        ? null
        : FootCheckSection(
            takenAt: footCheck.takenAt,
            rating: footCheck.rating,
            foreRatio: footCheck.foreRatio,
            medialRatio: footCheck.medialRatio,
          ),
    games: _games(days, activity),
    gait: gaitHistory == null ? null : _gait(days, gaitHistory),
    mobility: switch (mobility) {
      final MobilityGraded graded => MobilitySection(
        weekStart: DateTime.parse(graded.weekStart),
        isCurrentWeek: graded.isCurrentWeek,
        grade: graded.grade,
        changes: graded.changes,
        metrics: [
          for (final row in graded.rows)
            MobilityMetricGrade(metric: row.metric, grade: row.grade),
        ],
      ),
      _ => null,
    },
  );
}

GameSection? _games(List<DateTime> days, GameActivityLog log) {
  var activeDays = 0;
  var seconds = 0;
  final rounds = <String, int>{};
  var other = 0;
  for (final day in days) {
    final played = log.byDay[gaitDateKey(day)];
    if (played == null || played.isEmpty) continue;
    activeDays++;
    for (final a in played) {
      seconds += a.seconds;
      if (MissionCatalog.isGame(a.slug)) {
        rounds[a.slug] = (rounds[a.slug] ?? 0) + 1;
      } else {
        other++;
      }
    }
  }
  if (activeDays == 0) return null;

  // Most played first; a tie keeps the order the games are listed in (the
  // sort is stable).
  final known = [
    for (final id in MissionCatalog.gameIds)
      if (rounds.containsKey(id)) GameTally(slug: id, rounds: rounds[id]!),
  ]..sort((a, b) => b.rounds.compareTo(a.rounds));
  return GameSection(
    activeDays: activeDays,
    totalSeconds: seconds,
    games: [
      ...known,
      if (other > 0) GameTally(slug: null, rounds: other),
    ],
  );
}

GaitSection? _gait(List<DateTime> days, Map<String, DailyGait> history) {
  final bars = <GaitDayBar>[];
  final withSteps = <DailyGait>[];
  for (final day in days) {
    final gait = history[gaitDateKey(day)];
    final steps = gait != null && gait.hasData ? gait.steps : 0;
    if (gait != null && steps > 0) withSteps.add(gait);
    bars.add(GaitDayBar(day: day, steps: steps));
  }
  if (withSteps.isEmpty) return null;

  final cadences = [
    for (final d in withSteps)
      if (finiteOrNull(d.cadence) case final c?) c,
  ];
  final walkingMs = withSteps.fold(0, (n, d) => n + d.walkingMs);
  return GaitSection(
    days: bars,
    averageCadence: cadences.isEmpty
        ? null
        : cadences.reduce((a, b) => a + b) / cadences.length,
    averageWalkingMinutes: walkingMs <= 0
        ? null
        : (walkingMs / withSteps.length / 60000).round(),
  );
}
