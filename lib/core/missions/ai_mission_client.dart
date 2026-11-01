import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/missions/rule_planner.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How long the app waits for the server before it keeps the rules' plan.
/// The server gives Claude 8 seconds of its own; this adds room for the
/// network on both sides.
const aiMissionsTimeout = Duration(seconds: 12);

/// Rounds from yesterday and distinct games from the week the server takes.
const _maxYesterdayRounds = 20;
const _maxWeekGames = 30;

/// How a request to the server ended.
enum AiMissionOutcome {
  /// The server wrote a plan.
  planned,

  /// The server answered but not with a plan: a `fallback` reply
  /// (`not_configured`, `failed`, `daily_cap`, `busy`, `error`) or something
  /// the app cannot read. Asking again the same day would get the same.
  refused,

  /// No answer: offline, too slow, or an HTTP error. Worth asking again the
  /// next time the sheet opens.
  unreachable,
}

/// The end of one request: [plan] is set exactly when [outcome] is
/// [AiMissionOutcome.planned].
class AiMissionResult {
  const AiMissionResult.planned(MissionPlan this.plan)
    : outcome = AiMissionOutcome.planned;
  const AiMissionResult.refused()
    : outcome = AiMissionOutcome.refused,
      plan = null;
  const AiMissionResult.unreachable()
    : outcome = AiMissionOutcome.unreachable,
      plan = null;

  final AiMissionOutcome outcome;
  final MissionPlan? plan;
}

/// Asks the server (and through it Claude) to write today's missions.
///
/// An interface so the sheet's tests can put a fake in its place; the real
/// one is [SupabaseAiMissionClient].
abstract class AiMissionClient {
  /// Today's plan as the server wrote it, or why there is none. Never throws.
  Future<AiMissionResult> plan({
    required DateTime today,
    required GameActivityLog activity,
    required FootCheckRecord? lastFootCheck,
    Map<String, DailyGait>? gaitHistory,
  });
}

/// The request body for `daily-missions`: exactly the fields the server
/// accepts and nothing else. Numbers and fixed words only — no name, no
/// device or account id, no text a person typed.
///
/// - `games_yesterday`: yesterday's rounds (slug, stage, seconds), at most 20.
/// - `games_7d`: how many times each game was played in the seven days before
///   today, at most 30 games.
/// - `foot_check_days_ago` and `foot_check_rating` of the last foot check.
/// - `gait`: only when [gaitHistory] is given (step tracking is on) — yesterday's
///   steps, cadence and walking minutes, and the latest graded week's
///   mobility grade. Left out when there is nothing in it.
Map<String, Object?> buildAiMissionBody({
  required DateTime today,
  required GameActivityLog activity,
  required FootCheckRecord? lastFootCheck,
  Map<String, DailyGait>? gaitHistory,
}) {
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  // What the app itself would accept from a game: a stored entry that does not
  // pass is not sent.
  bool valid(String slug, String? stage) =>
      GameActivity.tryParse({
        'slug': slug,
        'stage': ?stage,
        'seconds': 0,
      }, today) !=
      null;

  final rounds = [
    for (final a in activity.byDay[gaitDateKey(yesterday)] ?? const [])
      if (valid(a.slug, a.stage) && a.seconds >= 0 && a.seconds <= 10800)
        {'slug': a.slug, 'stage': ?a.stage, 'seconds': a.seconds},
  ];

  final from = gaitDateKey(DateTime(today.year, today.month, today.day - 7));
  final to = gaitDateKey(yesterday);
  final plays = <String, int>{};
  for (final e in activity.byDay.entries) {
    if (e.key.compareTo(from) < 0 || e.key.compareTo(to) > 0) continue;
    for (final a in e.value) {
      if (valid(a.slug, null)) plays[a.slug] = (plays[a.slug] ?? 0) + 1;
    }
  }
  final week = plays.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  final gait = gaitHistory == null
      ? null
      : _gaitStats(gaitHistory, today: today, yesterday: yesterday);

  return {
    'day': gaitDateKey(today),
    'stats': {
      'games_yesterday': rounds
          .skip(math.max(0, rounds.length - _maxYesterdayRounds))
          .toList(),
      'games_7d': [
        for (final e in week.take(_maxWeekGames))
          {'slug': e.key, 'plays': math.min(e.value, 200)},
      ],
      'foot_check_days_ago': lastFootCheck == null
          ? null
          : calendarDaysBetween(lastFootCheck.takenAt, today).clamp(0, 365),
      'foot_check_rating': lastFootCheck?.rating.name,
      'gait': ?gait,
    },
  };
}

