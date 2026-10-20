import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';
import 'package:silversole/shared/widgets/status_card.dart';

import '../providers/telemetry_process_providers/device_online_provider.dart';
import '../providers/telemetry_process_providers/live_telemetry_notifier.dart';
import '../providers/telemetry_process_providers/telemetry_facade_provider.dart';

/// The home screen's card for one sole.
///
/// Reads [device]'s own stream rather than the primary sole's: the card is
/// titled with this sole's name, and showing another foot's battery or calling
/// it online because the *other* sole is streaming would name one sole and
/// report a second.
class HomeDeviceStatusSection extends ConsumerWidget {
  const HomeDeviceStatusSection({super.key, required this.device});

  final BlePairedDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Value unused on purpose: checkDeviceOnline compares against the clock,
    // and nothing rebuilds when a sole goes silent. Watching this provider is
    // what re-runs build when its timer fires.
    ref.watch(deviceOnlineProvider);
    final telemetry = ref.watch(liveTelemetryProvider(device.identityKey));
    final lastest = telemetry.recentImu.isNotEmpty
        ? telemetry.recentImu.last
        : null;
    final detail = DeviceStatusDetailModel(
      lastHeartbeatAt: telemetry.updatedAt,
      lastBatteryAt: telemetry.updatedAt,
      lastBatteryPercent: lastest?.batteryPercent,
      isCharging: lastest?.isCharging,
    );

    return DeviceStatusCard(
      name: device.name,
      type: StatusCardType.statusDisplay,
      model: device.displayModel ?? 'unknown_model'.tr(),
      id: device.deviceId ?? device.remoteId,
      activeDisplay: true,
      frosted: true,
      active: ref
          .watch(telemetryFacadeProvider)
          .checkDeviceOnline(telemetry.updatedAt),
      detail: detail,
      lastConnectedAt: device.lastConnectedAt,
      lastKnownBatteryPercent: device.lastBatteryPercent,
      onClick: () => context.push('/my-devices'),
    );
  }
}
