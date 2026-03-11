import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';

enum ChardDisplayType { all, single, optional }
enum ChardDataSource { imu, recordImu }

class ChardSection extends ConsumerStatefulWidget {
  final ChardDataSource source;
  final ChardDisplayType type;
  final List<int> selectedList;

  const ChardSection({super.key, required this.type, this.selectedList = const [], this.source = ChardDataSource.imu});

  @override
  ConsumerState<ChardSection> createState() => _ChardSectionState();
}

class _ChardSectionState extends ConsumerState<ChardSection> {
  Color getColor(int i) => Colors.accents[i % Colors.accents.length];

  static const _dataMax = [4500.0, 20000.0, 20000.0, 100.0];
  static const _dataMin = [0.0, -20000.0, -20000.0, 0.0];

  double getMaxY() {
    try {
      switch (widget.type) {
        case ChardDisplayType.all:
          return _dataMax.max;
        case ChardDisplayType.single:
          return _dataMax[widget.selectedList[0]];
        case ChardDisplayType.optional:
          final selected = _dataMax.whereIndexed((i, _) => widget.selectedList.contains(i)).toList();
          return (selected.isNotEmpty ? selected : [_dataMax[0]]).max;
      }
    } catch (e) {
      return 0.0;
    }
  }

  double getMinY() {
    try {
      switch (widget.type) {
        case ChardDisplayType.all:
          return _dataMin.min;
        case ChardDisplayType.single:
          return _dataMin[widget.selectedList[0]];
        case ChardDisplayType.optional:
          final selected = _dataMin.whereIndexed((i, _) => widget.selectedList.contains(i)).toList();
          return (selected.isNotEmpty ? selected : [_dataMin[0]]).min;
      }
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewProvider = ref.watch(telemetryViewProvider);
    final data = switch (widget.source) {
      ChardDataSource.imu => viewProvider.recentImu,
      ChardDataSource.recordImu => viewProvider.record,
    };
    final recent = data.skip((data.length - 20).clamp(0, data.length)).toList(growable: false);

    List<FlSpot> buildSpots(num Function(ImuNotifyDataModel d) pick) =>
        List.generate(recent.length, (i) => FlSpot(i.toDouble(), pick(recent[i]).toDouble()), growable: false);

    final spotsList = [
      [buildSpots((d) => d.pressure)],
      [buildSpots((d) => d.ax), buildSpots((d) => d.ay), buildSpots((d) => d.az)],
      [buildSpots((d) => d.gx), buildSpots((d) => d.gy), buildSpots((d) => d.gz)],
      [buildSpots((d) => d.batteryPercent)],
    ];

    final filteredSpotsList = widget.type == ChardDisplayType.all
        ? spotsList
        : spotsList.whereIndexed((i, _) => widget.selectedList.contains(i)).toList();

    return ClipRect(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            titlesData: FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
            ),
            maxY: getMaxY(),
            minY: getMinY(),
            lineBarsData: [
              for (int i = 0 ; i < filteredSpotsList.length ; i++)
                for (int j = 0; j < filteredSpotsList[i].length; j++)
                  LineChartBarData(
                    spots: filteredSpotsList[i][j],
                    isCurved: true,
                    color: getColor(i + j),
                    dotData: const FlDotData(show: false),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
