import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';

/// A stretch of the x axis tinted behind the plot, so a phase can be seen on
/// the chart rather than only read off a legend.
class GaitChartBand {
  const GaitChartBand({
    required this.fromX,
    required this.toX,
    required this.color,
  });

  final double fromX;
  final double toX;
  final Color color;
}

/// A clinical reference value drawn as a band, not a line: walking speed is
/// modelled rather than measured so the value carries real uncertainty, and a
/// hard line would put borderline cases on the wrong side of it.
class GaitReferenceBand {
  const GaitReferenceBand({
    required this.value,
    required this.uncertainty,
    required this.label,
  });

  final double value;
  final double uncertainty;
  final String label;
}

/// Y range padded past the data and snapped to [step], so a nearly flat series
/// does not render glued to the frame.
({double min, double max}) _bounds(List<double> values, double step) {
  if (values.isEmpty) return (min: 0, max: step);
  final lo = values.reduce(math.min);
  final hi = values.reduce(math.max);
  final pad = math.max((hi - lo) * 0.35, step);
  return (
    min: ((lo - pad) / step).floorToDouble() * step,
    max: ((hi + pad) / step).ceilToDouble() * step,
  );
}

/// Bucket number under a bar or point: 1-based, thinned out so twelve weeks do
/// not collide.
FlTitlesData _bucketTitles(
  BuildContext context,
  int count, {
  bool week = false,
  double? leftInterval,
}) {
  final every = count > 8 ? 3 : 1;
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: leftInterval == null
        ? const AxisTitles()
        : AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: leftInterval,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(2),
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 20,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index % every != 0 && index != count - 1) {
            return const SizedBox.shrink();
          }
          return Text(
            week ? 'W${index + 1}' : '${index + 1}',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(BuildContext context) => FlGridData(
  show: true,
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: context.colorScheme.outlineVariant, strokeWidth: 1),
);

/// One bar per day: the week scale's daily speed.
class GaitSpeedBars extends StatelessWidget {
  const GaitSpeedBars({
    super.key,
    required this.values,
    required this.color,
    this.step = 0.05,
  });

  final List<double> values;
  final Color color;
  final double step;

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds(values, step);
    return BarChart(
      BarChartData(
        minY: bounds.min,
        maxY: bounds.max,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _bucketTitles(context, values.length),
        barTouchData: BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  fromY: bounds.min,
                  color: color,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sub),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A trend over whole buckets. [openLast] leaves the final point hollow and its
/// segment dashed — the bucket is not finished and does not count yet.
class GaitTrendChart extends StatelessWidget {
  const GaitTrendChart({
    super.key,
    required this.values,
    required this.color,
    this.step = 0.05,
    this.openLast = false,
    this.bands = const [],
    this.dotColorAt,
    this.reference,
    this.showLeftAxis = false,
    this.weekLabels = false,
  });

  final List<double> values;
  final Color color;
  final double step;
  final bool openLast;

  /// Phase tints behind the plot.
  final List<GaitChartBand> bands;

  /// Per-point color, so each week reads as the phase it fell in.
  final Color Function(int index)? dotColorAt;

  final GaitReferenceBand? reference;

  /// Values down the left edge — worth the room on the long trajectory.
  final bool showLeftAxis;

  /// Label buckets `W1`, `W4`… instead of plain numbers.
  final bool weekLabels;

  @override
  Widget build(BuildContext context) {
    final reference = this.reference;
    final bounds = _bounds([
      ...values,
      if (reference != null) reference.value - reference.uncertainty,
      if (reference != null) reference.value + reference.uncertainty,
    ], step);
    final solid = openLast && values.length > 1
        ? values.sublist(0, values.length - 1)
        : values;

    LineChartBarData bar(List<double> series, {required bool dashed}) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < series.length; i++)
              FlSpot(
                (i + (dashed ? values.length - 2 : 0)).toDouble(),
                series[i],
              ),
          ],
          isCurved: false,
          color: color,
          barWidth: 2.5,
          dashArray: dashed ? const [5, 4] : null,
          dotData: FlDotData(
            getDotPainter: (spot, _, _, _) {
              final index = spot.x.round();
              // The last bucket is still running: hollow, so it reads as not
              // counted yet.
              final open = openLast && index == values.length - 1;
              final dot = dotColorAt?.call(index) ?? color;
              return FlDotCirclePainter(
                radius: open ? 4 : 3.5,
                color: open ? context.colorScheme.surface : dot,
                strokeWidth: 2,
                strokeColor: dot,
              );
            },
          ),
        );

