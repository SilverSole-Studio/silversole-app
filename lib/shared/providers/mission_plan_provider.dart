import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';
import 'package:silversole/core/missions/ai_mission_client.dart';
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
/// consent ([aiMissionsConsentProvider] is yes), the rules' plan is made, saved
/// and returned at once — the sheet never waits on the server — and the server
/// ([aiMissionClientProvider]) is asked in the background. A plan it writes
/// (`source: ai`) replaces today's plan when it arrives, provided nothing has
/// changed meanwhile (the consent, the sheet). When the server answers without
/// a plan the day is marked and not asked again; when it cannot be reached
/// (offline, too slow) nothing is marked and the next opening asks again.
///
/// A change of consent makes the plan again: yes asks for an AI plan, no puts
/// an AI plan back to the rules' (a rules plan already made that day is kept).
/// Every build takes a new generation number, and a background answer from an
/// older one is dropped without saving anything, so a slow answer can never
/// land after the wearer switched AI off. With the flag off none of this runs
/// and the client is never touched.
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
  /// Bumped by every [build]. `ref.mounted` does not turn false when the
  /// notifier is rebuilt, so this is what tells an old build's background work
  /// that it has been replaced.
  int _generation = 0;

  bool _current(int generation) => ref.mounted && generation == _generation;

  @override
  Future<MissionPlan> build() async {
    final generation = ++_generation;
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
      // A rules plan with AI wanted: keep it if the server already refused
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

    final rules = saved != null && saved.source == MissionPlanSource.rule
        ? saved
        : planByRules(
            today: today,
            activity: activity,
            lastFootCheck: lastFootCheck,
            gaitHistory: gait,
          );
    // A newer build owns the plan now: do not save over it.
    if (!_current(generation)) return rules;
    if (!identical(rules, saved)) {
      await _trySave(LocalSavableKey.dailyMissionPlan, rules.encode());
    }
    if (wantAi && _current(generation)) {
      unawaited(
        _askServer(
          generation,
          client!,
          today: today,
          activity: activity,
          lastFootCheck: lastFootCheck,
          gait: gait,
        ),
      );
    }
    return rules;
  }

  /// Asks for an AI plan after the rules' plan is already showing, and swaps it
  /// in if the answer is a plan and this is still the current build.
  Future<void> _askServer(
    int generation,
    AiMissionClient client, {
    required DateTime today,
    required GameActivityLog activity,
    required FootCheckRecord? lastFootCheck,
    required Map<String, DailyGait>? gait,
  }) async {
    AiMissionResult result;
    try {
      result = await client.plan(
        today: today,
        activity: activity,
        lastFootCheck: lastFootCheck,
        gaitHistory: gait,
      );
    } catch (_) {
      result = const AiMissionResult.unreachable();
    }
    final todayKey = gaitDateKey(today);
    // Replaced by a newer build or closed meanwhile (the consent changed, the
    // sheet went away): this answer is stale, so nothing is saved or marked.
    if (!_current(generation)) return;
    if (ref.read(aiMissionsConsentProvider).value != AiMissionsConsent.yes) {
      return;
    }

    final plan = result.plan;
    if (plan != null && plan.day == todayKey) {
      await _trySave(LocalSavableKey.dailyMissionPlan, plan.encode());
      if (_current(generation)) state = AsyncData(plan);
    } else if (result.outcome != AiMissionOutcome.unreachable) {
      await _trySave(LocalSavableKey.aiMissionsFailedDay, todayKey);
    }
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
