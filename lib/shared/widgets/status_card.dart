import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';

enum StatusCardType { normal, statusDisplay }

Widget statusCard(
  BuildContext context, {
  StatusCardType type = StatusCardType.normal,
  required String title,
  required String model,
  required String id,
  required IconData icon,
  bool addition = true,
  DeviceStatusDetailModel? detail,
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Icon(icon, size: 30, color: cs.onSurfaceVariant),
                    // Data
                    Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasProgress)
                  LinearProgressIndicator(
                    year2023: false, //ignore: deprecated_member_use
                    value: progress,
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
    final bgColor = active ? Colors.green[800] : Colors.grey[800];
    final textColor = active ? Colors.white : Colors.grey;
    final text = active ? 'online'.tr() : 'offline'.tr();
    return SizedBox(
      height: 32,
      child: Card(
        color: bgColor,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: textColor, shape: BoxShape.circle),
                    child: const SizedBox(width: 6, height: 6),
                  ),
                ),
                Text(
                  text,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                ),
              ],
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
        color: Colors.grey[800],
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
    child: InkWell(
      onTap: onTap,
      splashColor: splashColor,
      hoverColor: hoverColor,
      focusColor: hoverColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 16,
          children: [
            Row(
              spacing: 16,
              children: [
                Icon(icon),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Row(
                        textBaseline: TextBaseline.alphabetic,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        spacing: 4,
                        children: [
                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'oxanium',
                              fontWeight: FontWeight.bold,
                              fontVariations: [FontVariation('wght', 600)],
                            ),
                          ),

                          // Status Tag
                          if (type == StatusCardType.statusDisplay) ...[
                            const SizedBox(width: 4),
                            if (active != null) statusTag(active) else statusLoading(),
                          ],
                        ],
                      ),

                      // Device Model + Device ID
                      SizedBox(
                        child: Text(
                          '$model • ID: $id',
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelLarge?.copyWith(
                            fontFamily: 'Oxanium',
                            color: Colors.grey,
                            fontVariations: [const FontVariation('wght', 500)],
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
                spacing: 8,
                children: [
                  subStatusCard(
                    icon: (detail.isCharging ?? false)
                        ? LucideIcons.batteryCharging
                        : LucideIcons.batteryMedium,
                    title: detail.lastBatteryPercent != null ? '${detail.lastBatteryPercent}%' : 'no_data'.tr(),
                    hasProgress: true,
                    progress: ((detail.lastBatteryPercent ?? 0) / 100),
                    subtitle: '12hrs remaining',
                  ),
                  subStatusCard(icon: LucideIcons.wifi, title: 'strong'.tr(), subtitle: '8 sec ago'),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
