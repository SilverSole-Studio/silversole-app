import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/missions/ai_mission_client.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// An [AiMissionClient] that answers with [answer] and remembers what it was
/// asked. [answer] null means "the server could not write one".
class FakeAiMissionClient implements AiMissionClient {
  FakeAiMissionClient({this.answer, this.fail = false});

  /// What the server "wrote" for a given day (the plan's `day` is filled in).
  MissionPlan? answer;

  /// Throws instead of answering, which a real client never does.
  bool fail;

  final List<Map<String, Object?>> calls = [];

  @override
  Future<MissionPlan?> plan({
    required DateTime today,
    required GameActivityLog activity,
    required FootCheckRecord? lastFootCheck,
    Map<String, DailyGait>? gaitHistory,
  }) async {
    calls.add({
      'today': today,
      'gaitHistory': gaitHistory,
      'lastFootCheck': lastFootCheck,
    });
    if (fail) throw Exception('the client broke');
    final a = answer;
    if (a == null) return null;
    return MissionPlan(
      day: gaitDateKey(today),
      source: a.source,
      greeting: a.greeting,
      items: a.items,
    );
  }
}

/// A plan the way the server writes it: a greeting and a reason for each of
/// three missions.
MissionPlan aiPlanFixture() => const MissionPlan(
  day: '',
  source: MissionPlanSource.ai,
  greeting: 'Good morning! A gentle day today.',
  items: [
    MissionPlanItem('fish', reason: 'Easy and fun to start with'),
    MissionPlanItem('foot_check', reason: 'It has been a few days'),
    MissionPlanItem('laojie', reason: 'A stroll through the old street'),
  ],
);