Map<String, Object?>? _gaitStats(
  Map<String, DailyGait> history, {
  required DateTime today,
  required DateTime yesterday,
}) {
  final day = history[gaitDateKey(yesterday)];
  final has = day != null && day.hasData;
  double? round1(double? v, double max) =>
      v == null || !v.isFinite ? null : (v.clamp(0.0, max) * 10).round() / 10;
  final steps = has ? math.min(day.steps, 100000) : null;
  final cadence = has ? round1(day.cadence, 250) : null;
  final walkingMin = has ? round1(day.walkingMs / 60000, 1440) : null;
  final grade = gradeMobility(
    history,
    today: today,
  ).lastWhereOrNull((w) => w.grade != null)?.grade;
  if (steps == null && cadence == null && walkingMin == null && grade == null) {
    return null;
  }
  return {
    'steps': steps,
    'cadence': cadence,
    'walking_min': walkingMin,
    'mobility_grade': grade?.name,
  };
}

/// The server's answer as a plan for [day], or null unless it is `mode: "ai"`
/// with exactly [missionsPerDay] distinct missions this app knows, each with
/// a reason, and a greeting.
MissionPlan? parseAiMissionResponse(Object? data, {required String day}) {
  if (data is! Map || data['mode'] != 'ai') return null;
  final greeting = data['greeting'];
  final missions = data['missions'];
  if (greeting is! String || greeting.trim().isEmpty) return null;
  if (missions is! List || missions.length != missionsPerDay) return null;
  final items = <MissionPlanItem>[];
  for (final m in missions) {
    if (m is! Map) return null;
    final id = m['id'], reason = m['reason'];
    if (id is! String || !MissionCatalog.isKnown(id)) return null;
    if (reason is! String || reason.trim().isEmpty) return null;
    if (items.any((i) => i.id == id)) return null;
    items.add(MissionPlanItem(id, reason: reason.trim()));
  }
  return MissionPlan(
    day: day,
    source: MissionPlanSource.ai,
    greeting: greeting.trim(),
    items: items,
  );
}

/// Sends one request: the body in, the server's JSON out. Throws for anything
/// that is not a 2xx answer. Injectable for tests.
typedef AiMissionInvoke = Future<Object?> Function(Map<String, Object?> body);

Future<Object?> _invokeSupabase(Map<String, Object?> body) async {
  // Any non-2xx answer arrives as a FunctionException.
  final res = await Supabase.instance.client.functions.invoke(
    'daily-missions',
    body: body,
  );
  return res.data;
}

/// Calls the `daily-missions` Edge Function with the signed-in wearer's token.
class SupabaseAiMissionClient implements AiMissionClient {
  const SupabaseAiMissionClient({AiMissionInvoke? invoke})
    : _invoke = invoke ?? _invokeSupabase;

  final AiMissionInvoke _invoke;

  @override
  Future<AiMissionResult> plan({
    required DateTime today,
    required GameActivityLog activity,
    required FootCheckRecord? lastFootCheck,
    Map<String, DailyGait>? gaitHistory,
  }) async {
    final Object? data;
    try {
      final body = buildAiMissionBody(
        today: today,
        activity: activity,
        lastFootCheck: lastFootCheck,
        gaitHistory: gaitHistory,
      );
      data = await _invoke(body).timeout(aiMissionsTimeout);
    } catch (_) {
      // Signed out, offline, too slow or a non-2xx answer: no reply to go by.
      return const AiMissionResult.unreachable();
    }
    final plan = parseAiMissionResponse(data, day: gaitDateKey(today));
    return plan == null
        ? const AiMissionResult.refused()
        : AiMissionResult.planned(plan);
  }
}
