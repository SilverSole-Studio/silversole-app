import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

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

/// A single daily mission. There is no mission backend: a mission is only
/// marked done when the app itself knows it happened.
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

  /// Already finished + claimed → shows the "claimed" pill instead of a button.
  final bool completed;

  /// Tapped from the gray "go" button on an incomplete mission. Null when
  /// [completed].
  final VoidCallback? onGo;
}

/// Bottom-sheet body listing today's missions. Incomplete missions show a gray
/// "go" button that routes to where the mission is done (no reward amount —
/// there are no rewards); completed ones show a "done" pill.
///
/// Only missions that lead somewhere real are listed. There is no walking
/// mission: the app has no pedometer, so it could only show made-up progress.
/// The foot-pressure mission is done once a foot check finished today
/// ([lastFootCheckProvider]); the balance game reports nothing back, so that
/// one always offers "go".
class DailyMissionsSheet extends ConsumerWidget {
  const DailyMissionsSheet({super.key});

  List<_Mission> _missions(BuildContext context, {required bool measured}) => [
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
      subtitle: measured
          ? 'mission_done'.tr()
          : 'mission_measure_subtitle'.tr(),
      completed: measured,
      onGo: measured
          ? null
          : () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push('/foot-check');
            },
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measured =
        ref.watch(lastFootCheckProvider)?.isOnDay(DateTime.now()) ?? false;
    final missions = _missions(context, measured: measured);
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
