import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/chart/chart_section.dart';

class ImuChartSection extends ConsumerWidget {
  final ChardDisplayType type;
  final List<int> selectedList;

  const ImuChartSection({super.key, required this.type, this.selectedList = const []});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(telemetryViewProvider).recentImu;
    final recent = data.takeLast(20);
    List<FlSpot> buildSpots(num Function(ImuNotifyDataModel d) pick) =>
        List.generate(recent.length, (i) => FlSpot(i.toDouble(), pick(recent[i]).toDouble()), growable: false);

    final spotsList = [
      [buildSpots((d) => d.pressure)],
      [buildSpots((d) => d.ax), buildSpots((d) => d.ay), buildSpots((d) => d.az)],
      [buildSpots((d) => d.gx), buildSpots((d) => d.gy), buildSpots((d) => d.gz)],
      [buildSpots((d) => d.pitch ?? 0), buildSpots((d) => d.roll ?? 0)],
      [buildSpots((d) => d.batteryPercent)],
    ];

    const dataMax = [4500.0, 20000.0, 20000.0, 180.0, 100.0];
    const dataMin = [0.0, -20000.0, -20000.0, -180.0, 0.0];

    return ChardSection(
      type: type,
      data: data,
      selectedList: selectedList,
      dataMax: dataMax,
      dataMin: dataMin,
      spotsList: spotsList,
    );
  }
}
