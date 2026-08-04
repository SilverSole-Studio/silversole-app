import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/record_session_mixin.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/widgets/chart/chart_section.dart';
import 'package:silversole/shared/widgets/chart/imu_chart_section.dart';
import 'package:silversole/shared/widgets/chart/record_imu_chart_section.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Live telemetry detail, mascot theme — the panel behind the home screen's
/// "recent device data" card.
///
/// Same capabilities as the classic [AnalyticsDetailPage] (pick a channel,
/// start/stop a recording, export it) with this theme's chrome: outlined
/// cards, gold as the primary fill, pills instead of a segmented strip.
///
/// The chart line colors deliberately stay on `AppPalette.chartSeries`: those
/// carry meaning per channel and are shared by both themes.
class AnalyticsDetailPageT2 extends ConsumerStatefulWidget {
  const AnalyticsDetailPageT2({super.key});

  @override
  ConsumerState<AnalyticsDetailPageT2> createState() =>
      _AnalyticsDetailPageT2State();
}

class _AnalyticsDetailPageT2State extends ConsumerState<AnalyticsDetailPageT2>
    with RecordSessionMixin {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final recordList = ref.watch(liveTelemetryProvider).record;
    final labels = [
      'pressure'.tr(),
      'acc'.tr(),
      'gyro'.tr(),
      'six-axis'.tr(),
      'battery'.tr(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('analytics'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wrapped pills rather than one segmented strip: five channel
              // names do not fit on one row at phone widths.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    _ChannelPill(
                      label: labels[i],
                      selected: _selectedIndex == i,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              MascotCard(
                padding: const EdgeInsets.fromLTRB(6, 14, 12, 6),
                child: ImuChartSection(
                  type: ChardDisplayType.single,
                  selectedList: [_selectedIndex],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'start_record'.tr(),
                      color: AppPaletteT2.gold,
                      onTap: isRecordingNow ? null : startRecord,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.stop_rounded,
                      label: 'stop_record'.tr(),
                      color: AppPaletteT2.card,
                      onTap: stopRecord,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RecordCard(
                recordList: recordList,
                isRecording: isRecordingNow,
                onExport: () => exportRecorded(recordList),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Channel picker ────────────────────────────────────────────────────────

class _ChannelPill extends StatelessWidget {
  const _ChannelPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MascotPill(
        color: selected ? AppPaletteT2.gold : AppPaletteT2.card,
        child: Text(label, style: context.textTheme.labelLarge),
      ),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────

/// Outlined block button. A null [onTap] mutes the fill and the label rather
/// than relying on Material's disabled colors, which this theme overrides.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = enabled ? AppPaletteT2.ink : AppPaletteT2.inkMuted;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: MascotCard(
        color: color,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: ink),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: context.textTheme.titleMedium?.copyWith(color: ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recording ─────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.recordList,
    required this.isRecording,
    required this.onExport,
  });

  final List<dynamic> recordList;
  final bool isRecording;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      color: AppPaletteT2.cardWarm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('record'.tr(), style: context.textTheme.titleMedium),
          if (isRecording) ...[
            const SizedBox(height: 14),
            RecordImuChartSection(type: ChardDisplayType.all),
          ],
          const SizedBox(height: 14),
          Text(
            'already_recording_with_count'.tr(args: ['${recordList.length}']),
            style: context.textTheme.bodyLarge,
          ),
          if (!isRecording) ...[
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.download_rounded,
              label: 'export'.tr(),
              color: AppPaletteT2.gold,
              onTap: recordList.isEmpty ? null : onExport,
            ),
          ],
        ],
      ),
    );
  }
}
