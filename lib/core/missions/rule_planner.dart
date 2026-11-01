import 'package:collection/collection.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// Missions in a day.
const missionsPerDay = 3;

/// No foot check in this many days (today included) puts one in the list;
/// the same window decides which games count as played lately.
const _recentDays = 3;

/// Earlier days with data needed before yesterday's steps are compared.
const _minBaselineDays = 3;

/// Picks [missionsPerDay] distinct missions for [today] from the wearer's own
/// record. A pure function: the same inputs always give the same plan.
///
/// In order:
/// 1. no foot check in the last three days → `foot_check`;
/// 2. only with [gaitHistory] (null while step tracking is off): yesterday's
///    steps well under the week before → `walkgroup`; the latest graded week's
///    cadence graded D or E → `rhythm`;
/// 3. the rest from the games (nine plus 踩進老街): those not played in the last
///    three days first, the rotation start moving a place every day of the
///    year; when too few are left, the ones played longest ago.
///
/// The plan has no greeting and no reasons. The gait rules only add missions
/// and say nothing about health.
///
/// [mobility] stands in for the grades worked out from [gaitHistory], for
/// callers (and tests) that already have them.
MissionPlan planByRules({
  required DateTime today,
  required GameActivityLog activity,
  required FootCheckRecord? lastFootCheck,
  Map<String, DailyGait>? gaitHistory,
  List<WeekMobility>? mobility,
}) {
  final picks = <String>[];
  void pick(String id) {
    if (picks.length < missionsPerDay && !picks.contains(id)) picks.add(id);
  }

  if (lastFootCheck == null ||
      calendarDaysBetween(lastFootCheck.takenAt, today) >= _recentDays) {
    pick(MissionCatalog.footCheck);
  }

  if (gaitHistory != null) {
    if (_stepsLow(gaitHistory, today)) pick('walkgroup');
    final weeks = mobility ?? gradeMobility(gaitHistory, today: today);
    if (_cadenceLow(weeks)) pick('rhythm');
  }

  final games = MissionCatalog.gameIds;
  final start = dayOfYear(today) % games.length;
  final rotated = [...games.skip(start), ...games.take(start)];
  bool playedLately(String id) {
    final last = activity.lastPlayed(id);
    return last != null && calendarDaysBetween(last, today) < _recentDays;
  }

  for (final id in rotated.where((id) => !playedLately(id))) {
    pick(id);
  }
  // Everything left was played lately: the one played longest ago first, the
  // rotation breaking ties (sort is not stable, so the index is in the key).
  final rest = [...rotated.where(playedLately)];
  final order = {for (var i = 0; i < rotated.length; i++) rotated[i]: i};
  rest.sort((a, b) {
    final byDay = activity.lastPlayed(a)!.compareTo(activity.lastPlayed(b)!);
    return byDay != 0 ? byDay : order[a]!.compareTo(order[b]!);
  });
  rest.forEach(pick);

  return MissionPlan(
    day: gaitDateKey(today),
    source: MissionPlanSource.rule,
    items: [for (final id in picks) MissionPlanItem(id)],
  );
}

/// G1: yesterday has data, at least [_minBaselineDays] of the seven days
/// before it do too, and yesterday's steps are under 0.7 times
/// their mean. Whole numbers all the way, so exactly 0.7 times does not count.
bool _stepsLow(Map<String, DailyGait> history, DateTime today) {
  DailyGait? on(int daysAgo) =>
      history[gaitDateKey(
        DateTime(today.year, today.month, today.day - daysAgo),
      )];
  final yesterday = on(1);
  if (yesterday == null || !yesterday.hasData) return false;
  var days = 0, total = 0;
  for (var back = 2; back <= 8; back++) {
    final day = on(back);
    if (day != null && day.hasData) {
      days++;
      total += day.steps;
    }
  }
  if (days < _minBaselineDays) return false;
  // steps < 0.7 × (total / days)
  return yesterday.steps * days * 10 < total * 7;
}

/// G2: the latest week that has a grade has its cadence graded D or E.
bool _cadenceLow(List<WeekMobility> weeks) {
  final latest = weeks.lastWhereOrNull((w) => w.grade != null);
  final grade = latest?.metrics[MobilityMetric.cadence]?.grade;
  return grade == MobilityGrade.d || grade == MobilityGrade.e;
}
