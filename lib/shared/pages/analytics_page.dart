import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/utils/useful_extension.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _selectedRangeIndex = 0;
  int _selectedTrendIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'analytics'.tr(),
          style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.calendarDays),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: _RangeSelector(
                      labels: [
                        'today'.tr(),
                        'seven_days'.tr(),
                        'thirty_days'.tr(),
                      ],
                      selectedIndex: _selectedRangeIndex,
                      onSelected: (index) {
                        setState(() => _selectedRangeIndex = index);
                      },
                    ),
                  ),
                  _MetricSelector(label: 'pressure'.tr()),
                ],
              ),
              const _PressureDistributionCard(),
              const _TodayStatusCard(),
              const _MetricGrid(),
              const _PressureAnalysisCard(),
              _StabilityTrendCard(
                selectedIndex: _selectedTrendIndex,
                onSelected: (index) {
                  setState(() => _selectedTrendIndex = index);
                },
              ),
              const _CareSuggestionCard(
                suggestion:
                    '整體步態今日穩定。右腳後跟壓力略高，可能與行走平衡或鞋墊擺放有關。建議今晚檢查鞋墊是否放置正確，並留意是否有任何腳跟不適。',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: context.cs.surfaceContainerHigh,
        selectedBackgroundColor: context.cs.primaryContainer,
        selectedForegroundColor: context.cs.onPrimaryContainer,
        foregroundColor: context.cs.onSurfaceVariant,
      ),
      segments: [
        for (var i = 0; i < labels.length; i++)
          ButtonSegment<int>(
            value: i,
            label: Text(
              labels[i],
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
      selected: {selectedIndex},
      onSelectionChanged: (selection) {
        onSelected(selection.first);
      },
    );
  }
}

class _MetricSelector extends StatelessWidget {
  const _MetricSelector({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [MenuItemButton(onPressed: () {}, child: Text(label))],
      builder: (context, controller, child) {
        return FilledButton.tonalIcon(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(LucideIcons.chevronDown, size: 18),
          label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        );
      },
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        color: context.cs.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _PressureDistributionCard extends StatelessWidget {
  const _PressureDistributionCard();

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return _AnalyticsCard(
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'foot_pressure_distribution'.tr(),
            style: context.tt.titleMedium?.bold,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 16,
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 190,
                  child: CustomPaint(
                    painter: _FootPressurePainter(colorScheme: cs),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const Expanded(flex: 4, child: _PressureValueList()),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'low'.tr(),
                style: context.tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Container(
                width: 170,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2F56B3),
                      Color(0xFF126BFF),
                      Color(0xFF4AC663),
                      Color(0xFFFFE735),
                      Color(0xFFFF8A1D),
                      Color(0xFFFF2D20),
                    ],
                  ),
                ),
              ),
              Text(
                'high'.tr(),
                style: context.tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PressureValueList extends StatelessWidget {
  const _PressureValueList();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        _PressureValueRow(label: 'forefoot'.tr(), value: '48 kPa'),
        _PressureValueRow(label: 'midfoot'.tr(), value: '22 kPa'),
        _PressureValueRow(label: 'heel'.tr(), value: '71 kPa'),
        _PressureValueRow(label: 'average_pressure'.tr(), value: '47 kPa'),
      ],
    );
  }
}

