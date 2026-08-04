import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/shop_view_data.dart';
import 'package:silversole/shared/widgets/count_up_text.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// The vitality-coin shop, mascot theme — opened from the games hub's
/// "shop" village card.
///
/// Display only: the balance is [MockShop] and buying does nothing yet, since
/// there is no coin ledger behind it.
class ShopPageT2 extends StatelessWidget {
  const ShopPageT2({super.key});

  static const coinArt = 'assets/mascot-assets/fx/fx_coin.webp';

  @override
  Widget build(BuildContext context) {
    final sections = shopCatalog();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('shop_title'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BalanceCard(),
              for (final section in sections) ...[
                const SizedBox(height: 18),
                _SectionHeader(title: section.titleKey.tr()),
                for (final item in section.items) ...[
                  const SizedBox(height: 10),
                  _ItemCard(item: item),
                ],
              ],
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
    return MascotCard(
      color: AppPaletteT2.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('your_coins'.tr(), style: context.textTheme.bodyLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Image.asset(ShopPageT2.coinArt, height: 34),
              const SizedBox(width: 10),
              CountUpText(
                value: MockShop.coins,
                style: context.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppPaletteT2.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'real_prize_quota'.tr(
              args: [
                '${MockShop.realPrizeUsedNtd}',
                '${MockShop.realPrizeCapNtd}',
              ],
            ),
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppPaletteT2.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

/// Gold tab + title, the same section marker the analytics screen uses.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Expanded(child: Text(title, style: context.textTheme.titleMedium)),
      ],
    );
  }
}

// ── Item ──────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: comingSoon,
      child: Row(
        children: [
          Image.asset(item.art, height: 56, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.titleKey.tr(), style: context.textTheme.titleMedium),
                if (item.subtitleKey != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitleKey!.tr(args: item.subtitleArgs),
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _PricePill(price: item.price),
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return MascotPill(
      color: AppPaletteT2.gold,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(ShopPageT2.coinArt, height: 18),
          const SizedBox(width: 6),
          Text('$price', style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}
