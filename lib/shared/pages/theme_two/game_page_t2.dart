import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/game_entry.dart';
import 'package:silversole/shared/models/shop_view_data.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Games hub, mascot theme: today's mission, the village shortcuts, and the
/// game grid. Tapping a game opens the existing HTML5 web view.
///
/// Every figure here (steps, streak, coins, nutrients, cheers) is mockup
/// copy — none of it is measured or stored yet.
class GamePageT2 extends StatelessWidget {
  const GamePageT2({super.key});

  // Coins come from MockShop so the hub and the shop agree.
  static const _mockNutrient = 4;
  static const _mockCheers = 2;
  static const _mockGameReward = 30;

  @override
  Widget build(BuildContext context) {
    final games = gameCatalog();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'games_hub_title'.tr(),
                style: context.textTheme.headlineLarge,
              ),
              const SizedBox(height: 14),
              const _MissionCard(),
              const SizedBox(height: 14),
              const _VillageRow(),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppPaletteT2.gold,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppPaletteT2.ink, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'pick_a_game'.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
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
    return MascotCard(
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/mascot-assets/icons/home_play.webp',
                height: 34,
              ),
              const SizedBox(width: 8),
              Text('today_mission'.tr(), style: context.textTheme.titleMedium),
              const Spacer(),
              MascotPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      'streak_days'.tr(args: ['${HomeBodyT2.mockStreakDays}']),
                      style: context.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MissionRow(
            icon: 'assets/mascot-assets/icons/nav_analysis.webp',
            label: 'mission_walk_steps'.tr(
              args: ['${HomeBodyT2.mockStepGoal}', '${HomeBodyT2.mockSteps}'],
            ),
            trailing: const Icon(
              Icons.check_circle,
              color: AppPaletteT2.safe,
              size: 26,
            ),
          ),
          const SizedBox(height: 10),
          _MissionRow(
            icon: 'assets/mascot-assets/cards/card_fish.webp',
            label: 'mission_play_game'.tr(args: ['game_catch_fish'.tr()]),
            trailing: MascotPill(
              child: Text(
                'coin_reward'.tr(args: ['${GamePageT2._mockGameReward}']),
                style: context.textTheme.labelLarge,
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

  final String icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(icon, height: 32, width: 32, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

// ── Village shortcuts ─────────────────────────────────────────────────────

class _VillageRow extends StatelessWidget {
  const _VillageRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VillageCard(
            art: 'assets/mascot-assets/farm/ent_farm.webp',
            title: 'garden'.tr(),
            subtitle: 'garden_nutrient'.tr(
              args: ['${GamePageT2._mockNutrient}'],
            ),
            onTap: comingSoon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VillageCard(
            art: 'assets/mascot-assets/farm/ent_shop.webp',
            title: 'shop'.tr(),
            subtitle: 'shop_coins'.tr(args: ['${MockShop.coins}']),
            onTap: () => context.push('/shop'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _VillageCard(
            art: 'assets/mascot-assets/farm/ent_mailbox.webp',
            title: 'family'.tr(),
            subtitle: 'family_cheers'.tr(args: ['${GamePageT2._mockCheers}']),
            subtitleIcon: '❤️',
            onTap: comingSoon,
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
    required this.onTap,
    this.subtitleIcon,
  });

  final String art;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? subtitleIcon;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(art, height: 58, fit: BoxFit.contain),
          const SizedBox(height: 8),
          Text(
            title,
            style: context.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (subtitleIcon != null) ...[
                Text(subtitleIcon!, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  subtitle,
                  style: context.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Game tile ─────────────────────────────────────────────────────────────

class _GameTile extends StatelessWidget {
  const _GameTile({required this.entry});

  final GameEntry entry;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      padding: EdgeInsets.zero,
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
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppPaletteT2.ink,
                  width: AppPaletteT2.outlineWidth,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.nameKey.tr(),
                    style: context.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppPaletteT2.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppPaletteT2.safe, width: 2),
                  ),
                  child: Text(
                    'game_go'.tr(),
                    style: context.textTheme.labelLarge?.copyWith(
                      color: AppPaletteT2.safe,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
