import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/live_telemetry_notifier.dart';

import 'settings_provider.dart';

const _serviceUuid = '83BFF893-8E7C-4530-9BB8-18EBA983E660';
const _notifyCharUuid = 'B8863299-8492-4C76-ACF4-514965B1A747';
const _deviceIdCharUuid = 'A761F782-3754-4EBA-9169-0CCD314590A2';

final bleForegroundControlProvider = Provider<void>((ref) {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final bleConnectionService = ref.read(bleConnectProvider);
  final settings = ref.read(settingsProvider.notifier);
  final live = ref.read(liveTelemetryProvider.notifier);

  ref.listen<BlePairedDevice?>(settingsProvider.select((s) => s.preferredDevice), (prev, next) {
    if (prev?.remoteId == next?.remoteId) return;
    if (next != null) {
      unawaited(() async {
        if (prev != null && prev.remoteId != next.remoteId) {
          await bleConnectionService.disconnect(prev);
        }
        await startBleService();
        final result = await bleConnectionService.reconnectIfNeed(
          next,
          serviceUuid: _serviceUuid,
          characteristicUuid: _notifyCharUuid,
          onData: (value) {
            try {
              final json = bleConnectionService.parseImuNotify(value);
              final data = ImuNotifyDataModel.fromJson(json);
              live.updateImuNotifyData(data);
              debugPrint('notify: $data');
            } catch (e) {
              debugPrint('parse notify failed: $e');
            }
          },
        );

        switch (result) {
          case Error():
            debugPrint('subscribe failed: ${result.error}');
          case Ok():
            break;
        }

        final deviceIdResult = await bleConnectionService.readStringCharacteristic(
          next,
          serviceUuid: _serviceUuid,
          characteristicUuid: _deviceIdCharUuid,
        );

        switch (deviceIdResult) {
          case Error():
            debugPrint('read device id failed: ${deviceIdResult.error}');
          case Ok():
            unawaited(settings.addOrUpdatePairedDevice(next.copyWith(deviceId: deviceIdResult.value)));
            debugPrint('device id: ${deviceIdResult.value}');
        }

      }());
    } else {
      if (prev != null) unawaited(bleConnectionService.disconnect(prev));
      unawaited(stopBleService());
    }
  }, fireImmediately: true);
});
