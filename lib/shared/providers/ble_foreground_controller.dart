import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_status_model.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/device_status_ingest_provider.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

import 'settings_provider.dart';

final bleForegroundControlProvider = Provider<void>((ref) {
  // Check platform
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final bleConnectionService = ref.read(bleConnectProvider);
  final deviceStatusIngestService = ref.read(deviceStatusIngestProvider);
  final settings = ref.read(settingsProvider.notifier);
  final live = ref.read(liveTelemetryProvider.notifier);

  Timer? reconnectTimer;
  bool connecting = false;

  void onData(List<int> value) {
    final json = bleConnectionService.parseImuNotify(value);
    final data = ImuNotifyDataModel.fromJson(json);
    live.updateImuNotifyData(data);
    // debugPrint('notify: $data');
  }

  void onRecordData(List<int> value) {
    final json = bleConnectionService.parseImuNotify(value);
    final data = RecordImuNotifyDataModel.fromJson(json);
    live.updateRecordImuNotifyData(data);
    debugPrint('record notify: $data');
  }

  void onFallDetect(List<int> value, String deviceId) {
    final isFall = utf8.decode(value) == "1";
    if (!isFall) return;
    ref
        .read(fallEventBusProvider)
        .emit(
          FallDetectEvent(
            timestamp: DateTime.now(),
            deviceId: deviceId,
            detect: true,
          ),
        );
  }

  bool isDeviceStatusTimestampValid(
    int timestampMs, {
    Duration tolerance = const Duration(minutes: 10),
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffMs = (timestampMs - nowMs).abs();
    debugPrint('device status diffMs=$diffMs');
    return diffMs <= tolerance.inMilliseconds;
  }

  Future<void> onDeviceStatus(BlePairedDevice device, List<int> value) async {
    try {
      final payload = bleConnectionService.parseImuNotify(value);
      final status = DeviceStatusModel.fromJson(payload);
      if (!isDeviceStatusTimestampValid(status.timestamp)) {
        debugPrint('device status timestamp invalid: ${status.timestamp}');
        return;
      }
      final result = await deviceStatusIngestService.ingestDeviceStatus(
        device: device,
        payload: status,
      );

      switch (result) {
        case Error():
          throw result.error;
        case Ok():
          break;
      }
    } catch (e) {
      debugPrint('device status ingest failed: $e');
    }
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
          return;
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
        },
      );

      switch (recordImuResult) {
        case Error():
          debugPrint('record_subscribe_failed ${recordImuResult.error}');
          return;
        case Ok():
          debugPrint('auto connect success');
      }

      // Read device ID
      final deviceIdResult = await bleConnectionService
          .readStringCharacteristic(
            device,
            serviceUuid: serviceUuid,
            characteristicUuid: deviceIdCharUuid,
          );
      var boundDevice = device;
      switch (deviceIdResult) {
        case Error():
          debugPrint('read device id failed: ${deviceIdResult.error}');
          return;
        case Ok():
          boundDevice = device.copyWith(deviceId: deviceIdResult.value);
          unawaited(settings.addOrUpdatePairedDevice(boundDevice));
          debugPrint('device id: ${deviceIdResult.value}');
      }
      final deviceId = boundDevice.deviceId!;

      // Write base timestamp
      final timestampResult = await bleConnectionService.writeBaseTimestamp(
        device,
      );
      switch (timestampResult) {
        case Error():
          debugPrint('write base timestamp failed: ${timestampResult.error}');
          return;
        case Ok():
          debugPrint('base timestamp synced');
      }

      // Read fall detect
      final fallDetectResult = await bleConnectionService.subscribeNotify(
        device,
        serviceUuid: serviceUuid,
        characteristicUuid: fallDetectCharUuid,
        onData: (value) {
          try {
            onFallDetect(value, deviceId);
          } catch (e) {
            debugPrint('parse fall detect failed: $e');
          }
        },
      );

      switch (fallDetectResult) {
        case Error():
          debugPrint('fall_detect_subscribe_failed ${fallDetectResult.error}');
          return;
        case Ok():
          debugPrint('auto connect success');
      }

      final deviceStatusResult = await bleConnectionService.subscribeNotify(
        device,
        serviceUuid: serviceUuid,
        characteristicUuid: deviceStatusCharUuid,
        onData: (value) async {
          try {
            await onDeviceStatus(boundDevice, value);
          } catch (e) {
            debugPrint('parse device status failed: $e');
          }
        },
      );

      switch (deviceStatusResult) {
        case Error():
          debugPrint(
            'device_status_subscribe_failed ${deviceStatusResult.error}',
          );
          return;
        case Ok():
          debugPrint('device status subscribe success');
      }
    } finally {
      connecting = false;
    }
  }

  ref.listen<BlePairedDevice?>(
    settingsProvider.select((s) => s.preferredDevice),
    (prev, next) {
      if (prev?.remoteId == next?.remoteId) return;

      reconnectTimer?.cancel();

      // Disconnect
      if (prev != null) unawaited(bleConnectionService.disconnect(prev));
      if (next == null) {
        unawaited(stopBleService());
        return;
      }

      unawaited(tryAutoConnect(next));
      reconnectTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!bleConnectionService.checkConnect(next)) {
          unawaited(tryAutoConnect(next));
        }
      });
    },
    fireImmediately: true,
  );
});
