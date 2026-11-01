import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/missions/mission_catalog.dart';
import 'package:silversole/core/missions/mission_plan.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/mission_plan_provider.dart';

/// Opens the "daily missions" sheet (the home FAB's mission action).
Future<void> showDailyMissionsBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const DailyMissionsSheet(),
  );
}

/// A single daily mission, as the sheet draws it.
class _Mission {
  const _Mission({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.completed = false,
    this.onGo,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Already done → shows the "done" pill instead of a button.
  final bool completed;

  /// Tapped from the gray "go" button on an incomplete mission. Null when
  /// [completed].
  final VoidCallback? onGo;
}

/// The icon of each mission in [MissionCatalog].
const _missionIcons = <String, IconData>{
  MissionCatalog.footCheck: LucideIcons.scanLine,
  'walkgroup': LucideIcons.users,
  'bike': LucideIcons.bike,
  'canoe': LucideIcons.ship,
  'fish': LucideIcons.fish,
  'ski': LucideIcons.snowflake,
  'hop': LucideIcons.footprints,
  'rhythm': LucideIcons.music,
  'quiz': LucideIcons.circleQuestionMark,
  'pool': LucideIcons.circleDot,
  MissionCatalog.laojie: LucideIcons.landmark,
};

/// Bottom-sheet body listing today's missions. Incomplete missions show a gray
/// "go" button that routes to where the mission is done (no reward amount —
/// there are no rewards); completed ones show a "done" pill.
///
/// Which missions are listed is today's [MissionPlan]
/// ([todayMissionPlanProvider]): picked from the wearer's own record the first
/// time the sheet opens that day, then kept. A mission is done only when the
/// app itself recorded it: a foot check finished today ([lastFootCheckProvider])
/// or a round of that very game the game page reported today
/// ([gameActivityProvider]). There is no walking mission here: the app has no
/// pedometer of its own to count it with.
class DailyMissionsSheet extends ConsumerWidget {
  const DailyMissionsSheet({super.key});

  _Mission _mission(
    BuildContext context,
    MissionPlanItem item, {
    required DateTime today,
    required bool done,
  }) {
    final id = item.id;
    final isCheck = id == MissionCatalog.footCheck;
    final title = MissionCatalog.titleKey(id).tr();
    return _Mission(
      icon: _missionIcons[id] ?? LucideIcons.circle,
      title: title,
      subtitle:
          item.reason ??
          (done
              ? 'mission_done'.tr()
              : (isCheck
                    ? 'mission_measure_subtitle'.tr()
                    : 'mission_game_subtitle'.tr())),
      completed: done,
      onGo: done
          ? null
          : () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              if (isCheck) {
                router.push('/foot-check');
              } else {
                router.push(
                  '/game-webview',
                  extra: {
                    'url':
                        '${Constants.gameUrl}${MissionCatalog.gamePath(id, today)}',
                    'title': title,
                  },
                );
              }
            },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(todayMissionPlanProvider).value;
    final footCheck = ref.watch(lastFootCheckProvider);
    final activity = ref.watch(gameActivityProvider);
    final today = clock.now();
    final missions = [
      for (final item in plan?.items ?? const <MissionPlanItem>[])
        _mission(
          context,
          item,
          today: today,
          done: MissionCatalog.isCompleted(
            item.id,
            today: today,
            activity: activity,
            lastFootCheck: footCheck,
          ),
        ),
    ];
    final remaining = missions.where((m) => !m.completed).length;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'daily_missions_title'.tr(),
                style: context.textTheme.displaySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (plan != null)
                Text(
                  'daily_missions_subtitle'.tr(args: ['$remaining']),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              if (plan == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              for (var i = 0; i < missions.length; i++) ...[
                if (i > 0) const Divider(height: AppSpacing.xl),
                _MissionRow(mission: missions[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission});

  final _Mission mission;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Center(
            child: Icon(
              mission.icon,
              size: 32,
              color: context.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mission.title, style: context.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                mission.subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _Trailing(mission: mission),
      ],
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({required this.mission});

  final _Mission mission;

  @override
  Widget build(BuildContext context) {
    if (mission.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: ShapeDecoration(
          color: context.tokens.success.withValues(alpha: 0.14),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'mission_done'.tr(),
              style: context.textTheme.labelLarge?.copyWith(
                color: context.tokens.success,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(LucideIcons.check, size: 16, color: context.tokens.success),
          ],
        ),
      );
    }

    // Incomplete: a neutral gray "go" button (no reward amount) that routes to
    // where the mission is completed.
    return FilledButton(
      onPressed: mission.onGo,
      style: FilledButton.styleFrom(
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        foregroundColor: context.colorScheme.onSurface,
        elevation: 0,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        textStyle: context.textTheme.labelLarge,
        shape: AppRadius.pillShape,
      ),
      child: Text('mission_go'.tr()),
    );
  }
}
