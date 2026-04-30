import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChardDisplayType { all, single, optional }

enum ChardDataSource { imu, recordImu }

class ChardSection extends ConsumerStatefulWidget {
  static const int defaultVisiblePointCount = 20;

  final ChardDataSource source;
  final ChardDisplayType type;
  final List<dynamic> data;
  final List<double> dataMax;
  final List<double> dataMin;
  final List<List<List<FlSpot>>> spotsList;
  final List<int> selectedList;
  final int visiblePointCount;

  const ChardSection({
    super.key,
    required this.type,
    required this.data,
    required this.spotsList,
    required this.dataMax,
    required this.dataMin,
    this.selectedList = const [],
    this.source = ChardDataSource.imu,
    this.visiblePointCount = defaultVisiblePointCount,
  });

  @override
  ConsumerState<ChardSection> createState() => _ChardSectionState();
}

class _ChardSectionState extends ConsumerState<ChardSection> {
  Color getColor(int i) => Colors.accents[i % Colors.accents.length];

  double getMaxY() {
    try {
      switch (widget.type) {
        case ChardDisplayType.all:
          return widget.dataMax.max;
        case ChardDisplayType.single:
          return widget.dataMax[widget.selectedList[0]];
        case ChardDisplayType.optional:
          final selected = widget.dataMax
              .whereIndexed((i, _) => widget.selectedList.contains(i))
              .toList();
          return (selected.isNotEmpty ? selected : [widget.dataMax[0]]).max;
      }
    } catch (e) {
      return 0.0;
    }
  }

  double getMinY() {
    try {
      switch (widget.type) {
        case ChardDisplayType.all:
          return widget.dataMin.min;
        case ChardDisplayType.single:
          return widget.dataMin[widget.selectedList[0]];
        case ChardDisplayType.optional:
          final selected = widget.dataMin
              .whereIndexed((i, _) => widget.selectedList.contains(i))
              .toList();
          return (selected.isNotEmpty ? selected : [widget.dataMin[0]]).min;
      }
    } catch (e) {
      return 0.0;
    }
  }

  List<T> getRecentList<T>(List<T> data, int count) => data
      .skip((data.length - count).clamp(0, data.length))
      .toList(growable: false);

  double getMinX() {
    final totalCount = widget.data.length;
    if (totalCount <= widget.visiblePointCount) return 0;
    return (totalCount - widget.visiblePointCount).toDouble();
  }

  double getMaxX() {
    final totalCount = widget.data.length;
    if (totalCount <= widget.visiblePointCount) {
      return (widget.visiblePointCount - 1).toDouble();
    }
    return (totalCount - 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSpotsList = widget.type == ChardDisplayType.all
        ? widget.spotsList
        : widget.spotsList
              .whereIndexed((i, _) => widget.selectedList.contains(i))
              .toList();

    return ClipRect(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            titlesData: FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true),
              ),
            ),
            minX: getMinX(),
            maxX: getMaxX(),
            maxY: getMaxY(),
            minY: getMinY(),
            lineBarsData: () {
              var colorIndex = 0;
              final bars = <LineChartBarData>[];

              for (final group in filteredSpotsList) {
                for (final spots in group) {
                  bars.add(
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: getColor(colorIndex++),
                      dotData: const FlDotData(show: false),
                    ),
                  );
                }
              }

              return bars;
            }(),
          ),
          duration: const Duration(milliseconds: 120),
          curve: Curves.linear,
        ),
      ),
    );
  }
}
