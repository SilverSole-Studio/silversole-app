import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/telemetry_view_provider.dart';

import '../providers/settings_provider.dart';

class RecentDataChartCard extends ConsumerStatefulWidget {
  const RecentDataChartCard({super.key});

  @override
  ConsumerState<RecentDataChartCard> createState() => _RecentDataChartCardState();
}

class _RecentDataChartCardState extends ConsumerState<RecentDataChartCard> {
  // final List<int> _pressuresDataList = [];
  ProviderSubscription<AppSettings>? _sub;
  bool _loaded = false;

  Future<void> getRecentPressureData() async {
    final userProvider = ref.read(authUserProvider);
    final settings = ref.read(settingsProvider);
    if (userProvider == null) {
      showErrorSnakeBar('not_signed_in'.tr());
      return;
    }
    if (settings.deviceId == null) {
      showErrorSnakeBar('not_binding'.tr());
      return;
    }
    debugPrint('getRecentData');
    // final viewProvider = ref.watch(telemetryViewProvider);
    // _pressuresDataList = data.take(20);
    // debugPrint(result.toString());

    // switch (result) {
    //   case Ok<List<SilverSoleRecordModel>>():
    //     if (mounted) {
    //       setState(() => _pressuresDataList.clear());
    //       setState(() => _pressuresDataList.addAll(result.value.map((it) => it.pressure).toList()));
    //       showMessage('get_data_success'.tr());
    //     }
    //   case Error():
    //     return showErrorSnakeBar(result.error.toString());
    // }
  }

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<AppSettings>(settingsProvider, (prev, next) {
      final id = next.deviceId;
      if (!_loaded && id != null && id.isNotEmpty) {
        _loaded = true;
        getRecentPressureData();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final viewProvider = ref.watch(telemetryViewProvider);
    final data = viewProvider.recent;
    final recent = viewProvider.recent.skip((data.length - 20).clamp(0, data.length)).toList(growable: false);

    List<FlSpot> buildSpots(num Function(ImuNotifyDataModel d) pick) =>
        List.generate(recent.length, (i) => FlSpot(i.toDouble(), pick(recent[i]).toDouble()), growable: false);

    Color getColor(int i) => Colors.accents[i % Colors.accents.length];

    final labels = ['pressure', 'ax', 'ay', 'az', 'gx', 'gy', 'gz', 'battery'];

    final spots = <List<FlSpot>>[
      buildSpots((d) => d.pressure),
      buildSpots((d) => d.ax),
      buildSpots((d) => d.ay),
      buildSpots((d) => d.az),
      buildSpots((d) => d.gx),
      buildSpots((d) => d.gy),
      buildSpots((d) => d.gz),
      buildSpots((d) => d.batteryPercent),
    ];

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        child: InkWell(
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 18,
              children: [
                Text('device_recent_data'.tr(), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                      ),
                      maxY: 20000,
                      lineBarsData: [
                        for (int i = 0; i < spots.length; i++)
                          LineChartBarData(
                            spots: spots[i],
                            isCurved: true,
                            color: Colors.accents[i % Colors.accents.length],
                            dotData: const FlDotData(show: false),
                          ),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < labels.length; i++)
                      Chip(
                        avatar: CircleAvatar(backgroundColor: getColor(i), radius: 5,),
                        label: Text(labels[i]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
