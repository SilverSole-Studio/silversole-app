import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

class RecentDataChartCard extends ConsumerStatefulWidget {
  const RecentDataChartCard({super.key});

  @override
  ConsumerState<RecentDataChartCard> createState() => _RecentDataChartCardState();
}

class _RecentDataChartCardState extends ConsumerState<RecentDataChartCard> {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final isBinding = settings.deviceId != null;

    final fakeData = [
      380,
      920,
      640,
      1480,
      1120,
      2150,
      1760,
      2980,
      2620,
      3450,
      3100,
      4020,
      3550,
      4200,
      3000,
      3650,
      2400,
      2850,
      1900,
      520,
    ];

    final spots = fakeData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: InkWell(
          // onTap: comingSoon,
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
                if (!isBinding)
                  // Center(child: hintBindingPage())
                  const SizedBox.shrink()
                else ...[
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
                        maxY: 4500,

                        lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: Colors.blue)],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
