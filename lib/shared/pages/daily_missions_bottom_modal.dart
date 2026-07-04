import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

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

/// A single daily mission (static placeholder — no mission backend yet).
class _Mission {
  const _Mission({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.progress,
    this.completed = false,
    this.onGo,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// 0..1 progress bar shown under the subtitle, or null for none.
  final double? progress;

  /// Already finished + claimed → shows the "claimed" pill instead of a button.
  final bool completed;

  /// Tapped from the gray "go" button on an incomplete mission. Null when
  /// [completed].
  final VoidCallback? onGo;
}

/// Bottom-sheet body listing today's missions. Incomplete missions show a gray
/// "go" button that routes to where the mission is done (instead of a reward
/// amount); completed ones show a "claimed" pill.
class DailyMissionsSheet extends StatelessWidget {
  const DailyMissionsSheet({super.key});

  // Static placeholder figures (mirrors the foot-health card's step count).
  static const String _steps = '4,210';
  static const String _stepGoal = '5,000';

  List<_Mission> _missions(BuildContext context) => [
    _Mission(
      icon: LucideIcons.footprints,
      title: 'mission_walk_title'.tr(args: [_stepGoal]),
      subtitle: '$_steps / $_stepGoal',
      progress: 4210 / 5000,
      // No dedicated steps page yet — placeholder.
      onGo: () {
        Navigator.of(context).pop();
        comingSoon();
      },
    ),
    _Mission(
      icon: LucideIcons.scale,
      title: 'mission_balance_title'.tr(),
      subtitle: 'mission_balance_subtitle'.tr(),
      // Done by playing the balance game → open it in the webview.
      onGo: () {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(
          '/game-webview',
          extra: {
            'url': 'https://h5.silversole.dongyu.company/',
            'title': 'mission_balance_game'.tr(),
          },
        );
      },
    ),
    _Mission(
      icon: LucideIcons.scanLine,
      title: 'mission_measure_title'.tr(),
      subtitle: 'mission_done'.tr(),
      completed: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final missions = _missions(context);
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
              Text(
                'daily_missions_subtitle'.tr(args: ['$remaining']),
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (var i = 0; i < missions.length; i++) ...[
                if (i > 0) const Divider(height: AppSpacing.xl),
                _MissionRow(mission: missions[i]),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                'daily_missions_footer'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
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
              if (mission.progress != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: mission.progress,
                    minHeight: 6,
                    backgroundColor: context.colorScheme.surfaceContainerHighest,
                    // Reward gold: missions are a rewards feature (DESIGN.md
                    // reserves gold for rewards/points).
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.tokens.rewardGold,
                    ),
                  ),
                ),
              ],
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
              'mission_claimed'.tr(),
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
