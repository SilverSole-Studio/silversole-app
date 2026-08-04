import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/game_entry.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// Games hub, classic theme.
///
/// Same information as the mascot version — today's mission, then the game
/// grid — dressed in the blue design system: white cards, hairline borders,
/// Lucide icons, no character art in the chrome.
///
/// The one deliberate exception is the game covers: those use the mascot
/// pack's illustrations full-bleed, because cover art is content rather than
/// theming and the tiles would be lifeless without it.
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

class _MissionCard extends StatelessWidget {
  const _MissionCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'today_mission'.tr(),
      trailing: Chip(
        avatar: Icon(
          LucideIcons.flame,
          size: 16,
          color: context.tokens.dataOrange,
        ),
        label: Text('streak_days'.tr(args: ['${HomeBodyT2.mockStreakDays}'])),
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        spacing: AppSpacing.sm,
        children: [
          _MissionRow(
            icon: LucideIcons.footprints,
            label: 'mission_walk_steps'.tr(
              args: ['${HomeBodyT2.mockStepGoal}', '${HomeBodyT2.mockSteps}'],
            ),
            trailing: Icon(
              LucideIcons.circleCheck,
              color: context.tokens.success,
              size: 22,
            ),
          ),
          _MissionRow(
            icon: LucideIcons.gamepad2,
            label: 'mission_play_game'.tr(args: ['game_catch_fish'.tr()]),
            trailing: Text(
              'coin_reward'.tr(args: ['${GamePage._mockGameReward}']),
              style: context.textTheme.labelLarge?.copyWith(
                color: context.tokens.rewardGold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.sm,
      children: [
        Icon(icon, size: 20, color: context.colorScheme.onSurfaceVariant),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing,
      ],
    );
  }
}

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
