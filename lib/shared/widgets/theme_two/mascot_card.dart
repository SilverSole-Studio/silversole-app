import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';

/// The mascot theme's card shell: a flat fill with a hard dark outline and a
/// generous corner radius. The outline — not a shadow — is what reads as
/// "card" here, so every block on the page goes through this widget instead of
/// styling its own container.
class MascotCard extends StatelessWidget {
  const MascotCard({
    super.key,
    required this.child,
    this.color = AppPaletteT2.card,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppPaletteT2.cardRadius),
      side: const BorderSide(
        color: AppPaletteT2.ink,
        width: AppPaletteT2.outlineWidth,
      ),
    );

    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A small outlined pill used for statuses and counters (「連續 6 天」,「安全」).
class MascotPill extends StatelessWidget {
  const MascotPill({
    super.key,
    required this.child,
    this.color = AppPaletteT2.card,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppPaletteT2.ink,
          width: AppPaletteT2.outlineWidth,
        ),
      ),
      child: child,
    );
  }
}