    return LineChart(
      LineChartData(
        minY: bounds.min,
        maxY: bounds.max,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _bucketTitles(
          context,
          values.length,
          week: weekLabels,
          leftInterval: showLeftAxis ? step * 2 : null,
        ),
        lineTouchData: const LineTouchData(enabled: false),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            for (final band in bands)
              VerticalRangeAnnotation(
                x1: band.fromX,
                x2: band.toX,
                color: band.color,
              ),
          ],
          horizontalRangeAnnotations: [
            if (reference != null)
              HorizontalRangeAnnotation(
                y1: reference.value - reference.uncertainty,
                y2: reference.value + reference.uncertainty,
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.14,
                ),
              ),
          ],
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (reference != null)
              HorizontalLine(
                y: reference.value,
                color: context.colorScheme.onSurfaceVariant,
                strokeWidth: 1.4,
                dashArray: const [5, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  labelResolver: (_) => reference.label,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        lineBarsData: [
          bar(solid, dashed: false),
          if (solid.length != values.length)
            bar(values.sublist(values.length - 2), dashed: true),
        ],
      ),
    );
  }
}

/// Left against right stance share, one pair per bucket.
class GaitStanceChart extends StatelessWidget {
  const GaitStanceChart({
    super.key,
    required this.left,
    required this.right,
    required this.leftColor,
    required this.rightColor,
  });

  final List<double> left;
  final List<double> right;
  final Color leftColor;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds([...left, ...right], 2);
    BarChartRodData rod(double value, Color color) => BarChartRodData(
      toY: value,
      fromY: bounds.min,
      color: color,
      width: 10,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sub),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              minY: bounds.min,
              maxY: bounds.max,
              gridData: _grid(context),
              borderData: FlBorderData(show: false),
              titlesData: _bucketTitles(context, left.length),
              barTouchData: BarTouchData(enabled: false),
              barGroups: [
                for (var i = 0; i < left.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      rod(left[i], leftColor),
                      rod(right[i], rightColor),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpacing.base,
          children: [
            _LegendDot(color: leftColor, label: 'left_foot'.tr()),
            _LegendDot(color: rightColor, label: 'right_foot'.tr()),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.xs,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(label, style: context.textTheme.labelMedium),
      ],
    );
  }
}

/// The quarter's phase timeline: one span per phase, as wide as it lasted.
class GaitPhaseTimeline extends StatelessWidget {
  const GaitPhaseTimeline({
    super.key,
    required this.spans,
    required this.colorOf,
  });

  final List<GaitPhaseSpan> spans;
  final Color Function(GaitPhase phase) colorOf;

  @override
  Widget build(BuildContext context) {
    final weeks = spans.fold(0, (sum, span) => sum + span.weeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'gait_week_n'.tr(args: ['1']),
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'gait_week_n'.tr(args: ['$weeks']),
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Row(
          spacing: AppSpacing.xs,
          children: [
            for (final span in spans)
              Expanded(
                flex: span.weeks,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorOf(span.phase),
                    borderRadius: AppRadius.subR,
                  ),
                ),
              ),
          ],
        ),
        Row(
          spacing: AppSpacing.xs,
          children: [
            for (final span in spans)
              Expanded(
                flex: span.weeks,
                child: Text(
                  span.phase.labelKey.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium.bold?.copyWith(
                    color: colorOf(span.phase),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Four metrics over the same twelve weeks, stacked so the shapes can be
/// compared at a glance — the point being that they all move together.
class GaitSmallMultiples extends StatelessWidget {
  const GaitSmallMultiples({
    super.key,
    required this.lines,
    required this.colorOf,
  });

  final List<GaitTrendLine> lines;
  final Color Function(GaitTone tone) colorOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        for (final line in lines)
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  line.nameKey.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelLarge,
                ),
              ),
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 30,
                  child: _Sparkline(
                    values: line.values,
                    color: colorOf(line.tone),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  line.values.last.toStringAsFixed(
                    line.values.last < 10 ? 2 : 1,
                  ),
                  textAlign: TextAlign.right,
                  style: context.textTheme.titleSmall.bold?.copyWith(
                    color: colorOf(line.tone),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds(values, (values.first.abs() * 0.02).clamp(0.02, 2));
    return LineChart(
      LineChartData(
        minY: bounds.min,
        maxY: bounds.max,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
