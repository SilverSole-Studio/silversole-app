import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_status_model.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';
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

  // The sole as we currently know it. Refreshed on every (re)connection by
  // onReady, before any notify handler below can run.
  BlePairedDevice? boundDevice;

  // Only arms when arming the session itself fails (permission revoked, the
  // connectionState listener throwing). Connecting and reconnecting is the
  // service's own backoff loop — do not add a second one here.
  Timer? retryTimer;
  var retryAttempt = 0;

  // A wire-format mismatch fails on every packet, so throttle the failure log
  // and carry the raw bytes — the payload is what identifies the wrong format.
  var imuFailCount = 0;
  String toHex(List<int> v) =>
      v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  void onImu(List<int> value) {
    try {
      final data = bleConnectionService.parseImuNotify(value);
      live.updateImuNotifyData(data);
    } catch (e) {
      // Always report the first failure, then throttle: a format mismatch
      // fails on every packet and would spam ~20 lines/s.
      imuFailCount++;
      if (imuFailCount == 1 || imuFailCount % 20 == 0) {
        debugPrint(
          'parse notify FAILED #$imuFailCount len=${value.length} '
          'hex=[${toHex(value)}] err=$e',
        );
      }
    }
  }

  void onRecordImu(List<int> value) {
    try {
      final json = bleConnectionService.parseJsonNotify(value);
      final data = RecordImuNotifyDataModel.fromJson(json);
      live.updateRecordImuNotifyData(data);
      debugPrint('record notify: $data');
    } catch (e) {
      debugPrint('parse record notify failed: $e');
    }
  }

  void onFallDetect(List<int> value) {
    try {
      if (utf8.decode(value) != '1') return;
      final deviceId = boundDevice?.deviceId;
      if (deviceId == null) return;
      ref
          .read(fallEventBusProvider)
          .emit(
            FallDetectEvent(
              timestamp: DateTime.now(),
              deviceId: deviceId,
              detect: true,
            ),
          );
    } catch (e) {
      debugPrint('parse fall detect failed: $e');
    }
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

  Future<void> onDeviceStatus(List<int> value) async {
    final device = boundDevice;
    if (device == null) return;
    try {
      final payload = bleConnectionService.parseJsonNotify(value);
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

  // attach and scheduleRetry call each other, and Dart has no forward
  // references for local functions — so one of the pair has to be a variable.
  late final Future<void> Function(BlePairedDevice device) attach;

  void scheduleRetry(BlePairedDevice device) {
    retryTimer?.cancel();
    // 2, 4, 8, 16, 30, 30… — a failed attach means the adapter or the
    // permission is unavailable, so back off instead of hammering it.
    final seconds = math.min(1 << (retryAttempt + 1), 30);
    retryAttempt++;
    debugPrint('sole attach retry in ${seconds}s');
    retryTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(attach(device)),
    );
  }

  attach = (BlePairedDevice device) async {
    retryTimer?.cancel();
    boundDevice = device;

    final granted = await ensureConnectPermission();
    if (!granted) {
      debugPrint('bluetoothConnect permission denied'.tr());
      scheduleRetry(device);
      return;
    }

    await startBleService();

    final result = await bleConnectionService.attach(
      device,
      handlers: BleSessionHandlers(
        onImu: onImu,
        onRecordImu: onRecordImu,
        onFallDetect: onFallDetect,
        onDeviceStatus: (value) => unawaited(onDeviceStatus(value)),
        onReady: (deviceId) {
          // Persist the moment we (re)connected so the status card can show a
          // real "last connected" time. Same remoteId, so this does not
          // re-trigger the preferredDevice listener.
          final updated = (boundDevice ?? device).copyWith(
            deviceId: deviceId ?? boundDevice?.deviceId,
            lastConnectedAt: DateTime.now(),
          );
          boundDevice = updated;
          unawaited(settings.addOrUpdatePairedDevice(updated));
          debugPrint('sole session ready: deviceId=${updated.deviceId}');
        },
        onDisconnected: (reason) => debugPrint('sole disconnected: $reason'),
      ),
    );

    switch (result) {
      case Error():
        debugPrint('sole attach failed: ${result.error}');
        scheduleRetry(device);
      case Ok():
        retryAttempt = 0;
        debugPrint('sole session attached');
    }
  };

  ref.listen<BlePairedDevice?>(
    settingsProvider.select((s) => s.preferredDevice),
    (prev, next) {
      if (prev?.remoteId == next?.remoteId) return;

      retryTimer?.cancel();
      retryAttempt = 0;
      boundDevice = null;

      if (next == null) {
        unawaited(
          bleConnectionService.detach().whenComplete(() => stopBleService()),
        );
        return;
      }

      unawaited(attach(next));
    },
    fireImmediately: true,
  );
});
