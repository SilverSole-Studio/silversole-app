import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';

class WarningCard extends ConsumerStatefulWidget {
  const WarningCard({super.key});

  @override
  ConsumerState<WarningCard> createState() => _WarningCardState();
}

class _WarningCardState extends ConsumerState<WarningCard> {
  //TODO: the eventCount is global currently, make the eventCount per device
  int eventCount = 0;

  Widget bar(bool isOn) {
    return Expanded(
      child: SizedBox(
        height: 12,
        child: LinearProgressIndicator(
          value: isOn ? 1 : 0,
          borderRadius: AppRadius.subR,
          year2023: false, // ignore: deprecated_member_use
          stopIndicatorRadius: 0,
        ),
      ),
    );
  }

  Widget buildIndicator({
    required double progress,
    required Color? bgColor,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      spacing: AppSpacing.sm,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'alert_severity'.tr(),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        SizedBox(
          height: 16,
          child: Row(
            spacing: 6,
            children: [bar(progress > 0), bar(progress > 1), bar(progress > 2)],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('low'.tr(), style: TextStyle(color: cs.onSurfaceVariant)),
            Text('high'.tr(), style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget buildCenterContent({required int eventCount, required Color color}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      spacing: AppSpacing.sm,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          eventCount.toString(),
          style: tt.displaySmall?.copyWith(color: color),
        ),
        Text(
          'safety_events_detected'.tr(),
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = eventCount > 3 ? context.tokens.alert : cs.primary;

    //TODO: save the event to history provider and separate with the deviceId
    ref.listen(fallEventStreamProvider, (_, next) {
      next.whenData((event) {
        setState(() {
          eventCount++;
        });
      });
    });

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        // Not tappable: the history page it used to open has no history to
        // show — falls are only counted in memory since the app opened.
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 18,
            children: [
              Text(
                'device_recent_warnings'.tr(),
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              buildCenterContent(eventCount: eventCount, color: color),
              buildIndicator(
                progress: eventCount.toDouble() / 2.0,
                bgColor: eventCount == 0 ? context.tokens.success : null,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
