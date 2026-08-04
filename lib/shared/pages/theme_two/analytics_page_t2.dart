import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/analytics_view_data.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Analytics, mascot theme: a gait summary over a selectable window, the gait
/// metrics, and the game badge wall — plus the live pressure map on the second
/// tab.
///
/// Only the pressure map is real (live BLE FSR values). Every gait figure is
/// mockup copy from [MockGait]; month and quarter have no aggregation yet and
/// say so rather than drawing an empty chart.
class AnalyticsPageT2 extends StatefulWidget {
  const AnalyticsPageT2({super.key});

  @override
  State<AnalyticsPageT2> createState() => _AnalyticsPageT2State();
}

class _AnalyticsPageT2State extends State<AnalyticsPageT2> {
  bool _showPressure = false;
  AnalyticsRange _range = AnalyticsRange.day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          // stretch, not start: cards whose content is narrower than the
          // screen (the "pending" card) would otherwise shrink-wrap and sit
          // half-width next to the full-width ones.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'analytics_title'.tr(),
                style: context.textTheme.headlineLarge,
              ),
              const SizedBox(height: 14),
              _Segmented(
                labels: ['vitality_gait'.tr(), 'pressure_distribution'.tr()],
                selected: _showPressure ? 1 : 0,
                onSelected: (i) => setState(() => _showPressure = i == 1),
              ),
              const SizedBox(height: 10),
              if (_showPressure)
                const _PressurePanel()
              else ...[
                _Segmented(
                  labels: [
                    for (final r in AnalyticsRange.values) r.labelKey.tr(),
                  ],
                  selected: _range.index,
                  onSelected: (i) =>
                      setState(() => _range = AnalyticsRange.values[i]),
                ),
                const SizedBox(height: 14),
                _RangePanel(range: _range),
                const SizedBox(height: 14),
                const _MetricsCard(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppPaletteT2.gold,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppPaletteT2.ink, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'my_game_badges'.tr(),
                      style: context.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _BadgeWall(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Segmented control ─────────────────────────────────────────────────────

/// Outlined stadium track with the active segment filled gold — this theme's
/// answer to SegmentedButton.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppPaletteT2.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppPaletteT2.ink,
          width: AppPaletteT2.outlineWidth,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: i == selected
                      ? BoxDecoration(
                          color: AppPaletteT2.gold,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppPaletteT2.ink, width: 2),
                        )
                      : null,
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: i == selected
                          ? AppPaletteT2.ink
                          : AppPaletteT2.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    return MascotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('gait_diary'.tr(), style: context.textTheme.titleMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  label: 'steps_label'.tr(),
                  value: '${MockGait.todaySteps}',
                ),
              ),
              Expanded(
                child: _BigStat(
                  label: 'balance_label'.tr(),
                  value: MockGait.balanceGrade,
                  valueColor: AppPaletteT2.safe,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppPaletteT2.ink,
          ),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  static const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  @override
  Widget build(BuildContext context) {
    final steps = MockGait.weekSteps;
    return MascotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('weekly_trend'.tr(), style: context.textTheme.titleMedium),
          const SizedBox(height: 12),
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
                    color: AppPaletteT2.inkMuted.withValues(alpha: 0.25),
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
                        style: context.textTheme.bodySmall,
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
                          style: context.textTheme.bodyMedium,
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
                    isCurved: false,
                    color: AppPaletteT2.gold,
                    barWidth: 4,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, _, index) => FlDotCirclePainter(
                        radius: 6,
                        color: index == steps.length - 1
                            ? AppPaletteT2.safe
                            : AppPaletteT2.gold,
                        strokeWidth: 2.5,
                        strokeColor: AppPaletteT2.ink,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppPaletteT2.gold.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${'weekly_summary'.tr(args: [_grouped(MockGait.weekTotal), '${MockGait.weekDeltaPercent}'])} 👍',
            style: context.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  /// 31800 -> 31,800. Done here rather than in the CSV, where a comma would
  /// split the row.
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
    return MascotCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      child: Column(
        children: [
          Image.asset('assets/mascot-assets/determined.webp', height: 96),
          const SizedBox(height: 10),
          Text(
            'long_term_pending'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

// ── Metrics ───────────────────────────────────────────────────────────────

class _MetricsCard extends StatelessWidget {
  const _MetricsCard();

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      child: Column(
        children: [
          _MetricRow(
            label: 'stride_length'.tr(),
            value: '${MockGait.strideLengthCm} cm',
          ),
          _MetricRow(
            label: 'lr_symmetry'.tr(),
            value: '${MockGait.symmetryScore} ${'score_unit'.tr()}',
          ),
          _MetricRow(
            label: 'stance_swing'.tr(),
            value: '${MockGait.stancePercent} / ${MockGait.swingPercent}',
          ),
          _MetricRow(
            label: 'drag_count'.tr(),
            value: 'drag_today'.tr(args: ['${MockGait.dragCount}']),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.textTheme.bodyLarge),
          Text(value, style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────

class _BadgeWall extends StatelessWidget {
  const _BadgeWall();

  @override
  Widget build(BuildContext context) {
    final badges = badgeCatalog();
    return MascotCard(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
        ),
        itemCount: badges.length,
        itemBuilder: (context, i) => BadgeTile(badge: badges[i]),
      ),
    );
  }
}

/// Earned badges render normally; locked ones are desaturated with a padlock,
/// so the wall reads as progress rather than a gallery.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge, this.lockColor});

  final BadgeEntry badge;
  final Color? lockColor;

  @override
  Widget build(BuildContext context) {
    final art = Image.asset(badge.art, fit: BoxFit.contain);
    return Tooltip(
      message: badge.earned ? badge.nameKey.tr() : 'badge_locked'.tr(),
      child: badge.earned
          ? art
          : Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.45,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0.2126, 0.7152, 0.0722, 0, 0, //
                      0, 0, 0, 1, 0,
                    ]),
                    child: art,
                  ),
                ),
                Icon(
                  Icons.lock,
                  size: 22,
                  color: lockColor ?? AppPaletteT2.ink,
                ),
              ],
            ),
    );
  }
}

// ── Pressure ──────────────────────────────────────────────────────────────

class _PressurePanel extends ConsumerWidget {
  const _PressurePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imu = ref.watch(telemetryViewProvider).recentImu;
    final pressure = imu.isNotEmpty ? imu.last.pressure : const <int>[0, 0, 0];
    return MascotCard(
      child: Center(child: FootPressureHeatmap(pressure: pressure)),
    );
  }
}
