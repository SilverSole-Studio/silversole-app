/// The vitality-coin economy. Nothing here is earned or spent yet — there is
/// no coin ledger in the backend — so the balance and the quota are fixed
/// mockup numbers, kept in one place for both themes.
abstract final class MockShop {
  /// Balance the shop counts up to on open.
  static const int coins = 1310;

  /// Real-prize spend this month, in NTD.
  static const int realPrizeUsedNtd = 0;
  static const int realPrizeCapNtd = 50;
}

/// One purchasable row.
class ShopItem {
  const ShopItem({
    required this.art,
    required this.titleKey,
    required this.price,
    this.subtitleKey,
    this.subtitleArgs = const [],
  });

  /// Mascot art. Shown by BOTH themes — like the game covers, the artwork is
  /// the product here, so the classic theme carries it too.
  final String art;

  final String titleKey;
  final String? subtitleKey;
  final List<String> subtitleArgs;

  /// Cost in vitality coins.
  final int price;
}

/// A titled group of items.
class ShopSection {
  const ShopSection({required this.titleKey, required this.items});

  final String titleKey;
  final List<ShopItem> items;
}

/// The catalog, shared by both themes so the two shops never drift apart.
List<ShopSection> shopCatalog() {
  const shop = 'assets/mascot-assets/shop';
  const prizeValue = '50';

  return const [
    ShopSection(
      titleKey: 'shop_section_gacha',
      items: [
        ShopItem(
          art: '$shop/sh_gacha.webp',
          titleKey: 'shop_item_gacha',
          price: 80,
        ),
      ],
    ),
    ShopSection(
      titleKey: 'shop_section_prize',
      items: [
        ShopItem(
          art: '$shop/sh_coffee.webp',
          titleKey: 'shop_item_coffee',
          subtitleKey: 'shop_prize_value',
          subtitleArgs: [prizeValue],
          price: 2700,
        ),
        ShopItem(
          art: '$shop/sh_voucher.webp',
          titleKey: 'shop_item_voucher',
          subtitleKey: 'shop_prize_value',
          subtitleArgs: [prizeValue],
          price: 3000,
        ),
      ],
    ),
    ShopSection(
      titleKey: 'shop_section_skin',
      items: [
        ShopItem(
          art: '$shop/sh_skin_sport.webp',
          titleKey: 'shop_item_skin_sport',
          subtitleKey: 'shop_skin_wearable',
          price: 300,
        ),
        ShopItem(
          art: '$shop/sh_skin_chef.webp',
          titleKey: 'shop_item_skin_chef',
          subtitleKey: 'shop_skin_wearable',
          price: 250,
        ),
      ],
    ),
  ];
}
