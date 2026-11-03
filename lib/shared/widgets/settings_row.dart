import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/app_card.dart';

/// One row of a settings list: icon, title, optional subtitle and a trailing
/// widget (a chevron by default when it can be tapped). Each row is its own
/// [AppCard], so every list in the app (account, devices, settings) looks the
/// same in both themes; there is no grouped slab and no separate row style.
///
/// The row is at least 64 tall and the whole card is the touch target.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Replaces the chevron (a switch, a progress ring...).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Destructive action: title and icon in the error color.
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron)
              Icon(
                LucideIcons.chevronRight,
                size: 24,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled group of settings cards: a section title, then the cards 8 apart.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(title!, style: context.textTheme.titleLarge),
          ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          children[i],
        ],
      ],
    );
  }
}
