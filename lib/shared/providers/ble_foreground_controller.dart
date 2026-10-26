import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ble_permissions.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/ble/pressure_channel_fix.dart';
import 'package:silversole/core/ble/sole_notification_text.dart';
import 'package:silversole/core/ble/sole_reconcile.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';
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
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

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
  final registry = ref.read(soleSessionsProvider);
  final deviceStatusIngestService = ref.read(deviceStatusIngestProvider);
  final settings = ref.read(settingsProvider.notifier);
  final connectedSoles = ref.read(connectedSolesProvider.notifier);

  final scanner = SoleScanner();

  // Re-arms the search: nothing advertising, a permission refused, arming a
  // session failing, or still being short of a foot. Reconnecting to a sole
  // we already found is that session's own backoff loop — do not add a second
  // one here.
  Timer? retryTimer;
  var searching = false;
  var searchAttempt = 0;

  // An OTA owns the link between hold() and release(): nothing may search,
  // swap soles or chase a reboot meanwhile.
  var held = false;
  // Completed by onReady while reacquire() waits for the rebooted sole, for
  // the remoteId it is waiting on — so a different sole's onReady (a stray
  // search that slipped in before hold() landed) cannot complete it.
  ({String remoteId, Completer<SoleSessionInfo?> completer})? readyWaiter;

  String toHex(List<int> v) =>
      v.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  // Persists a sole's battery level so it can be shown greyed out while that
  // sole is offline. The IMU stream repeats the same level at 50 Hz, so only a
  // change is written; the link carries it so onReady's write keeps it.
  void rememberBattery(SoleLink link, int percent) {
    if (!percent.isValidBatteryPercent) return;
    if (link.device.lastBatteryPercent == percent) return;
    link.device = link.device.copyWith(lastBatteryPercent: percent);
    unawaited(settings.setLastBatteryPercent(link.device.identityKey, percent));
  }

  // The service's notification names the sole(s) and says what the home card
  // says. Pushed only when the text changes, since telemetry ticks at 50 Hz
  // per foot.
  String? notified;
  void syncNotification() {
    final current = ref.read(settingsProvider);
    final facade = ref.read(telemetryFacadeProvider);

    SoleNotice noticeFor(BlePairedDevice sole, {int? liveBattery}) {
      final telemetry = ref.read(liveTelemetryProvider(sole.identityKey));
      final online = facade.checkDeviceOnline(telemetry.updatedAt);
      return SoleNotice(
        name: sole.name,
        // Before a side is assigned the ID suffix is all that tells two
        // identical "SilverSole"s apart.
        label:
            sole.footSide?.labelKey.tr() ??
            (sole.shortId == null ? sole.name : '••••${sole.shortId}'),
        online: online,
        lastSeen: telemetry.updatedAt ?? sole.lastConnectedAt,
        battery: BatteryDisplay.resolve(
          live: online
              ? liveBattery ?? telemetry.recentImu.lastOrNull?.batteryPercent
              : null,
          lastKnown: sole.lastBatteryPercent,
        ),
      );
    }

    final notices = <SoleNotice>[];
    for (final link in registry.links) {
      // The stored entry carries a rename; the link's copy the freshest
      // battery.
      final stored = current.pairedDevicesList.firstWhereOrNull(
        (d) => d.identityKey == link.device.identityKey,
      );
      notices.add(
        noticeFor(
          stored ?? link.device,
          liveBattery: link.device.lastBatteryPercent,
        ),
      );
    }
    if (notices.isEmpty) {
      // Nothing linked yet: name the primary entry so the service's ongoing
      // notification is not blank while the first search runs.
      final sole =
          current.preferredDevice ?? current.pairedDevicesList.firstOrNull;
      if (sole == null) return;
      notices.add(noticeFor(sole));
    }

    final content = soleNotificationText(notices);
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

  // Every notify handler holds the link itself rather than the key it was
  // filed under: onReady re-keys a legacy sole the moment it reports a chip
  // ID, and a captured key would then look up nothing — that foot's telemetry
  // would stop with no error at all. The telemetry key is therefore read off
  // the link on every packet.
  void onImu(SoleLink link, List<int> value) {
    try {
      final data = link.service.parseImuNotify(value);
      final key = link.device.identityKey;
      ref.read(liveTelemetryProvider(key).notifier).updateImuNotifyData(data);
      // The raw sample too, unaveraged, for the games (game_sole_forwarding).
      ref
          .read(soleSampleBusProvider)
          .emit(SoleSample(identityKey: key, data: data));
      rememberBattery(link, data.batteryPercent);
    } catch (e) {
      // Always report the first failure, then throttle: a format mismatch
      // fails on every packet and would spam ~20 lines/s per foot.
      link.imuFailCount++;
      if (link.imuFailCount == 1 || link.imuFailCount % 20 == 0) {
        debugPrint(
          'parse notify FAILED ${link.device.identityKey} '
          '#${link.imuFailCount} len=${value.length} '
          'hex=[${toHex(value)}] err=$e',
        );
      }
    }
  }

  void onRecordImu(SoleLink link, List<int> value) {
    try {
      final json = link.service.parseJsonNotify(value);
      final data = RecordImuNotifyDataModel.fromJson(json);
      ref
          .read(liveTelemetryProvider(link.device.identityKey).notifier)
          .updateRecordImuNotifyData(
            data.copyWith(pressure: fixPressureChannels(data.pressure)),
          );
      debugPrint('record notify ${link.device.identityKey}: $data');
    } catch (e) {
      debugPrint('parse record notify failed: $e');
    }
  }

  void onFallDetect(SoleLink link, List<int> value) {
    try {
      if (utf8.decode(value) != '1') return;
      final deviceId = link.device.deviceId;
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

  Future<void> onDeviceStatus(SoleLink link, List<int> value) async {
    try {
      final payload = link.service.parseJsonNotify(value);
      final status = DeviceStatusModel.fromJson(payload);
      if (!isDeviceStatusTimestampValid(status.timestamp)) {
        debugPrint('device status timestamp invalid: ${status.timestamp}');
        return;
      }
      rememberBattery(link, status.body.batteryPercent);
      final result = await deviceStatusIngestService.ingestDeviceStatus(
        device: link.device,
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

  Future<bool> ensureConnectPermission() => requestBleConnectPermission();

  /// Mirrors the pairing sheet's request. This only ever runs once the user has
  /// paired a sole by hand, so the prompts have already been seen by then.
  Future<bool> ensureScanPermission() => requestBleScanPermission();

  // The service's ongoing notification is what tells the wearer BLE keeps
  // running in the background (and what Play's foreground-service review looks
  // for). Android 13+ hides it until this is granted — the service itself runs
  // either way, so a refusal only costs the notification and never blocks the
  // connection. Asked once per launch, not on every search retry.
  var notificationAsked = false;
  Future<void> ensureNotificationPermission() async {
    if (notificationAsked || !bleNeedsNotificationPermission) return;
    notificationAsked = true;
    await Permission.notification.request();
  }

  // searchAndAttach and the timers below call each other, and Dart has no
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

  /// Gives this sole's own fast reconnect a window to bring the same MAC back.
  /// When it cannot, the sole has most likely rebooted — it advertises a
  /// different MAC then, and only a fresh scan can find it.
  void armWatchdog(
    SoleLink link, [
    Duration delay = const Duration(seconds: 30),
  ]) {
    link.cancelWatchdog();
    link.watchdog = Timer(delay, () {
      if (link.isConnected) return;
      debugPrint('sole ${link.device.identityKey} did not connect — searching');
      unawaited(searchAndAttach());
    });
  }

  void onReady(
    SoleLink link,
    String soleKey,
    SoleCandidate pick,
    SoleSessionInfo info,
  ) {
    final deviceId = info.deviceId;
    // Connected and handshaked: this sole's watchdog has nothing to rescue and
    // the next search starts from the short delay again.
    link.cancelWatchdog();
    searchAttempt = 0;
    // The Serial Number read and the advertisement carry the same ID; a
    // mismatch means one of them is being parsed wrong.
    if (deviceId != null &&
        pick.deviceId != null &&
        deviceId != pick.deviceId) {
      debugPrint(
        'device ID mismatch: advertised ${pick.deviceId}, read $deviceId',
      );
    }
    // Persist the moment we (re)connected so the status card can show a real
    // "last connected" time. The settings listener ignores timestamp changes,
    // so this does not restart the search.
    final updated = link.device.copyWith(
      deviceId: deviceId ?? link.device.deviceId,
      lastConnectedAt: DateTime.now(),
    );
    link.device = updated;
    // A sole paired on pre-ID firmware is filed under its address. Now that it
    // has reported a chip ID its paired entry is keyed by that ID, so the
    // session has to move with it — otherwise the next reconcile reads the old
    // key as unpaired and tears this working link down. The handlers hold this
    // link rather than its key, so they keep working across the move.
    final liveKey = updated.identityKey;
    if (liveKey != soleKey) {
      connectedSoles.clear(soleKey);
      unawaited(registry.rekey(soleKey, liveKey));
    }
    syncNotification();
    unawaited(settings.addOrUpdatePairedDevice(updated));
    connectedSoles.set(
      liveKey,
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
      'sole session ready: $liveKey deviceId=${updated.deviceId} '
      'firmware=${info.firmwareVersion}',
    );
  }

  /// Connects to [pick] with the app's handlers, reusing its paired entry.
  /// False when the session could not even be armed.
  Future<bool> attachTo(
    SoleCandidate pick,
    List<BlePairedDevice> paired,
  ) async {
    // Reuse the stored entry for this sole, so its name, foot side and primary
    // flag survive; it only moves to the address the sole is on now, and picks
    // up the advertised ID if it was paired before the firmware sent one.
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
    final soleKey = identityKeyFor(pick, paired);
    final link = registry.link(soleKey, device);
    syncNotification();

    // attach()'s own detach() cancels this session's old listener before the
    // new link comes up, so onDisconnected never fires for it — without this,
    // a re-attach would leave a stale entry in connectedSolesProvider until
    // the new handshake overwrote it.
    connectedSoles.clear(soleKey);

    final result = await link.service.attach(
      device,
      handlers: BleSessionHandlers(
        onImu: (value) => onImu(link, value),
        onRecordImu: (value) => onRecordImu(link, value),
        onFallDetect: (value) => onFallDetect(link, value),
        onDeviceStatus: (value) => unawaited(onDeviceStatus(link, value)),
        onReady: (info) => onReady(link, soleKey, pick, info),
        onDisconnected: (reason) {
          debugPrint('sole ${link.device.identityKey} disconnected: $reason');
          connectedSoles.clear(link.device.identityKey);
          // During an update the reboot is expected, and reacquire() — not the
          // watchdog — brings the sole back.
          if (!held) armWatchdog(link);
        },
      ),
    );

    if (result case Error(:final error)) {
      debugPrint('sole attach failed: $error');
      return false;
    }
    debugPrint('sole session attached: $soleKey');
    return true;
  }

  /// Finds the paired soles that are actually advertising and connects to
  /// them — up to [maxSoles], one per foot.
  ///
  /// Soles are recognised by the chip ID in their advertisement, so a sole is
  /// found again whatever address it comes back on; firmware too old to send
  /// the ID falls back to the address, which is what [pickSoles] spells out.
  /// [force] is the manual primary-device pick asking us to look even though
  /// every slot is already filled.
  searchAndAttach = ({bool force = false}) async {
    // An update owns the link until it releases it.
    if (searching || held) return;

    final current = ref.read(settingsProvider);
    final desired = current.pairedDevicesList.length < maxSoles
        ? current.pairedDevicesList.length
        : maxSoles;
    if (!needsSearch(
      paired: current.pairedDevicesList,
      links: linkStatesOf(registry),
      force: force,
    )) {
      return;
    }

    searching = true;
    retryTimer?.cancel();
    try {
      // Never reach for a stranger's sole: auto-connect starts only once the
      // user has paired one by hand.
      if (current.pairedDevicesList.isEmpty) {
        await registry.detachAll();
        connectedSoles.clearAll();
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

      final seen = await scanner.scan();
      // Re-read after the scan: a legacy sole's handshake can land mid-scan
      // and move its paired entry's identityKey, and planning against the
      // pre-scan list would read that fresh link as unpaired and detach it.
      final paired = ref.read(settingsProvider).pairedDevicesList;
      final plan = reconcileSoleLinks(
        picks: pickSoles(seen, paired: paired, max: desired),
        paired: paired,
        // Read again rather than reusing the guard's snapshot: the scan above
        // takes seconds, and a link that connected or died meanwhile must not
        // be planned for as it was before.
        links: linkStatesOf(registry),
      );

      for (final soleKey in plan.detach) {
        await registry.detach(soleKey);
        connectedSoles.clear(soleKey);
      }

      // An update may have taken the link while this search was scanning.
      if (held) return;

      // One at a time: fbp 2.1.1 runs every GATT operation behind a single
      // global mutex, so two handshakes at once only queue up anyway — and
      // interleaving them would make a failure much harder to read.
      var anyFailed = false;
      for (final pick in plan.attach) {
        if (held) return;
        if (await attachTo(pick, paired)) {
          final link = registry.lookup(identityKeyFor(pick, paired));
          if (!held && link != null) armWatchdog(link);
        } else {
          // A session that could not even be armed leaves a dead link behind
          // and no watchdog to rescue it, so the search has to come back.
          anyFailed = true;
        }
      }

      // Still short of a foot (the other sole is switched off, out of range,
      // or rebooted onto an address this scan did not see): keep looking on
      // the backoff. A sole that was just attached counts as found even though
      // its link is still coming up. The watchdog does not cover this — it
      // only fires once per link and then needs a search to exist to call.
      if (plan.reschedule || anyFailed) scheduleSearch();
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
      // This sole's own reconnect would chase the address it had before it
      // rebooted. The other foot's session is left alone.
      await registry.detach(target.identityKey);
      connectedSoles.clear(target.identityKey);
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

  // What the notification shows moves on its own: the online flag, a rename,
  // and the battery — which lands in the paired list via rememberBattery, so
  // that listener covers it. Deliberately *not* a listener on live telemetry:
  // that fires 50 times a second per foot.
  ref.listen(deviceOnlineProvider, (_, _) => syncNotification());
  ref.listen(
    settingsProvider.select((s) => s.pairedDevicesList),
    (_, _) => syncNotification(),
  );
  // Keeps "last connected: N min ago" current while everything is offline.
  final notificationTicker = Timer.periodic(
    const Duration(seconds: 30),
    (_) => syncNotification(),
  );
  ref.onDispose(notificationTicker.cancel);

  // The primary-device pick and "is anything paired at all" are the only
  // settings that change what we should be connected to. Every reconnect
  // rewrites the paired entry's timestamp, which this selector ignores on
  // purpose — otherwise each reconnect would kick off another search. A
  // calibration only labels soles that are already connected, so it is not
  // here either.
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
        connectedSoles.clearAll();
        unawaited(registry.detachAll().whenComplete(() => stopBleService()));
        return;
      }
      // A manual pick goes looking even while every slot is filled; anything
      // else only searches when a foot is missing. A pick changes both the
      // identity and the address. A connected sole changes only one of them,
      // and that must not force a reconnect: on a new address its identity
      // stays the same, and when an old entry picks up its ID its address
      // stays the same.
      final picked =
          prev?.preferredKey != next.preferredKey &&
          prev?.preferredAddress != next.preferredAddress;
      unawaited(searchAndAttach(force: picked));
    },
    fireImmediately: true,
  );

  return _ForegroundSoleConnection(
    onHold: (soleKey) {
      held = true;
      retryTimer?.cancel();
      for (final link in registry.links) {
        link.cancelWatchdog();
      }
      dropOtherSoles(registry, connectedSoles, keep: soleKey);
      // The dropped foot is still named by the notification until something
      // re-pushes it. The deviceOnlineProvider listener usually will not: the
      // sole we keep is still streaming, so "any sole is online" never
      // changes and the listener does not fire. Without this the text keeps
      // claiming a foot that is gone until the 30 s ticker comes round.
      syncNotification();
    },
    onRelease: () {
      if (!held) return;
      held = false;
      unawaited(searchAndAttach());
    },
    onDfuLink: (soleKey) => registry.lookup(soleKey)?.service.dfuLink(),
    onReacquire: reacquire,
  );
});

/// Tears down every session except [keep]'s.
///
/// An OTA's page writes and another foot's handshake contend for
/// flutter_blue_plus's one global GATT mutex, so the other feet come off the
/// air for the duration; the search loop fetches them back after `release()`.
///
/// A free function so the "never the sole we are keeping" rule can be tested
/// without standing up the whole orchestrator.
void dropOtherSoles(
  SoleSessionRegistry registry,
  ConnectedSolesNotifier connectedSoles, {
  required String keep,
}) {
  // Snapshot the keys, because detach() mutates the registry's map — and it
  // removes the entry *before* its first await, so a caller may read the
  // registry straight after this returns and see only [keep]. The
  // syncNotification() call at the hold site relies on exactly that.
  for (final otherKey in registry.keys.toList()) {
    if (otherKey == keep) continue;
    debugPrint('ota holds the link — dropping $otherKey meanwhile');
    unawaited(registry.detach(otherKey));
    connectedSoles.clear(otherKey);
  }
}

class _ForegroundSoleConnection implements SoleConnectionController {
  _ForegroundSoleConnection({
    required this.onHold,
    required this.onRelease,
    required this.onDfuLink,
    required this.onReacquire,
  });

  final void Function(String identityKey) onHold;
  final void Function() onRelease;
  final DfuLink? Function(String identityKey) onDfuLink;
  final Future<ReacquiredSole?> Function(BlePairedDevice, Duration) onReacquire;

  @override
  void hold(String identityKey) => onHold(identityKey);

  @override
  void release() => onRelease();

  @override
  DfuLink? dfuLink(String identityKey) => onDfuLink(identityKey);

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) => onReacquire(target, timeout);
}
