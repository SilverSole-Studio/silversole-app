import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

class WarningCard extends ConsumerStatefulWidget {
  const WarningCard({super.key});

  @override
  ConsumerState<WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends ConsumerState<WarningCard> {
  void goToRecentWarningsPage(bool enable) {
    if (enable) {
      context.push('/device-recent-warnings');
    }
  }

  Widget bar(bool isOn) {
    return Expanded(
      child: SizedBox(
        height: 12,
        child: LinearProgressIndicator(
          value: isOn ? 1 : 0,
          borderRadius: BorderRadius.circular(8),
          year2023: false, // ignore: deprecated_member_use
          stopIndicatorRadius: 0,
        ),
      ),
    );
  }

  Widget buildIndicator({required double progress, required Color? bgColor, required Color color}) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('alert_severity'.tr(), style: TextStyle(color: cs.onSurfaceVariant)),
        SizedBox(
          height: 16,
          child: Row(spacing: 6, children: [bar(progress > 0), bar(progress > 1), bar(progress > 2)]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('low'.tr(), style: TextStyle(color: cs.onSurfaceVariant)),
            Text('high'.tr(), style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        )
      ],
    );
  }

  Widget buildCenterContent({required int eventCount, required Color color}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          eventCount.toString(),
          style: tt.displayMedium?.copyWith(
            fontFamily: "Oxanium",
            fontVariations: [FontVariation('wght', 900)],
            color: color,
          ),
        ),
        Text('safety_events_detected'.tr(), style: TextStyle(color: cs.onSurfaceVariant)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventCount = 0;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = eventCount > 3 ? Colors.red : Theme.of(context).colorScheme.primary;
    final splashColor = cs.primary.withValues(alpha: 0.04);
    final hoverColor = cs.primary.withValues(alpha: 0.02);
    final settings = ref.watch(settingsProvider);
    final isBinding = settings.deviceId != null;
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: InkWell(
          onTap: () => goToRecentWarningsPage(isBinding),
          splashColor: splashColor,
          hoverColor: hoverColor,
          focusColor: hoverColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 18,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('device_recent_warnings'.tr(), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('view_history'.tr(), style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                buildCenterContent(eventCount: eventCount, color: color),
                buildIndicator(
                  progress: eventCount.toDouble() / 10.0,
                  bgColor: eventCount == 0 ? Colors.greenAccent[700] : null,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
