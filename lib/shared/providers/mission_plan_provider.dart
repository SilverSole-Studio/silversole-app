import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/missions/rule_planner.dart';
import 'package:silversole/shared/providers/ai_missions_provider.dart';
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
/// With `AI_MISSIONS` on ([aiMissionsEnabledProvider]) and the wearer's
/// consent ([aiMissionsConsentProvider] is yes), the plan is asked of the
/// server first ([aiMissionClientProvider]): a plan it wrote (`source: ai`)
/// is saved and kept like any other. When it cannot write one, the rules'
/// plan stands and the day is marked, so that day is not asked again. A
/// change of consent makes the plan again: yes asks for an AI plan, no puts
/// an AI plan back to the rules' (a rules plan already made that day is kept).
/// With the flag off none of this runs and the client is never touched.
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
    final todayKey = gaitDateKey(today);
    // Everything that is watched or read from the providers comes before the
    // first await, so a change in any of them makes this plan again.
    final aiEnabled = ref.watch(aiMissionsEnabledProvider);
    final consentFuture = aiEnabled
        ? ref.watch(aiMissionsConsentProvider.future)
        : null;
    final realGait = ref.read(realGaitEnabledProvider);
    final client = aiEnabled ? ref.read(aiMissionClientProvider) : null;

    final wantAi = aiEnabled && await consentFuture! == AiMissionsConsent.yes;

    final decoded = MissionPlan.tryDecode(
      await _tryLoad(LocalSavableKey.dailyMissionPlan),
    );
    final saved =
        decoded != null &&
            decoded.day == todayKey &&
            decoded.items.length >= missionsPerDay
        ? decoded
        : null;
    if (saved != null) {
      final isAi = saved.source == MissionPlanSource.ai;
      if (isAi == wantAi) return saved;
      // A rules plan with AI wanted: keep it if the server already failed
      // today, otherwise ask. An AI plan with AI not wanted: made again below.
      if (wantAi &&
          await _tryLoad(LocalSavableKey.aiMissionsFailedDay) == todayKey) {
        return saved;
      }
    }

    final activity = GameActivityLog.decode(
      await _tryLoad(LocalSavableKey.gameActivity),
      today: today,
    );
    final lastFootCheck = FootCheckRecord.tryDecode(
      await _tryLoad(LocalSavableKey.lastFootCheck),
    );
    final gait = realGait
        ? decodeGaitHistory(await _tryLoad(LocalSavableKey.gaitHistory))
        : null;

    var plan = saved != null && saved.source == MissionPlanSource.rule
        ? saved
        : planByRules(
            today: today,
            activity: activity,
            lastFootCheck: lastFootCheck,
            gaitHistory: gait,
          );
    if (wantAi) {
      MissionPlan? written;
      try {
        written = await client!.plan(
          today: today,
          activity: activity,
          lastFootCheck: lastFootCheck,
          gaitHistory: gait,
        );
      } catch (_) {
        written = null;
      }
      // Asked again by a newer build (the consent changed meanwhile): this
      // answer is stale and must not be saved over it.
      if (!ref.mounted) return plan;
      if (written != null && written.day == todayKey) {
        plan = written;
      } else {
        await _trySave(LocalSavableKey.aiMissionsFailedDay, todayKey);
      }
    }
    if (!ref.mounted) return plan;
    await _trySave(LocalSavableKey.dailyMissionPlan, plan.encode());
    return plan;
  }
}

/// Saves, ignoring a phone that cannot: the plan is still the one shown.
Future<void> _trySave(LocalSavableKey key, String value) async {
  try {
    await saveLocalValue(key, value);
  } catch (_) {
    // Not saved.
  }
}

final todayMissionPlanProvider =
    AsyncNotifierProvider.autoDispose<TodayMissionPlanNotifier, MissionPlan>(
      TodayMissionPlanNotifier.new,
    );
