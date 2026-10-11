import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/ble/sole_notification_text.dart';
import 'package:silversole/core/ble/pressure_channel_fix.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/device_status_model.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';
import 'package:silversole/shared/models/record_imu_notify_data_model.dart';
import 'package:silversole/shared/providers/ble_connection_provider.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/device_status_ingest_provider.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/sole_connection_controller.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

import 'settings_provider.dart';

/// Lets an OTA wait for a rebooting sole without it being mistaken for the
/// last advertisements of the old firmware on its way down.
const _reacquireSettle = Duration(seconds: 3);

/// A found sole still needs to connect and handshake, however little of the
/// reacquire timeout is left.
const _minHandshakeWait = Duration(seconds: 20);

final bleForegroundControlProvider = Provider<SoleConnectionController>((ref) {
  // Check platform
  if (defaultTargetPlatform != TargetPlatform.android) {
    return const NoSoleConnection();
  }
  final bleConnectionService = ref.read(bleConnectProvider);
  final deviceStatusIngestService = ref.read(deviceStatusIngestProvider);
  final settings = ref.read(settingsProvider.notifier);
  final live = ref.read(liveTelemetryProvider.notifier);
  final connectedSole = ref.read(connectedSoleProvider.notifier);

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

  // An OTA owns the link between hold() and release(): nothing may search,
  // swap soles or chase a reboot meanwhile.
  var held = false;
  // Completed by onReady while reacquire() waits for the rebooted sole, for
  // the remoteId it is waiting on — so a different sole's onReady (a stray
  // search that slipped in before hold() landed) cannot complete it.
  ({String remoteId, Completer<SoleSessionInfo?> completer})? readyWaiter;

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
    unawaited(settings.setLastBatteryPercent(device.identityKey, percent));
  }

  // The service's notification names the sole and says what the home card
  // says: online or "last connected", plus the battery level. Pushed only when
  // the text changes, since telemetry ticks at 50 Hz.
  String? notified;
  void syncNotification() {
    final current = ref.read(settingsProvider);
    final bound = boundDevice;
    final stored = bound == null
        ? current.preferredDevice
        : current.pairedDevicesList.firstWhereOrNull(
            (d) => d.identityKey == bound.identityKey,
          );
    // The stored entry carries a rename; the bound copy the freshest battery.
    final sole = stored ?? bound;
    if (sole == null) return;

    final telemetry = ref.read(liveTelemetryProvider);
    final online = ref.read(deviceOnlineProvider);
    final content = soleNotificationText(
      soleName: sole.name,
      online: online,
      lastSeen: telemetry.updatedAt ?? sole.lastConnectedAt,
      battery: BatteryDisplay.resolve(
        live: online ? telemetry.recentImu.lastOrNull?.batteryPercent : null,
        lastKnown: bound?.lastBatteryPercent ?? sole.lastBatteryPercent,
      ),
    );
    final key = '${content.title}\n${content.text}';
    if (key == notified) return;
    notified = key;
    unawaited(
      updateBleNotification(
        title: content.title,
        text: content.text,
      ).catchError((Object e) => debugPrint('notification update: $e')),
    );
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
      live.updateRecordImuNotifyData(
        data.copyWith(pressure: fixPressureChannels(data.pressure)),
      );
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

  // The service's ongoing notification is what tells the wearer BLE keeps
  // running in the background (and what Play's foreground-service review looks
  // for). Android 13+ hides it until this is granted — the service itself runs
  // either way, so a refusal only costs the notification and never blocks the
  // connection. Asked once per launch, not on every search retry.
  var notificationAsked = false;
  Future<void> ensureNotificationPermission() async {
    if (notificationAsked) return;
    notificationAsked = true;
    await Permission.notification.request();
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

  /// Connects to [pick] with the app's handlers, reusing its paired entry.
  /// False when the session could not even be armed.
  Future<bool> attachTo(
    SoleCandidate pick,
    List<BlePairedDevice> paired,
  ) async {
    // Reuse the stored entry for this sole, so its name and primary flag
    // survive; it only moves to the address the sole is on now, and picks up
    // the advertised ID if it was paired before the firmware sent one.
    final known = paired.firstWhereOrNull((d) => isSameSole(pick, d));
    final device =
        known?.copyWith(
          remoteId: pick.remoteId,
          deviceId: pick.deviceId ?? known.deviceId,
        ) ??
        BlePairedDevice(
          remoteId: pick.remoteId,
          name: pick.name,
          deviceId: pick.deviceId,
          lastRssi: pick.rssi,
        );
    boundDevice = device;
    syncNotification();

    final result = await bleConnectionService.attach(
      device,
      handlers: BleSessionHandlers(
        onImu: onImu,
        onRecordImu: onRecordImu,
        onFallDetect: onFallDetect,
        onDeviceStatus: (value) => unawaited(onDeviceStatus(value)),
        onReady: (info) {
          final deviceId = info.deviceId;
          // Connected and handshaked: the watchdog has nothing to rescue and
          // the next search starts from the short delay again.
          watchdogTimer?.cancel();
          searchAttempt = 0;
          // The Serial Number read and the advertisement carry the same ID;
          // a mismatch means one of them is being parsed wrong.
          if (deviceId != null &&
              pick.deviceId != null &&
              deviceId != pick.deviceId) {
            debugPrint(
              'device ID mismatch: advertised ${pick.deviceId}, '
              'read $deviceId',
            );
          }
          // Persist the moment we (re)connected so the status card can show a
          // real "last connected" time. The listener below ignores timestamp
          // changes, so this does not restart the search.
          final updated = (boundDevice ?? device).copyWith(
            deviceId: deviceId ?? boundDevice?.deviceId,
            lastConnectedAt: DateTime.now(),
          );
          boundDevice = updated;
          syncNotification();
          unawaited(settings.addOrUpdatePairedDevice(updated));
          connectedSole.set(
            ConnectedSole(
              device: updated,
              firmwareVersion: info.firmwareVersion,
              dfuSupported: info.dfuSupported,
            ),
          );
          final waiter = readyWaiter;
          if (waiter != null &&
              waiter.remoteId == pick.remoteId &&
              !waiter.completer.isCompleted) {
            waiter.completer.complete(info);
          }
          debugPrint(
            'sole session ready: deviceId=${updated.deviceId} '
            'firmware=${info.firmwareVersion}',
          );
        },
        onDisconnected: (reason) {
          debugPrint('sole disconnected: $reason');
          connectedSole.clear();
          // During an update the reboot is expected, and reacquire() — not the
          // watchdog — brings the sole back.
          if (!held) armWatchdog();
        },
      ),
    );

    if (result case Error(:final error)) {
      debugPrint('sole attach failed: $error');
      return false;
    }
    debugPrint('sole session attached');
    return true;
  }

  /// Finds a paired sole that is actually advertising and connects to it.
  ///
  /// Soles are recognised by the chip ID in their advertisement, so a sole is
  /// found again whatever address it comes back on; firmware too old to send
  /// the ID falls back to the address, which is what [pickSole] spells out.
  /// [force] is the manual primary-device pick asking us to look even though a
  /// session is already up.
  searchAndAttach = ({bool force = false}) async {
    // An update owns the link until it releases it.
    if (searching || held) return;
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

      await ensureNotificationPermission();
      await startBleService();
      syncNotification();

      final pick = pickSole(
        await scanner.scan(),
        paired: current.pairedDevicesList,
      );
      if (pick == null) {
        debugPrint('no paired sole advertising');
        scheduleSearch();
        return;
      }
      debugPrint('sole found: $pick');

      // An update may have taken the link while this search was scanning.
      if (held) return;

      if (await attachTo(pick, current.pairedDevicesList)) {
        // ...or while attachTo itself was running the handshake.
        if (!held) armWatchdog();
      } else {
        scheduleSearch();
      }
    } finally {
      searching = false;
    }
  };

  /// Brings [target] back after it rebooted into new firmware and returns its
  /// fresh session, or null when it does not show up within [timeout].
  ///
  /// Never throws: the caller (an update stuck in its rebooting phase) treats
  /// null as "could not confirm the sole came back" either way.
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target,
    Duration timeout,
  ) async {
    try {
      final deadline = clock.now().add(timeout);
      // The old session's own reconnect would chase the address the sole had
      // before it rebooted.
      await bleConnectionService.detach();
      connectedSole.clear();
      await Future<void>.delayed(_reacquireSettle);

      final paired = ref.read(settingsProvider).pairedDevicesList;
      final seen = await scanner.watch(
        timeout: deadline.difference(clock.now()),
        stopWhen: (c) => isReacquireTarget(c, target),
      );
      final match = matchReacquireTarget(
        target: target,
        seen: seen,
        paired: paired,
      );
      if (match == null) {
        debugPrint('updated sole not found among ${seen.length} soles');
        return null;
      }

      final completer = Completer<SoleSessionInfo?>();
      // Keyed by remoteId so a stray search's onReady for a different sole
      // cannot complete this waiter.
      readyWaiter = (remoteId: match.candidate.remoteId, completer: completer);
      try {
        if (!await attachTo(match.candidate, paired)) return null;
        final left = deadline.difference(clock.now());
        final info = await completer.future.timeout(
          left > _minHandshakeWait ? left : _minHandshakeWait,
          onTimeout: () => null,
        );
        return info == null ? null : ReacquiredSole(info, match.confidence);
      } finally {
        readyWaiter = null;
      }
    } catch (e) {
      debugPrint('reacquire failed: $e');
      return null;
    }
  }

  // What the notification shows moves on its own: the online flag, the battery,
  // a rename. The ticker keeps "last connected: N min ago" current offline.
  ref.listen(deviceOnlineProvider, (_, _) => syncNotification());
  ref.listen(
    liveTelemetryProvider.select((s) => s.recentImu.lastOrNull?.batteryPercent),
    (_, _) => syncNotification(),
  );
  ref.listen(
    settingsProvider.select((s) => s.pairedDevicesList),
    (_, _) => syncNotification(),
  );
  final notificationTicker = Timer.periodic(
    const Duration(seconds: 30),
    (_) => syncNotification(),
  );
  ref.onDispose(notificationTicker.cancel);

  // The primary-device pick and "is anything paired at all" are the only
  // settings that change what we should be connected to. Every reconnect
  // rewrites the paired entry's timestamp, which this selector ignores on
  // purpose — otherwise each reconnect would kick off another search.
  ref.listen<
    ({String? preferredKey, String? preferredAddress, int pairedCount})
  >(
    settingsProvider.select(
      (s) => (
        preferredKey: s.preferredDevice?.identityKey,
        preferredAddress: s.preferredDevice?.remoteId,
        pairedCount: s.pairedDevicesList.length,
      ),
    ),
    (prev, next) {
      if (next.pairedCount == 0) {
        retryTimer?.cancel();
        watchdogTimer?.cancel();
        boundDevice = null;
        connectedSole.clear();
        unawaited(
          bleConnectionService.detach().whenComplete(() => stopBleService()),
        );
        return;
      }
      // A manual pick goes looking even while another sole is connected;
      // anything else only searches when nothing is connected. A pick changes
      // both the identity and the address. The connected sole changes only
      // one of them, and that must not force a reconnect: on a new address its
      // identity stays the same, and when an old entry picks up its ID its
      // address stays the same.
      final picked =
          prev?.preferredKey != next.preferredKey &&
          prev?.preferredAddress != next.preferredAddress;
      unawaited(searchAndAttach(force: picked));
    },
    fireImmediately: true,
  );

  return _ForegroundSoleConnection(
    onHold: () {
      held = true;
      retryTimer?.cancel();
      watchdogTimer?.cancel();
    },
    onRelease: () {
      if (!held) return;
      held = false;
      unawaited(searchAndAttach());
    },
    onDfuLink: bleConnectionService.dfuLink,
    onReacquire: reacquire,
  );
});

class _ForegroundSoleConnection implements SoleConnectionController {
  _ForegroundSoleConnection({
    required this.onHold,
    required this.onRelease,
    required this.onDfuLink,
    required this.onReacquire,
  });

  final void Function() onHold;
  final void Function() onRelease;
  final DfuLink? Function() onDfuLink;
  final Future<ReacquiredSole?> Function(BlePairedDevice, Duration) onReacquire;

  @override
  void hold() => onHold();

  @override
  void release() => onRelease();

  @override
  DfuLink? dfuLink() => onDfuLink();

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) => onReacquire(target, timeout);
}
