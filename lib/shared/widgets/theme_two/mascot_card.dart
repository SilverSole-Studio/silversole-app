import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/app_card.dart';

/// The mascot pages' card. It is the app's [AppCard] under another name (the
/// outline comes from the theme, so it follows light/dark); kept so the mascot
/// pages keep their vocabulary. [color] is a fill override, null = the theme's.
class MascotCard extends StatelessWidget {
  const MascotCard({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(color: color, onTap: onTap, padding: padding, child: child);
  }
}

/// Progress bar in this theme's language: an outlined track with a rounded
/// fill floating inside it. Material's LinearProgressIndicator draws no
/// border, so the outline is applied here rather than per call site.
///
/// The fill does NOT touch the outline: [_inset] leaves a ring of [track]
/// visible all the way around it, which is what makes the bar read as a
/// capsule holding a pill rather than a two-tone block.
class MascotProgressBar extends StatelessWidget {
  const MascotProgressBar({
    super.key,
    required this.value,
    this.height = 18,
    this.fill,
    this.track,
  });

  /// Gap between the outline and the fill, on every side.
  static const double _inset = 2;

  /// 0..1; values outside are clamped.
  final double value;
  final double height;

  /// Null = the theme's "safe" green / card color.
  final Color? fill;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final c = context.mascot;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track ?? c.card,
        borderRadius: AppRadius.pillR,
        border: Border.all(color: c.line, width: 2),
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
              decoration: BoxDecoration(
                color: fill ?? c.safe,
                borderRadius: AppRadius.pillR,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small outlined pill used for statuses and counters.
class MascotPill extends StatelessWidget {
  const MascotPill({super.key, required this.child, this.color});

  final Widget child;

  /// Null = the theme's card color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.mascot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: AppRadius.pillR,
        border: Border.all(color: c.line, width: AppPaletteT2.outlineWidth),
      ),
      child: child,
    );
  }
}
