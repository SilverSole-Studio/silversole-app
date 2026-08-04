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

/// Progress bar in this theme's language: an outlined track with a rounded
/// fill floating inside it. Material's LinearProgressIndicator draws no
/// border, so the outline is applied here rather than per call site.
///
/// The fill does NOT touch the outline — [_inset] leaves a ring of [track]
/// visible all the way around it, which is what makes the bar read as a
/// capsule holding a pill rather than a two-tone block.
class MascotProgressBar extends StatelessWidget {
  const MascotProgressBar({
    super.key,
    required this.value,
    this.height = 18,
    this.fill = AppPaletteT2.safe,
    this.track = AppPaletteT2.card,
  });

  /// Gap between the outline and the fill, on every side.
  static const double _inset = 2;

  /// 0..1; values outside are clamped.
  final double value;
  final double height;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track,
        borderRadius: radius,
        border: Border.all(color: AppPaletteT2.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            // heightFactor is required: without it the DecoratedBox has no
            // intrinsic size and the fill collapses to zero height.
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, borderRadius: radius),
            ),
          ),
        ),
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
