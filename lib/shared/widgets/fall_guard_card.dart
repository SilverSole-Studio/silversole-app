import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/widgets/app_card.dart';

/// Fall detection, as it is shown on the map page: how many falls the soles
/// reported since the app was opened. The count is held in memory only (see
/// [fallCountSinceOpenProvider]), so the copy says exactly that: no "last 7
/// days", no "family notified". One card for both themes; the theme gives it
/// its look.
class FallGuardCard extends ConsumerWidget {
  const FallGuardCard({super.key});

  /// The key of the status pill, for tests.
  static const statusKey = ValueKey('fall_guard_status');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(fallCountSinceOpenProvider);
    final safe = count == 0;
    final scheme = context.colorScheme;

    return AppCard(
      child: Row(
        children: [
          Icon(LucideIcons.shieldCheck, size: 32, color: scheme.onSurface),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'fall_guard_active'.tr(),
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  safe
                      ? 'fall_guard_none_since_open'.tr()
                      : 'fall_guard_count_since_open'.tr(args: ['$count']),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // "Watching", not "safe": the guard cannot promise safety.
          Container(
            key: statusKey,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: safe
                  ? context.tokens.success.withValues(alpha: 0.14)
                  : context.tokens.alert,
              borderRadius: AppRadius.pillR,
            ),
            child: Text(
              safe
                  ? 'fall_guard_watching'.tr()
                  : 'fall_guard_events'.tr(args: ['$count']),
              style: context.textTheme.labelMedium?.copyWith(
                color: safe ? context.tokens.success : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