class _PressureValueRow extends StatelessWidget {
  const _PressureValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        spacing: 2,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.titleMedium?.bold?.copyWith(
              fontFamily: 'Oxanium',
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  const _TodayStatusCard();

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return _AnalyticsCard(
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('today_status'.tr(), style: context.tt.titleSmall?.bold),
          Row(
            spacing: 16,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  LucideIcons.shieldCheck,
                  color: cs.onPrimaryContainer,
                  size: 34,
                ),
              ),
              Expanded(
                child: Column(
                  spacing: 4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'gait_stable'.tr(),
                      style: context.tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Oxanium',
                      ),
                    ),
                    Text(
                      'today_pressure_summary'.tr(),
                      style: context.tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
          Row(
            children: [
              Expanded(
                child: _StatusStat(
                  icon: LucideIcons.shieldCheck,
                  label: 'stability_score'.tr(),
                  value: '86',
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatusStat(
                  icon: LucideIcons.footprints,
                  label: 'fall_risk'.tr(),
                  value: 'low'.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusStat extends StatelessWidget {
  const _StatusStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Row(
      spacing: 10,
      children: [
        Icon(icon, color: cs.onSurfaceVariant, size: 28),
        Expanded(
          child: Column(
            spacing: 2,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: context.tt.titleMedium?.bold?.copyWith(
                  fontFamily: 'Oxanium',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.cs.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      shrinkWrap: true,
      childAspectRatio: 2.25,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _MetricTile(
          icon: LucideIcons.footprints,
          label: 'today_steps'.tr(),
          value: '3,842',
        ),
        _MetricTile(
          icon: LucideIcons.sun,
          label: 'outdoor_time'.tr(),
          value: 'duration_minutes'.tr(args: ['42']),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Card(
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          spacing: 8,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.onSurfaceVariant, size: 24),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: context.tt.titleLarge?.bold?.copyWith(
                          fontFamily: 'Oxanium',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressureAnalysisCard extends StatelessWidget {
  const _PressureAnalysisCard();

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      child: Column(
        spacing: 10,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pressure_analysis'.tr(), style: context.tt.titleSmall?.bold),
          _AnalysisRow(
            icon: LucideIcons.scale,
            label: 'left_right_balance'.tr(),
            value: 'slightly_right'.tr(),
            status: 'normal'.tr(),
            highlighted: false,
          ),
          _AnalysisRow(
            icon: LucideIcons.moveHorizontal,
            label: 'front_back_balance'.tr(),
            value: 'heel_biased'.tr(),
            status: 'notice'.tr(),
            highlighted: true,
          ),
          _AnalysisRow(
            icon: LucideIcons.circleDot,
            label: 'pressure_focus_area'.tr(),
            value: 'right_heel'.tr(),
            status: 'notice'.tr(),
            highlighted: true,
          ),
          _AnalysisRow(
            icon: LucideIcons.activity,
            label: 'gait_rhythm'.tr(),
            value: 'stable'.tr(),
            status: 'stable'.tr(),
            highlighted: false,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _AnalysisRow extends StatelessWidget {
  const _AnalysisRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.status,
    required this.highlighted,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final String status;
  final bool highlighted;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Column(
      children: [
        Row(
          spacing: 12,
          children: [
            Icon(icon, color: cs.onSurfaceVariant, size: 20),
            Expanded(child: Text(label, style: context.tt.bodyLarge)),
            Text(
              value,
              style: context.tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            _StatusBadge(text: status, highlighted: highlighted),
          ],
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 10),
            child: Divider(
              color: cs.outlineVariant.withValues(alpha: 0.45),
              height: 1,
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.highlighted});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return Container(
      constraints: const BoxConstraints(minWidth: 66),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? cs.primaryContainer.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: context.tt.labelMedium?.copyWith(
          color: highlighted ? cs.primary : cs.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StabilityTrendCard extends StatelessWidget {
  const _StabilityTrendCard({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final values = [58.0, 74.0, 66.0, 84.0, 76.0, 89.0, 78.0];

    return _AnalyticsCard(
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'seven_day_stability_trend'.tr(),
                  style: context.tt.titleSmall?.bold,
                ),
              ),
              _MiniToggle(
                labels: ['week'.tr(), 'month'.tr()],
                selectedIndex: selectedIndex,
                onSelected: onSelected,
              ),
            ],
          ),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                minX: 0,
                maxX: 6,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.28),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                    bottom: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 32,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: context.tt.labelSmall?.bold?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final labels = [
                          'mon'.tr(),
                          'tue'.tr(),
                          'wed'.tr(),
                          'thu'.tr(),
                          'fri'.tr(),
                          'sat'.tr(),
                          'sun'.tr(),
                        ];
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: context.tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < values.length; i++)
                        FlSpot(i.toDouble(), values[i]),
                    ],
                    color: cs.primary,
                    barWidth: 3,
                    isCurved: true,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 5,
                            color: cs.primaryContainer,
                            strokeWidth: 2,
                            strokeColor: cs.primary,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.primary.withValues(alpha: 0.24),
                          cs.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: context.cs.surfaceContainerHighest,
        selectedBackgroundColor: context.cs.primaryContainer,
        selectedForegroundColor: context.cs.onPrimaryContainer,
        foregroundColor: context.cs.onSurfaceVariant,
      ),
      segments: [
        for (var i = 0; i < labels.length; i++)
          ButtonSegment<int>(
            value: i,
            label: Text(
              labels[i],
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
      ],
      selected: {selectedIndex},
      onSelectionChanged: (selection) {
        onSelected(selection.first);
      },
    );
  }
}

class _CareSuggestionCard extends StatelessWidget {
  const _CareSuggestionCard({required this.suggestion});

  final String suggestion;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;

    return _AnalyticsCard(
      child: Row(
        spacing: 14,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.sparkles, color: cs.primary, size: 32),
          Expanded(
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ai_care_suggestion'.tr(),
                  style: context.tt.titleSmall?.bold,
                ),
                Text(
                  suggestion,
                  style: context.tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FootPressurePainter extends CustomPainter {
  const _FootPressurePainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    _drawInsole(canvas, Offset(size.width * 0.45, size.height * 0.5));
  }

  void _drawInsole(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 28);

    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2E67FF).withValues(alpha: 0.76),
          const Color(0xFF173D8C).withValues(alpha: 0.88),
        ],
      ).createShader(const Rect.fromLTWH(-46, -82, 92, 164));

    final outlinePaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.28)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final insole = Path()
      ..moveTo(-8, -78)
      ..cubicTo(-38, -72, -44, -42, -34, -8)
      ..cubicTo(-25, 22, -29, 61, -2, 78)
      ..cubicTo(20, 92, 42, 70, 37, 38)
      ..cubicTo(33, 13, 18, -7, 29, -36)
      ..cubicTo(39, -64, 18, -83, -8, -78)
      ..close();
    canvas.drawPath(insole, basePaint);
    canvas.drawPath(insole, outlinePaint);

    _drawHotSpot(canvas, const Offset(4, -40), 34, const [
      Color(0xFFFFED2E),
      Color(0xFF3FD764),
      Color(0xFF126BFF),
    ]);
    _drawHotSpot(canvas, const Offset(10, 44), 34, const [
      Color(0xFFFF2D20),
      Color(0xFFFFE735),
      Color(0xFF126BFF),
    ]);
    _drawHotSpot(canvas, const Offset(-16, -4), 24, const [
      Color(0xFF54D569),
      Color(0xFF126BFF),
    ]);

    canvas.restore();
  }

  void _drawHotSpot(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
  ) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..shader = RadialGradient(
        colors: [
          ...colors.map((color) => color.withValues(alpha: 0.9)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _FootPressurePainter oldDelegate) {
    return oldDelegate.colorScheme != colorScheme;
  }
}
