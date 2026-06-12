import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_radius.dart';
import 'package:silversole/core/theme/app_spacing.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// A titled content card matching the DESIGN.md "section card" (§C3):
/// 20dp radius, soft shadow in light / color-step in dark (from `cardTheme`),
/// an optional header row (title + trailing, e.g. a `→` to a detail page),
/// then [child].
///
/// Use for dashboard/analytics/home sections instead of hand-rolling
/// `Card` + `Padding` + a bold title every time.
class SectionCard extends StatelessWidget {
  final String? title;

  /// Optional trailing widget in the header (commonly an arrow icon button).
  final Widget? trailing;

  /// Makes the whole card tappable (ripple clipped to the card shape).
  final VoidCallback? onTap;

  final EdgeInsetsGeometry padding;
  final Widget child;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.base),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || trailing != null;
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(title!, style: context.tt.titleMedium),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );

    return Card(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: AppRadius.cardR,
              child: content,
            ),
    );
  }
}
