import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_spacing.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// One column in a [StatRow].
class StatItem {
  final String label;
  final String value;
  const StatItem(this.label, this.value);
}

/// A row of equal-width stats separated by thin vertical dividers, matching
/// DESIGN.md §C2 (small muted label on top, large value below).
class StatRow extends StatelessWidget {
  final List<StatItem> items;
  const StatRow(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      // Full-height rule between columns; color, thickness and the horizontal
      // gap around it all come from `dividerTheme`.
      if (i > 0) children.add(const VerticalDivider());
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items[i].label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(items[i].value, style: context.textTheme.headlineSmall),
            ],
          ),
        ),
      );
    }
    // IntrinsicHeight + stretch: every column is as tall as the tallest one, so
    // the labels line up along the top and the rule spans the full height
    // instead of floating in the middle.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
