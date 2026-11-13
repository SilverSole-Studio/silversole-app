import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/missions/rule_planner.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';

/// What `callHandler('dailyMissions')` answers: `{day, missions: [{id, title,
/// done}]}` for today. Read only, and nothing in it is personal: ids and
/// titles come from [MissionCatalog], `done` from what the app recorded.
///
/// [plan] null (no plan could be made) gives an empty `missions` list.
/// [titleOf] turns a mission id into the wording the daily-missions sheet
/// shows.
Map<String, Object> dailyMissionsPayload({
  required MissionPlan? plan,
  required DateTime today,
  required GameActivityLog activity,
  required FootCheckRecord? lastFootCheck,
  required String Function(String id) titleOf,
}) => {
  'day': gaitDateKey(today),
  'missions': [
    for (final item in plan?.items ?? const <MissionPlanItem>[])
      {
        'id': item.id,
        'title': titleOf(item.id),
        'done': MissionCatalog.isCompleted(
          item.id,
          today: today,
          activity: activity,
          lastFootCheck: lastFootCheck,
        ),
      },
  ],
};

/// The answer for `dailyMissions`: today's plan from [todayMissionPlanProvider]
/// (the same one the sheet uses, made the same way when there is none yet),
/// or the rules' pick when that cannot be loaded, exactly as the sheet does.
Future<Map<String, Object>> dailyMissionsAnswer(WidgetRef ref) async {
  final today = clock.now();
  final footCheck = ref.read(lastFootCheckProvider);
  final activity = ref.read(gameActivityProvider);
  // autoDispose: keep it alive while waiting for the plan.
  final sub = ref.listenManual(todayMissionPlanProvider, (_, _) {});
  MissionPlan? plan;
  try {
    plan = await ref.read(todayMissionPlanProvider.future);
  } catch (_) {
    plan = planByRules(
      today: today,
      activity: activity,
      lastFootCheck: footCheck,
    );
  } finally {
    sub.close();
  }
  return dailyMissionsPayload(
    plan: plan,
    today: today,
    activity: ref.read(gameActivityProvider),
    lastFootCheck: ref.read(lastFootCheckProvider),
    titleOf: (id) => MissionCatalog.titleKey(id).tr(),
  );
}
