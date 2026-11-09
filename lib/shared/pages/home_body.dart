import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/home_data_providers.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/app_card.dart';
import 'package:silversole/shared/widgets/foot_health_check_card.dart'
    show lastFootCheckDate;
import 'package:silversole/shared/widgets/home_hello.dart';
import 'package:silversole/shared/widgets/recent_data_chart_card.dart';

/// 今天 in the two 極簡科技 looks (白 and 黑, the same layout).
///
/// One order of weight: the foot check is the [CardWeight.hero] card with its
/// verdict in big type and the page's only button; today's exercise is a
/// standard card whose number is the big thing; the insole and the missions are
/// one quiet line each. Every explanation is one line.
///
/// Every figure is a real one (a check ends on a band, never a score). Fall
/// detection lives on the map tab; the raw IMU traces only show in developer
/// mode.
class HomeBody extends ConsumerWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hello = homeHello(context, ref);
    final devMode = ref.watch(
      settingsProvider.select((s) => s.firmwareDevMode),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.lg,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hello.date,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hello.hello,
                style: context.textTheme.headlineLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FootCheckHero(),
              const SizedBox(height: AppSpacing.base),
              const _ExerciseCard(),
              const SizedBox(height: AppSpacing.base),
              const _InsoleRow(),
              const SizedBox(height: AppSpacing.md),
              const _MissionRow(),
              // The raw IMU traces (twelve channel names) are an engineering
              // view: only with developer mode on (seven taps on the firmware
              // title).
              if (devMode) ...[
                const SizedBox(height: AppSpacing.base),
                RecentDataChartCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The one-minute foot check: the last verdict as the big figure, three
/// segments for its level, and the page's single button.
class _FootCheckHero extends ConsumerWidget {
  const _FootCheckHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFootCheckProvider);
    final scheme = context.colorScheme;

    return AppCard(
      weight: CardWeight.hero,
      padding: const EdgeInsets.all(AppSpacing.xl - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'foot_check_title'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            last == null
                ? 'foot_check_none_yet'.tr()
                : last.rating.labelKey.tr(),
            style: context.look
                .number(last == null ? 30 : 56, color: scheme.onSurface)
                .copyWith(height: 1.1),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            spacing: 6,
            children: [
              for (var i = 1; i <= FootCheckRating.values.length; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: last != null && i <= last.rating.level
                          ? scheme.primary
                          : scheme.outlineVariant,
                      borderRadius: AppRadius.pillR,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            last == null
                ? 'foot_check_none_yet_hint'.tr()
                : 'foot_health_check_last'.tr(
                    args: [lastFootCheckDate(context, last)],
                  ),
            style: context.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xl - 4),
          FilledButton.icon(
            onPressed: () => context.push('/foot-check'),
            icon: const Icon(LucideIcons.play),
            label: Text('start_check'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Today's insole exercise: minutes as the big figure against the day's goal.
class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(exerciseTodayProvider);
    final scheme = context.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'today_exercise'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${today.minutes}',
                style: context.look.number(56, color: scheme.onSurface),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'exercise_goal_unit'.tr(args: ['${today.goal}']),
                style: context.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.pillR,
            child: LinearProgressIndicator(
              value: today.fraction,
              minHeight: 10,
              backgroundColor: scheme.outlineVariant,
              color: today.reached ? context.tokens.success : scheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            today.reached
                ? 'exercise_reached'.tr()
                : 'exercise_remaining'.tr(args: ['${today.remaining}']),
            style: context.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// One quiet line for the insole: its state and battery.
class _InsoleRow extends ConsumerWidget {
  const _InsoleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(soleStatusProvider);
    final scheme = context.colorScheme;
    final level = status.battery.percent;

    return AppCard(
      weight: CardWeight.quiet,
      onTap: () => context.push('/my-devices'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(LucideIcons.footprints, size: 24, color: scheme.onSurface),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_insole_title'.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                  Text(
                    !status.paired
                        ? 'device_tap_to_pair'.tr()
                        : status.online
                        ? 'device_synced'.tr()
                        : 'offline'.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: status.online
                          ? context.tokens.success
                          : scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (level != null)
              Text(
                '$level%',
                style: context.look.number(
                  28,
                  color: status.battery.isLive
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              LucideIcons.chevronRight,
              size: 24,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// One quiet line for today's missions: how many are left.
class _MissionRow extends ConsumerWidget {
  const _MissionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(todayMissionLinesProvider);
    final scheme = context.colorScheme;
    final left = lines?.where((m) => !m.done).length;

    return AppCard(
      weight: CardWeight.quiet,
      onTap: () => showDailyMissionsBottomSheet(context),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(LucideIcons.target, size: 24, color: scheme.onSurface),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'today_mission'.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                  Text(
                    left == null
                        ? 'mission_cta'.tr()
                        : 'daily_missions_subtitle'.tr(args: ['$left']),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 24,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
