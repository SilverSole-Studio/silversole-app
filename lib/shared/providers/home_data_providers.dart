import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/diamonds/diamond_repository.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/missions/rule_planner.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/providers/diamonds_provider.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

/// What the "today" screens of every look show about the wearer's day. The
/// pages differ in how they draw it; the numbers are the same, and every one is
/// a real figure from the phone or the sole (nothing is made up to fill a
/// layout).

/// Minutes of insole exercise today, and the goal that earns the day's
/// diamonds ([DiamondRules.minMinutes]).
class ExerciseToday {
  const ExerciseToday({required this.minutes});

  final int minutes;

  int get goal => DiamondRules.minMinutes;

  /// Minutes still to go; 0 once reached.
  int get remaining => (goal - minutes).clamp(0, goal);

  bool get reached => minutes >= goal;

  /// 0..1 for a bar.
  double get fraction => (minutes / goal).clamp(0.0, 1.0);
}

final exerciseTodayProvider = Provider<ExerciseToday>(
  (ref) => ExerciseToday(
    minutes: ref.watch(
      diamondsProvider.select((s) => s.exercise?.minutes ?? 0),
    ),
  ),
);

/// The primary sole as the home screen reports it: paired or not, online, and
/// its battery (live while online, otherwise the last level it reported).
class SoleStatus {
  const SoleStatus({
    required this.device,
    required this.online,
    required this.battery,
  });

  final BlePairedDevice? device;
  final bool online;
  final BatteryDisplay battery;

  bool get paired => device != null;
}

final soleStatusProvider = Provider<SoleStatus>((ref) {
  final device = ref.watch(settingsProvider.select((s) => s.preferredDevice));
  // Value unused on purpose: checkDeviceOnline compares against the clock and
  // nothing rebuilds when a sole goes silent; watching this provider is what
  // re-runs this when its timer fires.
  ref.watch(deviceOnlineProvider);
  if (device == null) {
    return SoleStatus(
      device: null,
      online: false,
      battery: BatteryDisplay.resolve(),
    );
  }
  final telemetry = ref.watch(liveTelemetryProvider(device.identityKey));
  final online = ref
      .watch(telemetryFacadeProvider)
      .checkDeviceOnline(telemetry.updatedAt);
  final recent = telemetry.recentImu;
  return SoleStatus(
    device: device,
    online: online,
    battery: BatteryDisplay.resolve(
      live: online && recent.isNotEmpty ? recent.last.batteryPercent : null,
      lastKnown: device.lastBatteryPercent,
    ),
  );
});

/// One of today's missions, as a line to show.
class MissionLine {
  const MissionLine({required this.id, required this.done});

  final String id;
  final bool done;

  /// Translation key of its title.
  String get titleKey => MissionCatalog.titleKey(id);
}

/// Today's missions with their done state, or null while the plan is still
/// being made. The same plan the missions sheet shows.
final todayMissionLinesProvider = Provider<List<MissionLine>?>((ref) {
  final footCheck = ref.watch(lastFootCheckProvider);
  final activity = ref.watch(gameActivityProvider);
  final saved = ref.watch(todayMissionPlanProvider);
  final today = clock.now();
  // The plan only fails to load if something unexpected broke: the rules' pick
  // for today beats a spinner that never ends.
  final MissionPlan? plan =
      saved.value ??
      (saved.hasError
          ? planByRules(
              today: today,
              activity: activity,
              lastFootCheck: footCheck,
            )
          : null);
  if (plan == null) return null;
  return [
    for (final item in plan.items)
      MissionLine(
        id: item.id,
        done: MissionCatalog.isCompleted(
          item.id,
          today: today,
          activity: activity,
          lastFootCheck: footCheck,
        ),
      ),
  ];
});
