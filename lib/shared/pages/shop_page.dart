import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/shop_view_data.dart';
import 'package:silversole/shared/pages/theme_two/shop_page_t2.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/count_up_text.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// Route target for `/shop`: picks the themed implementation, so switching
/// theme while the shop is open swaps it too.
class ShopRoute extends ConsumerWidget {
  const ShopRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(settingsProvider.select((s) => s.themeVariant));
    return variant == AppThemeVariant.mascot
        ? const ShopPageT2()
        : const ShopPage();
  }
}

/// The vitality-coin shop, classic theme — opened from the games hub's "shop"
/// village card.
///
/// Same catalog as [ShopPageT2] in this theme's vocabulary ([SectionCard],
/// stock [Chip] price tags, the blue accent). The item art is mascot work in
/// both themes: like the game covers, it is the product on sale rather than
/// decoration.
///
/// Display only — the balance is [MockShop] and buying does nothing yet.
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  static const coinArt = 'assets/mascot-assets/fx/fx_coin.webp';

  @override
  Widget build(BuildContext context) {
    final sections = shopCatalog();

    return Scaffold(
      appBar: AppBar(
        title: Text('shop_title'.tr(), style: context.textTheme.titleLarge),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.base,
            children: [
              const _BalanceCard(),
              for (final section in sections)
                SectionCard(
                  title: section.titleKey.tr(),
                  child: Column(
                    children: [
                      for (var i = 0; i < section.items.length; i++) ...[
                        if (i > 0) const Divider(height: AppSpacing.lg),
                        _ItemRow(item: section.items[i]),
                      ],
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

// ── Balance ───────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'your_coins'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Image.asset(ShopPage.coinArt, height: 32),
              const SizedBox(width: AppSpacing.md),
              CountUpText(
                value: MockShop.coins,
                style: context.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'real_prize_quota'.tr(
              args: [
                '${MockShop.realPrizeUsedNtd}',
                '${MockShop.realPrizeCapNtd}',
              ],
            ),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: comingSoon,
      borderRadius: AppRadius.cardR,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Image.asset(item.art, height: 48, fit: BoxFit.contain),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.titleKey.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                  if (item.subtitleKey != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitleKey!.tr(args: item.subtitleArgs),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Chip(
              avatar: Image.asset(ShopPage.coinArt, height: 18),
              label: Text('${item.price}'),
            ),
          ],
        ),
      ),
    );
  }
}
