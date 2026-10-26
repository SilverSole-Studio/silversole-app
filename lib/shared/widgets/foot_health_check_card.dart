import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// Home "one-minute foot-pressure health check" hero card (DESIGN.md S1 + the
/// §C3 card anatomy).
///
/// Follows the "gray base, single accent" principle (DESIGN.md §1): the card is
/// the stock neutral surface and the brand accent (`primary`, blue) is the only
/// accent — a solid round play button that doubles as the CTA. Gold is
/// intentionally NOT used: per DESIGN.md blue = action/brand and gold =
/// rewards/points, and starting the check is an action. The large band label
/// stays near-black (`number/stat`).
///
/// Shows the last foot check the wearer finished ([lastFootCheckProvider]):
/// its band and when it was taken. With none on record it says so and offers
/// the check — never a number it does not have.
class FootHealthCheckCard extends ConsumerWidget {
  const FootHealthCheckCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFootCheckProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'foot_health_check_title'.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    last == null
                        ? 'foot_check_none_yet'.tr()
                        : last.rating.labelKey.tr(),
                    style: last == null
                        ? context.textTheme.titleLarge
                        : context.textTheme.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    last == null
                        ? 'foot_check_none_yet_hint'.tr()
                        : 'foot_health_check_last'.tr(
                            args: [lastFootCheckDate(context, last)],
                          ),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.base),
            const _StartButton(),
          ],
        ),
      ),
    );
  }
}

/// When [record] was taken, as the home cards print it: the date, plus the
/// time when it was today.
String lastFootCheckDate(BuildContext context, FootCheckRecord record) {
  final locale = context.locale.toString();
  return record.isOnDay(DateTime.now())
      ? DateFormat.Hm(locale).format(record.takenAt)
      : DateFormat.MMMd(locale).format(record.takenAt);
}

/// Solid round brand-blue play button on the right of [FootHealthCheckCard].
/// It is the card's only CTA — a single play affordance is enough to signal
/// "start the foot-pressure check".
class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: IconButton(
        onPressed: () => context.push('/foot-check'),
        tooltip: 'foot_health_check_cta'.tr(),
        iconSize: 28,
        style: IconButton.styleFrom(
          backgroundColor: context.colorScheme.primary,
          foregroundColor: context.colorScheme.onPrimary,
          shape: const CircleBorder(),
        ),
        icon: const Icon(LucideIcons.play, size: 18),
      ),
    );
  }
}
