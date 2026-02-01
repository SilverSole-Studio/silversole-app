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

  Widget hintBindingPage() {
    final tt = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(LucideIcons.link2, color: colorScheme.onPrimaryContainer, size: 28),
          ),
          Text('not_binding'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget buildIndicator({required double progress, required Color? bgColor, required Color color}) {
    return SizedBox(
      width: 128,
      height: 128,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 8,
        // ignore: deprecated_member_use
        year2023: false,
        backgroundColor: bgColor,
        color: color,
      ),
    );
  }

  Widget buildCenterContent({required int eventCount, required Color color}) {
    final tt = Theme.of(context).textTheme;
    return (eventCount > 0)
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                eventCount.toString(),
                style: tt.displaySmall?.copyWith(
                  fontFamily: "Oxanium",
                  fontVariations: [FontVariation('wght', 600)],
                  color: color,
                ),
              ),
              Text('events'.tr()),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.check, size: 48, fontWeight: FontWeight.bold, color: Colors.greenAccent),
              // Text(
              //   'safe'.tr(),
              //   style: tt.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.greenAccent),
              // ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    final eventCount = 1;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = eventCount > 3 ? Colors.red : Theme.of(context).colorScheme.primary;
    final splashColor = cs.primary.withValues(alpha: 0.04);
    final hoverColor = cs.primary.withValues(alpha: 0.02);
    final settings = ref.watch(settingsProvider);
    final isBinding = settings.deviceId != null;
    return Card(
      child: InkWell(
        onTap: () => goToRecentWarningsPage(isBinding),
        splashColor: splashColor,
        hoverColor: hoverColor,
        focusColor: hoverColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('device_recent_warnings'.tr(), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Expanded(
                child: Center(
                  child: (!isBinding)
                      ? hintBindingPage()
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            buildIndicator(
                              progress: eventCount.toDouble() / 10.0,
                              bgColor: eventCount == 0 ? Colors.greenAccent[700] : null,
                              color: color,
                            ),
                            buildCenterContent(eventCount: eventCount, color: color),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
