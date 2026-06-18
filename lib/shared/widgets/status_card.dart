import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
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
  bool frosted = false,
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
          color: frosted
              ? cs.surface.withValues(alpha: 0.5)
              : cs.surfaceContainerHigh,
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
    final bgColor = active
        ? cs.primaryContainer
        : (frosted
              ? cs.surface.withValues(alpha: 0.5)
              : cs.surfaceContainerHighest);

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

  final content = InkWell(
    onTap: onTap,
    splashColor: splashColor,
    hoverColor: hoverColor,
    focusColor: hoverColor,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: type == StatusCardType.statusDisplay
          ? _statusDisplayBody(
              context,
              title: title,
              active: active,
              detail: detail,
            )
          : Column(
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
  );

  if (!frosted) {
    return Card(elevation: 0, child: content);
  }

  // Frosted glass: blur whatever sits behind the card (the home hero
  // gradient) and lay a translucent surface on top, with a hairline edge.
  return ClipRRect(
    borderRadius: AppRadius.cardR,
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Material(
        color: cs.surface.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardR,
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: content,
      ),
    ),
  );
}

/// Redesigned device-status body: transparent product image + name + a
/// "toggle" action button + a thick battery bar. Used only for the
/// [StatusCardType.statusDisplay] device card.
Widget _statusDisplayBody(
  BuildContext context, {
  required String title,
  required bool? active,
  required DeviceStatusDetailModel? detail,
}) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final tokens = Theme.of(context).extension<AppTokens>()!;
  final online = active ?? false;
  // TODO: 80 is a placeholder until real battery data is wired through.
  final battery = detail?.lastBatteryPercent ?? 80;
  final lastSeen = detail?.lastHeartbeatAt;
  final lastSeenText = lastSeen != null
      ? DateFormat('MM/dd HH:mm').format(lastSeen.toLocal())
      : '--';

  final batteryValue = (battery / 100).clamp(0.0, 1.0);

  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 120),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: AppSpacing.lg,
      children: [
        SizedBox(
          width: 108,
          height: 82,
          child: Image.asset(
            'assets/images/silversole_full.png',
            fit: BoxFit.contain,
            cacheWidth: 324,
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1) Title on the left, a "toggle" pill pinned to the top-right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: tt.headlineMedium.bold?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest,
                      foregroundColor: cs.onSurfaceVariant,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.cardR,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: AppSpacing.xs,
                        children: [
                          const Icon(LucideIcons.refreshCw, size: 14),
                          Text(
                            'toggle'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // 2) "Last connected" line, directly under the title.
              Row(
                spacing: AppSpacing.sm,
                children: [
                  RadarDot(
                    active: online,
                    color: online ? tokens.success : cs.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      'last_connected'.tr(args: [lastSeenText]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              // 3) Battery bar + percentage, pinned to the bottom.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        year2023: false, // ignore: deprecated_member_use
                        value: batteryValue,
                        stopIndicatorRadius: 0,
                        minHeight: 14,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  ),
                  Text(
                    '$battery%',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
