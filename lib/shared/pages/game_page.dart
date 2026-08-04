import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/game_entry.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// Games hub, classic theme.
///
/// Same content as the mascot version — today's mission, the village
/// shortcuts, then the game grid — but built from this theme's existing
/// vocabulary rather than a hand-rolled one: the mission rows copy
/// `DailyMissionsSheet`'s layout (fixed icon column, title + subtitle, a
/// stadium pill trailing) so the two mission surfaces line up, and color stays
/// on the three semantic roles the design system defines — primary for icons,
/// rewardGold for rewards and progress, success for completed.
///
/// Illustrations appear in two places only, and both are content rather than
/// chrome: the game covers and the village shortcuts.
///
/// Mission figures are mockup copy; nothing here is measured yet.
class GamePage extends StatelessWidget {
  const GamePage({super.key});

  static const _mockGameReward = 30;

  @override
  Widget build(BuildContext context) {
    final games = gameCatalog();

    return Scaffold(
      appBar: AppBar(
        title: Text('game'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.base,
            children: [
              const _MissionCard(),
              const _VillageRow(),
              Text('pick_a_game'.tr(), style: context.textTheme.titleMedium),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.base,
                  crossAxisSpacing: AppSpacing.base,
                  childAspectRatio: 0.78,
                ),
                itemCount: games.length,
                itemBuilder: (context, i) => _GameTile(entry: games[i]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Today's mission ───────────────────────────────────────────────────────

class _MissionCard extends StatelessWidget {
  const _MissionCard();

  @override
  Widget build(BuildContext context) {
    const steps = HomeBodyT2.mockSteps;
    const goal = HomeBodyT2.mockStepGoal;

    return SectionCard(
      title: 'today_mission'.tr(),
      trailing: _Pill(
        label: 'streak_days'.tr(args: ['${HomeBodyT2.mockStreakDays}']),
        color: context.tokens.rewardGold,
        icon: LucideIcons.flame,
      ),
      child: Column(
        children: [
          _MissionRow(
            icon: LucideIcons.footprints,
            title: 'mission_walk_title'.tr(args: ['$goal']),
            subtitle: 'steps_progress'.tr(args: ['$steps', '$goal']),
            progress: steps / goal,
            trailing: _Pill(
              label: 'mission_done'.tr(),
              color: context.tokens.success,
              icon: LucideIcons.check,
            ),
          ),
          const Divider(height: AppSpacing.xl),
          _MissionRow(
            icon: LucideIcons.gamepad2,
            title: 'mission_play_game'.tr(args: ['game_catch_fish'.tr()]),
            subtitle: 'mission_go'.tr(),
            trailing: _Pill(
              label: 'coin_reward'.tr(args: ['${GamePage._mockGameReward}']),
              color: context.tokens.rewardGold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors `DailyMissionsSheet`'s row: a fixed icon column keeps every row's
/// text on the same left edge no matter how wide the icon is.
class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Center(
            child: Icon(icon, size: 32, color: context.colorScheme.primary),
          ),
        ),
        const SizedBox(width: AppSpacing.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor:
                        context.colorScheme.surfaceContainerHighest,
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
        trailing,
      ],
    );
  }
}

/// Tinted stadium pill — the same treatment `DailyMissionsSheet` uses for its
/// "claimed" state, generalized so streak / reward / done all read as one
/// family instead of three different shapes.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Village shortcuts ─────────────────────────────────────────────────────

class _VillageRow extends StatelessWidget {
  const _VillageRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          child: _VillageCard(
            art: 'assets/mascot-assets/farm/ent_farm.webp',
            title: 'garden'.tr(),
            subtitle: 'garden_nutrient'.tr(args: ['4']),
          ),
        ),
        Expanded(
          child: _VillageCard(
            art: 'assets/mascot-assets/farm/ent_shop.webp',
            title: 'shop'.tr(),
            subtitle: 'shop_coins'.tr(args: ['1240']),
          ),
        ),
        Expanded(
          child: _VillageCard(
            art: 'assets/mascot-assets/farm/ent_mailbox.webp',
            title: 'family'.tr(),
            subtitle: 'family_cheers'.tr(args: ['2']),
          ),
        ),
      ],
    );
  }
}

class _VillageCard extends StatelessWidget {
  const _VillageCard({
    required this.art,
    required this.title,
    required this.subtitle,
  });

  final String art;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: comingSoon,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.base,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            children: [
              Image.asset(art, height: 52, fit: BoxFit.contain),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: context.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game tile ─────────────────────────────────────────────────────────────

/// Cover art runs edge to edge; the title strip sits on the card's surface
/// underneath it.
class _GameTile extends StatelessWidget {
  const _GameTile({required this.entry});

  final GameEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/game-webview',
          extra: {'url': entry.url, 'title': entry.nameKey.tr()},
        ),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                entry.art,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.nameKey.tr(),
                      style: context.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    LucideIcons.circlePlay,
                    size: 22,
                    color: context.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
