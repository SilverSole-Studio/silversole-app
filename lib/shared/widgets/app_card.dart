import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// How loud a card is. Three weights, in every look, so a page has a clear
/// order: one [hero] (the thing to do), a few [standard] cards, and [quiet]
/// ones for what is only there to be found.
enum CardWeight {
  /// The one main card of a page: bigger shadow / outline.
  hero,

  /// Everything ordinary.
  standard,

  /// Secondary blocks: flat, no shadow.
  quiet,
}

/// The app's one card. Its outline, fill and lift come from the active look,
/// so the same widget is a hairline card in the tech looks, a thick-outlined
/// card with a hard shadow in 粗哥手繪小鎮風, a panel in the dashboard and a
/// sheet of paper in the journal; a page never styles a card by hand.
///
/// [weight] picks how loud it is; [tint] gives the quieter second fill; pass
/// [onTap] to make the whole card a button.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.tint = false,
    this.weight = CardWeight.standard,
    this.color,
    this.padding = const EdgeInsets.all(AppSpacing.base + 2),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool tint;
  final CardWeight weight;

  /// Overrides the fill (state colors); prefer [tint].
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = theme.cardTheme;
    final fill =
        color ??
        (tint ? theme.colorScheme.surfaceContainerLow : card.color) ??
        theme.colorScheme.surface;

    // Looks that draw the card by hand (the outline and shadow are not things a
    // Material can do): A with its hard shadow, B's panel, C's sheet of paper.
    switch (context.variant) {
      case AppThemeVariant.mascot:
        final c = context.mascot;
        final drop = switch (weight) {
          CardWeight.hero => AppPaletteT2.shadowDrop + 1,
          CardWeight.standard => AppPaletteT2.shadowDrop - 1,
          CardWeight.quiet => 0.0,
        };
        final width = weight == CardWeight.quiet
            ? AppPaletteT2.outlineWidth - 0.5
            : AppPaletteT2.outlineWidth;
        return _Drawn(
          fill: color ?? (tint ? c.cardWarm : c.card),
          radius: AppPaletteT2.cardRadius,
          border: Border.all(color: c.line, width: width),
          shadows: [
            if (drop > 0)
              BoxShadow(color: c.line, offset: Offset(0, drop), blurRadius: 0),
          ],
          onTap: onTap,
          padding: padding,
          child: child,
        );
      case AppThemeVariant.journal:
        return _Drawn(
          fill: color ?? (tint ? AppPaletteC.butter : AppPaletteC.card),
          radius: weight == CardWeight.hero ? 22 : 18,
          border: null,
          shadows: [
            if (weight != CardWeight.quiet)
              BoxShadow(
                color: const Color(
                  0xFF3C321E,
                ).withValues(alpha: weight == CardWeight.hero ? 0.2 : 0.14),
                offset: Offset(0, weight == CardWeight.hero ? 10 : 6),
                blurRadius: weight == CardWeight.hero ? 18 : 12,
              ),
          ],
          onTap: onTap,
          padding: padding,
          child: child,
        );
      case AppThemeVariant.dashboard:
        return _Drawn(
          fill: color ?? (tint ? AppPaletteB.panel2 : AppPaletteB.panel),
          radius: weight == CardWeight.hero ? 28 : 26,
          border: weight == CardWeight.quiet
              ? null
              : Border.all(color: AppPaletteB.line, width: 1.5),
          shadows: const [],
          onTap: onTap,
          padding: padding,
          child: child,
        );
      case AppThemeVariant.techLight:
      case AppThemeVariant.techDark:
        final isLight = theme.brightness == Brightness.light;
        final shape = card.shape;
        final quiet = weight == CardWeight.quiet;
        return Material(
          color: quiet && color == null
              ? theme.colorScheme.surfaceContainerHigh.withValues(
                  alpha: isLight ? 0.6 : 0.5,
                )
              : fill,
          elevation: switch (weight) {
            CardWeight.hero => isLight ? 3 : 0,
            CardWeight.standard => card.elevation ?? 0,
            CardWeight.quiet => 0,
          },
          shadowColor: isLight
              ? Colors.black.withValues(alpha: 0.10)
              : card.shadowColor,
          surfaceTintColor: Colors.transparent,
          // Quiet cards drop the hairline: they are fills, not outlines.
          shape: quiet && shape is RoundedRectangleBorder
              ? RoundedRectangleBorder(borderRadius: shape.borderRadius)
              : shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        );
    }
  }
}

/// A card the theme's [Material] cannot draw: a fill, an optional outline and
/// shadows that sit outside the clip.
class _Drawn extends StatelessWidget {
  const _Drawn({
    required this.fill,
    required this.radius,
    required this.border,
    required this.shadows,
    required this.onTap,
    required this.padding,
    required this.child,
  });

  final Color fill;
  final double radius;
  final Border? border;
  final List<BoxShadow> shadows;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final inner = BorderRadius.circular(
      border == null ? radius : radius - border!.top.width,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: r,
        border: border,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: inner,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
