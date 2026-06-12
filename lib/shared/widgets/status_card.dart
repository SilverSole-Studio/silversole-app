import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/widgets/build_material_popup_menu.dart';
import 'package:silversole/shared/widgets/rader_dot.dart';

enum StatusCardType { normal, statusDisplay, menu }

Widget statusCard(
  BuildContext context, {
  StatusCardType type = StatusCardType.normal,
  required String title,
  required String model,
  required String id,
  required IconData icon,
  bool addition = true,
  DeviceStatusDetailModel? detail,
  List<ListTileData> menuItems = const <ListTileData>[],
  bool? active,
  VoidCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final splashColor = cs.primary.withValues(alpha: 0.04);
  final hoverColor = cs.primary.withValues(alpha: 0.02);

  Widget subStatusCard({
    required IconData icon,
    required String title,
    bool hasProgress = false,
    double progress = 0.8,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Flexible(
      flex: 1,
      child: SizedBox(
        width: 300,
        child: Card(
          color: cs.surfaceContainerHigh,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Icon(icon, size: 30, color: cs.onSurfaceVariant),
                    // Data
                    Text(title, style: tt.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (hasProgress)
                  LinearProgressIndicator(
                    year2023: false, //ignore: deprecated_member_use
                    value: progress,
                    stopIndicatorRadius: 0,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  )
                else
                  SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget statusTag(bool active) {
    final bgColor = active ? cs.primaryContainer : cs.surfaceContainerHighest;

    final textColor = active ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final text = active ? 'online'.tr() : 'offline'.tr();
    return SizedBox(
      height: 32,
      child: Card(
        elevation: 0,
        color: bgColor,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Center(
            child: RichText(
              text: TextSpan(
                style: tt.bodySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: RadarDot(active: active, color: textColor),
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget statusLoading() {
    return SizedBox(
      width: 70,
      height: 32,
      child: Card(
        color: cs.onSurfaceVariant,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.outline,
              year2023: false, // ignore: deprecated_member_use
            ),
          ),
        ),
      ),
    );
  }

  return Card(
    elevation: 0,
    child: InkWell(
      onTap: onTap,
      splashColor: splashColor,
      hoverColor: hoverColor,
      focusColor: hoverColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          spacing: AppSpacing.base,
          children: [
            Row(
              spacing: AppSpacing.base,
              children: [
                Icon(icon),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.xs,
                    children: [
                      Row(
                        textBaseline: TextBaseline.alphabetic,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        spacing: AppSpacing.xs,
                        children: [
                          // Title
                          Text(title, style: tt.titleLarge),

                          // Right Tool Widget
                          switch (type) {
                            StatusCardType.statusDisplay =>
                              active != null
                                  ? statusTag(active)
                                  : statusLoading(),
                            StatusCardType.menu => buildMaterialPopupMenu(
                              context,
                              raw: menuItems,
                            ),
                            _ => const SizedBox.shrink(),
                          },
                        ],
                      ),

                      // Device Model + Device ID
                      SizedBox(
                        child: Text(
                          '$model • ID: $id',
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (addition && detail != null)
              Row(
                spacing: AppSpacing.sm,
                children: [
                  subStatusCard(
                    icon: (detail.isCharging ?? false)
                        ? LucideIcons.batteryCharging
                        : LucideIcons.batteryMedium,
                    title: detail.lastBatteryPercent != null
                        ? '${detail.lastBatteryPercent}%'
                        : 'no_data'.tr(),
                    hasProgress: true,
                    progress: ((detail.lastBatteryPercent ?? 0) / 100),
                    subtitle: '12hrs remaining',
                  ),
                  subStatusCard(
                    icon: LucideIcons.wifi,
                    title: 'strong'.tr(),
                    subtitle: '8 sec ago',
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
