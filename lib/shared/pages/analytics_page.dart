import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/analytics_view_data.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart'
    show BadgeTile;
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/section_card.dart';
import 'package:silversole/shared/widgets/stat_row.dart';

/// Analytics, classic theme.
///
/// Mirrors the mascot screen's structure — gait summary over a selectable
/// window, gait metrics, badge wall, and the live pressure map — using this
/// theme's own vocabulary: stock [SegmentedButton]s styled by the theme,
/// [SectionCard], [StatRow], and the blue accent for data.
///
/// Only the pressure map is real (live BLE FSR values). Gait figures come from
/// [MockGait]; month and quarter have no aggregation yet and say so.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _showPressure = false;
  AnalyticsRange _range = AnalyticsRange.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'analytics_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.base,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text('vitality_gait'.tr()),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('pressure_distribution'.tr()),
                  ),
                ],
                selected: {_showPressure},
                onSelectionChanged: (s) =>
                    setState(() => _showPressure = s.first),
              ),
              if (_showPressure)
                const _PressurePanel()
              else ...[
                SegmentedButton<AnalyticsRange>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    for (final r in AnalyticsRange.values)
                      ButtonSegment(
                        value: r,
                        label: Text(
                          r.labelKey.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                _RangePanel(range: _range),
                const _MetricsCard(),
                const _BadgeWall(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Range panels ──────────────────────────────────────────────────────────

class _RangePanel extends StatelessWidget {
  const _RangePanel({required this.range});

  final AnalyticsRange range;

  @override
  Widget build(BuildContext context) {
    if (!range.isReady) return const _PendingCard();
    return range == AnalyticsRange.day ? const _DayCard() : const _WeekCard();
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'gait_diary'.tr(),
      child: StatRow([
        StatItem('steps_label'.tr(), '${MockGait.todaySteps}'),
        StatItem('balance_label'.tr(), MockGait.balanceGrade),
      ]),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  static const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  Widget build(BuildContext context) {
    final steps = MockGait.weekSteps;
    final accent = context.colorScheme.primary;

    return SectionCard(
      title: 'weekly_trend'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 8000,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 4000,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.colorScheme.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4000,
                      reservedSize: 42,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= _weekdayKeys.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          _weekdayKeys[i].tr(),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < steps.length; i++)
                        FlSpot(i.toDouble(), steps[i].toDouble()),
                    ],
                    isCurved: true,
                    color: accent,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
                        radius: 4,
                        color: index == steps.length - 1
                            ? context.tokens.success
                            : accent,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: accent.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'weekly_summary'.tr(
              args: [
                _grouped(MockGait.weekTotal),
                '${MockGait.weekDeltaPercent}',
              ],
            ),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 31800 -> 31,800. Grouped here rather than in the CSV, where a comma
  /// would split the row.
  static String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 48,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'long_term_pending'.tr(),
              textAlign: TextAlign.center,
              style: context.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Metrics ───────────────────────────────────────────────────────────────

class _MetricsCard extends StatelessWidget {
  const _MetricsCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          _MetricRow(
            label: 'stride_length'.tr(),
            value: '${MockGait.strideLengthCm} cm',
          ),
          const Divider(height: AppSpacing.lg),
          _MetricRow(
            label: 'lr_symmetry'.tr(),
            value: '${MockGait.symmetryScore} ${'score_unit'.tr()}',
          ),
          const Divider(height: AppSpacing.lg),
          _MetricRow(
            label: 'stance_swing'.tr(),
            value: '${MockGait.stancePercent} / ${MockGait.swingPercent}',
          ),
          const Divider(height: AppSpacing.lg),
          _MetricRow(
            label: 'drag_count'.tr(),
            value: 'drag_today'.tr(args: ['${MockGait.dragCount}']),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: context.textTheme.titleMedium),
      ],
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────

class _BadgeWall extends StatelessWidget {
  const _BadgeWall();

  @override
  Widget build(BuildContext context) {
    final badges = badgeCatalog();
    return SectionCard(
      title: 'my_game_badges'.tr(),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.95,
        ),
        itemCount: badges.length,
        itemBuilder: (context, i) => BadgeTile(
          badge: badges[i],
          lockColor: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Pressure ──────────────────────────────────────────────────────────────

/// The live foot-pressure heat map — the one panel here backed by real data.
class _PressurePanel extends ConsumerWidget {
  const _PressurePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imu = ref.watch(telemetryViewProvider).recentImu;
    final pressure = imu.isNotEmpty ? imu.last.pressure : const <int>[0, 0, 0];
    return SectionCard(
      child: Center(child: FootPressureHeatmap(pressure: pressure)),
    );
  }
}
