import 'dart:async';

import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/missions/ai_mission_client.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// An [AiMissionClient] that remembers what it was asked and answers with:
/// a plan when [answer] is set, "unreachable" when [unreachable] is true,
/// otherwise "refused" (the server replied without a plan). [fail] throws,
/// which a real client never does. When [gate] is set the answer waits for it,
/// to play a slow server.
class FakeAiMissionClient implements AiMissionClient {
  FakeAiMissionClient({
    this.answer,
    this.unreachable = false,
    this.fail = false,
    this.gate,
  });

  /// What the server "wrote" (the plan's `day` is filled in).
  MissionPlan? answer;
  bool unreachable;
  bool fail;
  Completer<void>? gate;

  final List<Map<String, Object?>> calls = [];

  @override
  Future<AiMissionResult> plan({
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
    await gate?.future;
    if (fail) throw Exception('the client broke');
    if (unreachable) return const AiMissionResult.unreachable();
    final a = answer;
    if (a == null) return const AiMissionResult.refused();
    return AiMissionResult.planned(
      MissionPlan(
        day: gaitDateKey(today),
        source: a.source,
        greeting: a.greeting,
        items: a.items,
      ),
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
