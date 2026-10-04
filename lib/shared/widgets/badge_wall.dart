import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/analytics_view_data.dart';
import 'package:silversole/shared/widgets/section_card.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// The game badge wall, in both themes' vocabularies.
///
/// It sits at the bottom of the games page: badges are earned by playing, so
/// they belong with the games rather than with the gait figures.
///
/// Earned flags are mockup copy — there is no achievement backend (see
/// [badgeCatalog]).

const _grid = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 4,
  mainAxisSpacing: AppSpacing.sm,
  crossAxisSpacing: AppSpacing.sm,
  childAspectRatio: 0.95,
);

/// Classic theme: a titled card around the grid.
class BadgeWall extends StatelessWidget {
  const BadgeWall({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = badgeCatalog();
    return SectionCard(
      title: 'my_game_badges'.tr(),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: _grid,
        itemCount: badges.length,
        itemBuilder: (context, i) => BadgeTile(
          badge: badges[i],
          lockColor: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Mascot theme: this theme's gold section tab over an outlined card.
class BadgeWallT2 extends StatelessWidget {
  const BadgeWallT2({super.key});

  @override
  Widget build(BuildContext context) {
    final badges = badgeCatalog();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            Text('my_game_badges'.tr(), style: context.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        MascotCard(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: badges.length,
            itemBuilder: (context, i) => BadgeTile(badge: badges[i]),
          ),
        ),
      ],
    );
  }
}

/// Earned badges render normally; locked ones are desaturated with a padlock,
/// so the wall reads as progress rather than a gallery.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge, this.lockColor});

  final BadgeEntry badge;
  final Color? lockColor;

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(badge.art, fit: BoxFit.contain);
    return Tooltip(
      message: badge.earned ? badge.nameKey.tr() : 'badge_locked'.tr(),
      child: badge.earned
          ? art
          : Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.45,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0, 0, 0, 1, 0,
                    ]),
                    child: art,
                  ),
                ),
                Icon(
                  Icons.lock,
                  size: 22,
                  color: lockColor ?? AppPaletteT2.ink,
                ),
              ],
            ),
    );
  }
}
