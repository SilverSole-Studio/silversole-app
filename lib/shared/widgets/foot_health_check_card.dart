import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Home "one-minute foot-pressure health check" hero card (DESIGN.md S1 + the
/// §C3 card anatomy).
///
/// Follows the "gray base, single accent" principle (DESIGN.md §1): the card is
/// the stock neutral surface and the brand accent (`primary`, blue) is the only
/// accent — a solid round play button that doubles as the CTA. Gold is
/// intentionally NOT used: per DESIGN.md blue = action/brand and gold =
/// rewards/points, and starting the check is an action. The large score stays
/// near-black (`number/stat`).
///
/// The figures here are a static placeholder — no health-check score or step
/// source is wired up yet (see the pipeline status in CLAUDE.md). They live as
/// named constants so this can later read a provider without touching layout.
class FootHealthCheckCard extends StatelessWidget {
  const FootHealthCheckCard({super.key});

  static const int _score = 81;
  static const String _lastCheck = '6/20';
  static const String _todaySteps = '4,210';

  @override
  Widget build(BuildContext context) {
    final meta = [
      'foot_health_check_last'.tr(args: [_lastCheck]),
      'foot_health_check_status_good'.tr(),
      'foot_health_check_today_steps'.tr(args: [_todaySteps]),
    ].join('  ·  ');

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$_score', style: context.textTheme.displaySmall),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'score_unit'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    meta,
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
        onPressed: comingSoon,
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
