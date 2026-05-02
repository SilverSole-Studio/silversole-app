import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/widgets/chart/chart_section.dart';
import 'package:silversole/shared/widgets/chart/imu_chart_section.dart';

import '../providers/settings_provider.dart';

class RecentDataChartCard extends ConsumerStatefulWidget {
  const RecentDataChartCard({super.key});

  @override
  ConsumerState<RecentDataChartCard> createState() =>
      _RecentDataChartCardState();
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
    Color getColor(int i) => Colors.accents[i % Colors.accents.length];
    final labels = [
      'pressure',
      'ax',
      'ay',
      'az',
      'gx',
      'gy',
      'gz',
      'pitch',
      'roll',
      'battery',
    ];

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => context.push('/analytics-detail'),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 18,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'device_recent_data'.tr(),
                        style: context.tt.titleSmall.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/analytics-detail'),
                      child: Text('view'.tr()),
                    ),
                  ],
                ),
                ImuChartSection(type: ChardDisplayType.all),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < labels.length; i++)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: getColor(i),
                          radius: 5,
                        ),
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
