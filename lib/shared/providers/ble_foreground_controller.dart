import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

import 'settings_provider.dart';

final bleForegroundControlProvider = Provider<void>((ref) {
  // Check platform
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final bleConnectionService = ref.read(bleConnectProvider);
  final settings = ref.read(settingsProvider.notifier);
  final live = ref.read(liveTelemetryProvider.notifier);

  Timer? reconnectTimer;
  bool connecting = false;

  void onData(List<int> value) {
    final json = bleConnectionService.parseImuNotify(value);
    final data = ImuNotifyDataModel.fromJson(json);
    live.updateImuNotifyData(data);
    debugPrint('notify: $data');
  }

  void onRecordData(List<int> value) {
    final json = bleConnectionService.parseImuNotify(value);
    final data = ImuNotifyDataModel.fromJson(json);
    live.updateRecordImuNotifyData(data);
    debugPrint('record notify: $data');
  }

  Future<bool> ensureConnectPermission() async {
    final stats = await Permission.bluetoothConnect.request();
    return stats.isGranted;
  }

  Future<void> tryAutoConnect(BlePairedDevice device) async {
    if (connecting) return;
    connecting = true;
    try {
      // Permission
      final granted = await ensureConnectPermission();
      if (!granted) {
        debugPrint('bluetoothConnect permission denied'.tr());
        return;
      }

      await startBleService();

      // Read IMU data
      final imuResult = await bleConnectionService.subscribeNotify(
        device,
        serviceUuid: serviceUuid,
        characteristicUuid: notifyCharUuid,
        onData: (value) {
          try {
            onData(value);
          } catch (e) {
            debugPrint('parse notify failed: $e');
          }
        },
      );

      switch (imuResult) {
        case Error():
          debugPrint('subscribe_failed ${imuResult.error}');
          break;
        case Ok():
          debugPrint('auto connect success');
      }

      // Read record IMU data
      final recordImuResult = await bleConnectionService.subscribeNotify(
        device,
        serviceUuid: serviceUuid,
        characteristicUuid: recordNotifyCharUuid,
        onData: (value) {
          try {
            onRecordData(value);
          } catch (e) {
            debugPrint('parse record notify failed: $e');
          }
        }
      );

      switch (recordImuResult) {
        case Error():
          debugPrint('record_subscribe_failed ${recordImuResult.error}');
          break;
        case Ok():
          debugPrint('auto connect success');
      }

      // Read device ID
      final deviceIdResult = await bleConnectionService.readStringCharacteristic(
        device,
        serviceUuid: serviceUuid,
        characteristicUuid: deviceIdCharUuid,
      );
      switch (deviceIdResult) {
        case Error():
          debugPrint('read device id failed: ${deviceIdResult.error}');
        case Ok():
          unawaited(settings.addOrUpdatePairedDevice(device.copyWith(deviceId: deviceIdResult.value)));
          debugPrint('device id: ${deviceIdResult.value}');
      }
    } finally {
      connecting = false;
    }
  }

  ref.listen<BlePairedDevice?>(settingsProvider.select((s) => s.preferredDevice), (prev, next) {
    reconnectTimer?.cancel();

    // Disconnect
    if (prev != null) unawaited(bleConnectionService.disconnect(prev));
    if (next == null) {
      unawaited(stopBleService());
      return;
    }

    unawaited(tryAutoConnect(next));
    reconnectTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!bleConnectionService.checkConnect(next)) unawaited(tryAutoConnect(next));
    });
  }, fireImmediately: true);
});
