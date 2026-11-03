import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';

/// The app's one card. Its shape, outline and fill come from the active
/// theme's `cardTheme`, so the same widget is a hairline card in the classic
/// theme and a thick-outlined card in the mascot theme; a page never styles a
/// card by hand.
///
/// [tint] gives the quieter second fill (secondary blocks, e.g. today's
/// mission); everything else is the standard card. Pass [onTap] to make the
/// whole card a button.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.tint = false,
    this.color,
    this.padding = const EdgeInsets.all(AppSpacing.base + 2),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool tint;

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

    return Material(
      color: fill,
      elevation: card.elevation ?? 0,
      shadowColor: card.shadowColor,
      surfaceTintColor: Colors.transparent,
      shape: card.shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
