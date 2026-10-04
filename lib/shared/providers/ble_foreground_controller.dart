import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/battery_level.dart';
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

  final scanner = SoleScanner();

  // Re-arms the search: nothing advertising, a permission refused, or arming
  // the session itself failing. Reconnecting to the sole we already found is
  // the service's own backoff loop — do not add a second one here.
  Timer? retryTimer;

  // Fires when a session never connects, or does not come back after a link
  // loss — which is what a rebooted sole's new MAC looks like from here.
  Timer? watchdogTimer;
  var searching = false;
  var searchAttempt = 0;

  // A wire-format mismatch fails on every packet, so throttle the failure log
  // and carry the raw bytes — the payload is what identifies the wrong format.
  var imuFailCount = 0;
  String toHex(List<int> v) =>
      v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  // Persists the sole's battery level so it can be shown greyed out while the
  // sole is offline. The IMU stream repeats the same level at 50 Hz, so only a
  // change is written; boundDevice carries it so onReady's write keeps it.
  void rememberBattery(int percent) {
    final device = boundDevice;
    if (device == null || !percent.isValidBatteryPercent) return;
    if (device.lastBatteryPercent == percent) return;
    boundDevice = device.copyWith(lastBatteryPercent: percent);
    unawaited(settings.setLastBatteryPercent(device.remoteId, percent));
  }

  void onImu(List<int> value) {
    try {
      final data = bleConnectionService.parseImuNotify(value);
      live.updateImuNotifyData(data);
      rememberBattery(data.batteryPercent);
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
      rememberBattery(status.body.batteryPercent);
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

  /// Mirrors the pairing sheet's request. This only ever runs once the user has
  /// paired a sole by hand, so both prompts have already been seen by then.
  Future<bool> ensureScanPermission() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();
    return statuses[Permission.bluetoothScan]?.isGranted ?? false;
  }

  // searchAndAttach and the two timers below call each other, and Dart has no
  // forward references for local functions — so one of them has to be a
  // variable.
  late final Future<void> Function({bool force}) searchAndAttach;

  /// 15, 30, then 60 s between searches, so a sole that is simply switched off
  /// does not keep a low-latency scan running every 15 s all day. Reset once a
  /// session is ready.
  void scheduleSearch() {
    const delays = [15, 30, 60];
    retryTimer?.cancel();
    final seconds =
        delays[searchAttempt < delays.length
            ? searchAttempt
            : delays.length - 1];
    searchAttempt++;
    debugPrint('sole search again in ${seconds}s');
    retryTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(searchAndAttach()),
    );
  }

  /// Gives [BleConnectionService]'s own fast reconnect a window to bring the
  /// same MAC back. When it cannot, the sole has most likely rebooted — it
  /// advertises a different MAC then, and only a fresh scan can find it.
  void armWatchdog([Duration delay = const Duration(seconds: 30)]) {
    watchdogTimer?.cancel();
    watchdogTimer = Timer(delay, () {
      if (bleConnectionService.isConnected) return;
      debugPrint('sole did not connect — searching again');
      unawaited(searchAndAttach());
    });
  }

  /// Finds whichever sole is actually advertising and connects to it.
  ///
  /// The sole's MAC changes on every boot, so the remembered primary device is
  /// a hint, not a target: scanning is what tells us which sole exists right
  /// now. [force] is the manual primary-device pick asking us to look even
  /// though a session is already up.
  searchAndAttach = ({bool force = false}) async {
    if (searching) return;
    if (!force && bleConnectionService.isConnected) return;

    searching = true;
    retryTimer?.cancel();
    watchdogTimer?.cancel();
    try {
      final current = ref.read(settingsProvider);
      // Never reach for a stranger's sole: auto-connect starts only once the
      // user has paired one by hand.
      if (current.pairedDevicesList.isEmpty) {
        boundDevice = null;
        await bleConnectionService.detach();
        await stopBleService();
        return;
      }

      if (!await ensureConnectPermission() || !await ensureScanPermission()) {
        debugPrint('ble permission denied');
        scheduleSearch();
        return;
      }

      await startBleService();

      final pick = pickSole(
        await scanner.scan(),
        preferredRemoteId: current.preferredDevice?.remoteId,
      );
      if (pick == null) {
        debugPrint('no sole advertising');
        scheduleSearch();
        return;
      }
      debugPrint('sole found: $pick');

      // Reuse the stored entry when this MAC is already known, so its name and
      // device id survive; a rebooted sole simply arrives as a new MAC.
      final known = current.pairedDevicesList.firstWhereOrNull(
        (d) => d.remoteId == pick.remoteId,
      );
      final device =
          known ??
          BlePairedDevice(
            remoteId: pick.remoteId,
            name: pick.name,
            lastRssi: pick.rssi,
          );
      boundDevice = device;

      final result = await bleConnectionService.attach(
        device,
        handlers: BleSessionHandlers(
          onImu: onImu,
          onRecordImu: onRecordImu,
          onFallDetect: onFallDetect,
          onDeviceStatus: (value) => unawaited(onDeviceStatus(value)),
          onReady: (deviceId) {
            // Connected and handshaked: the watchdog has nothing to rescue and
            // the next search starts from the short delay again.
            watchdogTimer?.cancel();
            searchAttempt = 0;
            // Persist the moment we (re)connected so the status card can show a
            // real "last connected" time. The listener below ignores timestamp
            // changes, so this does not restart the search.
            final updated = (boundDevice ?? device).copyWith(
              deviceId: deviceId ?? boundDevice?.deviceId,
              lastConnectedAt: DateTime.now(),
            );
            boundDevice = updated;
            unawaited(settings.addOrUpdatePairedDevice(updated));
            debugPrint('sole session ready: deviceId=${updated.deviceId}');
          },
          onDisconnected: (reason) {
            debugPrint('sole disconnected: $reason');
            armWatchdog();
          },
        ),
      );

      switch (result) {
        case Error():
          debugPrint('sole attach failed: ${result.error}');
          scheduleSearch();
        case Ok():
          debugPrint('sole session attached');
          armWatchdog();
      }
    } finally {
      searching = false;
    }
  };

  // The primary-device pick and "is anything paired at all" are the only
  // settings that change what we should be connected to. Every reconnect
  // rewrites the paired entry's timestamp, which this selector ignores on
  // purpose — otherwise each reconnect would kick off another search.
  ref.listen<({String? preferredId, int pairedCount})>(
    settingsProvider.select(
      (s) => (
        preferredId: s.preferredDevice?.remoteId,
        pairedCount: s.pairedDevicesList.length,
      ),
    ),
    (prev, next) {
      if (next.pairedCount == 0) {
        retryTimer?.cancel();
        watchdogTimer?.cancel();
        boundDevice = null;
        unawaited(
          bleConnectionService.detach().whenComplete(() => stopBleService()),
        );
        return;
      }
      // A manual pick goes looking even while another sole is connected;
      // anything else only searches when nothing is connected.
      unawaited(searchAndAttach(force: prev?.preferredId != next.preferredId));
    },
    fireImmediately: true,
  );
});
