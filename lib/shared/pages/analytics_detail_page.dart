import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/record_session_mixin.dart';
import 'package:silversole/shared/pages/theme_two/analytics_detail_page_t2.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/widgets/chart/chart_section.dart';
import 'package:silversole/shared/widgets/chart/imu_chart_section.dart';
import 'package:silversole/shared/widgets/chart/record_imu_chart_section.dart';

/// Route target for `/analytics-detail`: picks the themed implementation, so
/// switching theme while the panel is open swaps it too.
class AnalyticsDetailRoute extends ConsumerWidget {
  const AnalyticsDetailRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(settingsProvider.select((s) => s.themeVariant));
    return variant == AppThemeVariant.mascot
        ? const AnalyticsDetailPageT2()
        : const AnalyticsDetailPage();
  }
}

/// Live telemetry detail, classic theme — the panel behind the home screen's
/// "recent device data" card.
///
/// The recording half (start/stop/export) lives in [RecordSessionMixin]; this
/// class is only the chrome.
class AnalyticsDetailPage extends ConsumerStatefulWidget {
  const AnalyticsDetailPage({super.key});

  @override
  ConsumerState<AnalyticsDetailPage> createState() =>
      _AnalyticsDetailPageState();
}

class _AnalyticsDetailPageState extends ConsumerState<AnalyticsDetailPage>
    with RecordSessionMixin {
  int _selectedIndex = 0;

  Widget singleTab({
    required List<String> data,
    required int selectedIndex,
    required Function(int) onSelected,
  }) {
    if (data.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 4,
      children: [
        ...data.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          return GestureDetector(
            onTap: () {
              onSelected(i);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 100),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selectedIndex == i
                    ? context.colorScheme.surfaceContainerHighest
                    : context.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(
                  selectedIndex == i ? 50 : 4,
                ),
              ),
              child: Text(label, style: context.textTheme.bodyLarge.bold),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordList = ref.watch(liveTelemetryProvider).record;
    final recordCount = recordList.length;
    final labels = [
      'pressure'.tr(),
      'acc'.tr(),
      'gyro'.tr(),
      'six-axis'.tr(),
      'battery'.tr(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('analytics'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.base,
            ),
            child: Column(
              spacing: 16,
              children: [
                singleTab(
                  data: labels,
                  selectedIndex: _selectedIndex,
                  onSelected: (i) => setState(() => _selectedIndex = i),
                ),
                ImuChartSection(
                  type: ChardDisplayType.single,
                  selectedList: [_selectedIndex],
                ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: !isRecordingNow ? startRecord : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Row(
                            spacing: 8,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.play),
                              Text('start_record'.tr()),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: stopRecord,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Row(
                            spacing: 8,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.square),
                              Text('stop_record'.tr()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: Card.filled(
                    color: context.colorScheme.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Column(
                        spacing: 32,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'record'.tr(),
                            style: context.textTheme.titleSmall.bold,
                          ),
                          if (isRecordingNow)
                            RecordImuChartSection(type: ChardDisplayType.all),
                          Text(
                            'already_recording_with_count'.tr(
                              args: [recordCount.toString()],
                            ),
                            style: context.textTheme.titleMedium,
                          ),
                          if (!isRecordingNow)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FilledButton(
                                  onPressed: recordList.isEmpty
                                      ? null
                                      : () => exportRecorded(recordList),
                                  child: Row(
                                    spacing: 8,
                                    children: [
                                      Icon(LucideIcons.download),
                                      Text('export'.tr()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
