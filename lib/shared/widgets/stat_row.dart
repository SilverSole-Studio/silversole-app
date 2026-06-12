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
      if (i > 0) {
        children.add(
          Container(width: 1, height: 28, color: context.cs.outlineVariant),
        );
      }
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                items[i].label,
                style: context.tt.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(items[i].value, style: context.tt.headlineSmall),
            ],
          ),
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
    );
  }
}
