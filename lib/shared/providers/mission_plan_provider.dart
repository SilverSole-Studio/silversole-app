import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/missions/rule_planner.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// [loadLocalValue], or null when the phone's storage cannot be read: the
/// plan is then made from what is left rather than not at all.
Future<String?> _tryLoad(LocalSavableKey key) async {
  try {
    return await loadLocalValue(key);
  } catch (_) {
    return null;
  }
}

/// Today's missions: the plan saved for today, or — the first time the sheet
/// opens that day — one made by [planByRules] and saved.
///
/// The inputs are read from what is stored on the phone rather than from the
/// providers, which fill in after launch: a plan made from a half-loaded
/// record would think the wearer never played or never checked, and then stay
/// that way all day.
///
/// Storage that cannot be read or written never leaves the sheet without
/// missions: unreadable parts count as empty, and a plan that could not be
/// saved is still returned (the next opening makes it again).
///
/// A saved plan with fewer than [missionsPerDay] missions the app still knows
/// (the catalog changed since) is made again.
///
/// Disposed with the sheet, so the next opening reads the clock again.
class TodayMissionPlanNotifier extends AsyncNotifier<MissionPlan> {
  @override
  Future<MissionPlan> build() async {
    final today = clock.now();
    final saved = MissionPlan.tryDecode(
      await _tryLoad(LocalSavableKey.dailyMissionPlan),
    );
    if (saved != null &&
        saved.day == gaitDateKey(today) &&
        saved.items.length >= missionsPerDay) {
      return saved;
    }

    final activity = GameActivityLog.decode(
      await _tryLoad(LocalSavableKey.gameActivity),
      today: today,
    );
    final lastFootCheck = FootCheckRecord.tryDecode(
      await _tryLoad(LocalSavableKey.lastFootCheck),
    );
    final gait = ref.read(realGaitEnabledProvider)
        ? decodeGaitHistory(await _tryLoad(LocalSavableKey.gaitHistory))
        : null;
    final plan = planByRules(
      today: today,
      activity: activity,
      lastFootCheck: lastFootCheck,
      gaitHistory: gait,
    );
    try {
      await saveLocalValue(LocalSavableKey.dailyMissionPlan, plan.encode());
    } catch (_) {
      // Not saved: this plan is still the one shown.
    }
    return plan;
  }
}

final todayMissionPlanProvider =
    AsyncNotifierProvider.autoDispose<TodayMissionPlanNotifier, MissionPlan>(
      TodayMissionPlanNotifier.new,
    );
