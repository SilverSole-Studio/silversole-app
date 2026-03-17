import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';
import 'package:silversole/shared/widgets/status_card.dart';

import '../providers/telemetry_process_providers/telemetry_view_provider.dart';

class HomeDeviceStatusSection extends ConsumerWidget {
  const HomeDeviceStatusSection({
    super.key,
    required this.device,
  });

  final BlePairedDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewProvider = ref.watch(telemetryViewProvider);
    final lastest = viewProvider.recentImu.isNotEmpty ? viewProvider.recentImu.last : null;
    final detail = DeviceStatusDetailModel(
      lastHeartbeatAt: viewProvider.updatedAt,
      lastBatteryAt: viewProvider.updatedAt,
      lastBatteryPercent: lastest?.batteryPercent,
      isCharging: lastest?.isCharging,
    );

    return DeviceStatusCard(
      name: device.name,
      type: StatusCardType.statusDisplay,
      model: device.displayModel ?? 'unknown_model'.tr(),
      id: device.remoteId,
      activeDisplay: true,
      detail: detail,
    );
  }
}