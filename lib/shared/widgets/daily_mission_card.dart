import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/widgets/app_card.dart';

/// Opens today's missions. A labelled card on the home page of both themes
/// (it replaces the unlabelled floating button, whose hint only showed on a
/// long press). No step count or streak: the app has no pedometer and keeps no
/// streak, so the card only names what is waiting.
class DailyMissionCard extends StatelessWidget {
  const DailyMissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final shape = Theme.of(context).cardTheme.shape;
    final side = shape is RoundedRectangleBorder ? shape.side : BorderSide.none;

    return AppCard(
      tint: true,
      onTap: () => showDailyMissionsBottomSheet(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              border: side == BorderSide.none
                  ? null
                  : Border.fromBorderSide(side),
            ),
            child: Icon(LucideIcons.play, size: 24, color: scheme.onPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('today_mission'.tr(), style: context.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'mission_cta'.tr(),
                  style: context.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 24, color: scheme.onSurface),
        ],
      ),
    );
  }
}
