import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Entertainment hub ("娛樂"): a "遊戲" (games) tab and a "兌換" (redeem) tab.
/// Both bodies are placeholders for now — defaults to the games tab.
class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'entertainment'.tr(),
            style: context.textTheme.titleLarge,
          ),
          bottom: TabBar(
            labelStyle: context.textTheme.titleMedium,
            unselectedLabelStyle: context.textTheme.titleMedium,
            tabs: [
              Tab(text: 'game'.tr()),
              Tab(text: 'redeem'.tr()),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // _placeholder(context, LucideIcons.gamepad2, 'game'.tr()),
              gameView(),
              _placeholder(context, LucideIcons.gift, 'redeem'.tr()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon, String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [
          Icon(icon, size: 56, color: context.colorScheme.onSurfaceVariant),
          Text(label, style: context.textTheme.titleMedium),
          Text(
            'coming_soon'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget gameView() {
    // Placeholder catalog — a 2-column grid with n rows of game cards.
    // (name, high score, thumbnail asset, url)
    const fallbackThumb = 'assets/images/silversole_full.png';
    // TODO: point each game at its real web build; example.com for now.
    const url = 'https://h5.silversole.dongyu.company/';
    final demoGames = [
      (
        'skiing_game'.tr(),
        '8',
        'assets/images/games/skiing_game_preview.png',
        "${url}skiing",
      ),
      ('Balance Run', '12', fallbackThumb, url),
      ('Heel Hero', '5', fallbackThumb, url),
      ('Gait Rush', '20', fallbackThumb, url),
    ];
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.base),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.72,
      ),
      itemCount: demoGames.length,
      itemBuilder: (context, i) {
        final g = demoGames[i];
        return GameCard(
          name: g.$1,
          highScore: g.$2,
          image: g.$3,
          onTap: () => context.push(
            '/game-webview',
            extra: {'url': g.$4, 'title': g.$1},
          ),
        );
      },
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    this.name = 'game_name',
    this.highScore = '8',
    this.image = 'assets/images/silversole_full.png',
    this.onTap,
  });

  final String name;
  final String highScore;
  final String image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.sm,
            children: [
              // Shorter square thumbnail (was a height-filling Expanded) so the
              // title below gets breathing room.
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    // Concentric with the Card: inner radius = card radius − the
                    // gap to the Card edge (its AppSpacing.sm padding), so the gap
                    // stays a uniform AppSpacing.sm all the way around — corners too.
                    borderRadius: BorderRadius.circular(
                      AppRadius.card - AppSpacing.sm,
                    ),
                  ),
                  // Full-bleed: fill the rounded box (clipped above), no frame.
                  child: Image.asset(image, fit: BoxFit.cover),
                ),
              ),
              // Title + score get the freed-up space, vertically centered.
              Expanded(
                child: Row(
                  spacing: AppSpacing.xs,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      'highest_score'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      highScore,
                      style: context.textTheme.titleSmall.bold?.copyWith(
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
