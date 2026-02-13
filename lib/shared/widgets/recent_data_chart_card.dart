import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/sole_record_data_model.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/sole_provider.dart';

import '../providers/settings_provider.dart';

class RecentDataChartCard extends ConsumerStatefulWidget {
  const RecentDataChartCard({super.key});

  @override
  ConsumerState<RecentDataChartCard> createState() => _RecentDataChartCardState();
}

class _RecentDataChartCardState extends ConsumerState<RecentDataChartCard> {
  final List<int> _pressuresDataList = [];
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
    final soleService = ref.read(soleProvider);
    debugPrint('getRecentData');
    final result = await soleService.getRecentDeviceData(deviceId: settings.deviceId ?? '', limit: 20);
    debugPrint(result.toString());

    switch (result) {
      case Ok<List<SilverSoleRecordModel>>():
        if (mounted) {
          setState(() => _pressuresDataList.clear());
          setState(() => _pressuresDataList.addAll(result.value.map((it) => it.pressure).toList()));
          showMessage('get_data_success'.tr());
        }
      case Error():
        return showErrorSnakeBar(result.error.toString());
    }
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
    final settings = ref.watch(settingsProvider);
    final isBinding = settings.deviceId != null;
    final spots = _pressuresDataList.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: InkWell(
          onTap: getRecentPressureData,
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
