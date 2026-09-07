import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

/// Raw notify payload from the sole.
typedef BleNotifyHandler = void Function(List<int> value);

/// What a caller wants out of one sole session.
///
/// The same set is reused for every (re)connection: each time the link comes
/// back the service re-runs the handshake and re-arms these handlers.
class BleSessionHandlers {
  const BleSessionHandlers({
    required this.onImu,
    required this.onRecordImu,
    required this.onFallDetect,
    required this.onDeviceStatus,
    this.onReady,
    this.onDisconnected,
  });

  final BleNotifyHandler onImu;
  final BleNotifyHandler onRecordImu;
  final BleNotifyHandler onFallDetect;
  final BleNotifyHandler onDeviceStatus;

  /// Called once per connection, after the read/write handshake and *before*
  /// any notify is enabled — so the handlers above can rely on the device id.
  /// [deviceId] is null when the sole did not answer the read.
  final void Function(String? deviceId)? onReady;

  /// Called on every link loss with the platform's disconnect reason
  /// (e.g. `8 GATT_CONN_TIMEOUT`), which is the only way to tell a supervision
  /// timeout apart from a remote-initiated disconnect.
  final void Function(String reason)? onDisconnected;
}

/// Owns the single live BLE session with the sole.
///
/// The session is connection-state driven, not polled: [attach] registers a
/// [BluetoothDevice.connectionState] listener, and every `connected` event
/// re-runs [_setUpSession], which discovers services **once** and derives every
/// characteristic from that one result. Link loss arrives as a `disconnected`
/// event and arms a backoff reconnect.
class BleConnectionService {
  /// Matches the firmware's `conn_gatt.att_mtu`; the negotiated value is
  /// `min(request, firmware)` anyway, so asking for more just wastes a
  /// round-trip.
  static const _preferredMtu = 64;

  static const _connectTimeout = Duration(seconds: 15);
  static const _maxBackoffSeconds = 30;

  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  BluetoothService? _service;
  BleSessionHandlers? _handlers;
  bool _settingUp = false;
  bool _setupPending = false;

  /// True between [attach] and [detach]. Gates the reconnect loop so a
  /// deliberate teardown is not immediately undone by it.
  bool _wanted = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  /// Whether the sole is connected to this app right now.
  bool get isConnected => _device?.isConnected ?? false;

  /// Starts a persistent session with [device].
  ///
  /// Called once per preferred device, not once per reconnect: the
  /// `connectionState` listener registered here owns every later attempt.
  /// Returns as soon as the session is armed — the first connection attempt
  /// reports through [BleSessionHandlers.onDisconnected] and the backoff loop
  /// like any other, so callers do not special-case it.
  Future<Result<void>> attach(
    BlePairedDevice device, {
    required BleSessionHandlers handlers,
  }) async {
    await detach();

    final target = BluetoothDevice.fromId(device.remoteId);
    _device = target;
    _handlers = handlers;
    _wanted = true;
    _reconnectAttempt = 0;

    try {
      // Deliberately not registered with cancelWhenDisconnected: that would
      // drop the listener on the first disconnect and we would never hear the
      // reconnect that follows.
      _stateSub = target.connectionState.listen((state) {
        switch (state) {
          case BluetoothConnectionState.connected:
            _reconnectTimer?.cancel();
            _reconnectAttempt = 0;
            unawaited(_setUpSession());
          case BluetoothConnectionState.disconnected:
            _service = null;
            final reason = target.disconnectReason;
            handlers.onDisconnected?.call(
              '${reason?.code ?? '-'} ${reason?.description ?? 'unknown'}',
            );
            _scheduleReconnect();
          default:
            break;
        }
      });
    } catch (e) {
      return Result.error(Exception('attach failed: $e'));
    }

    unawaited(_connect());
    return Result.ok(null);
  }

  /// Tears the session down and stops the reconnect loop.
  Future<void> detach() async {
    _wanted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;

    await _stateSub?.cancel();
    _stateSub = null;
    _service = null;
    _handlers = null;

    final device = _device;
    _device = null;
    if (device == null) return;
    try {
      await device.disconnect();
    } catch (e) {
      debugPrint('disconnect failed: $e');
    }
  }

  /// One direct connection attempt.
  ///
  /// `autoConnect: false` on purpose. Android's `autoConnect: true` is a
  /// background, low-duty-cycle acceptlist connection that routinely never
  /// completes for a device the Bluetooth stack has not connected to before —
  /// i.e. exactly a freshly added sole. A direct connection is what actually
  /// establishes the first link; the backoff loop below covers the retries
  /// that autoConnect would otherwise have handled.
  Future<void> _connect() async {
    final device = _device;
    if (device == null || !_wanted || device.isConnected) return;
    try {
      // mtu is left null and requested in the handshake instead, so both the
      // MTU and the rest of the setup live in one place.
      await device.connect(
        license: License.free,
        autoConnect: false,
        mtu: null,
        timeout: _connectTimeout,
      );
    } catch (e) {
      debugPrint('connect failed: $e');
      _scheduleReconnect();
    }
  }

  /// Arms one pending reconnect. Whichever path notices the failure first wins;
  /// a `disconnected` event and a thrown `connect()` often both fire for the
  /// same attempt, and re-arming on the second would double the backoff.
  void _scheduleReconnect() {
    if (!_wanted) return;
    if (_reconnectTimer?.isActive ?? false) return;

    // 1, 2, 4, 8, 16, 30, 30… seconds.
    final seconds = math.min(1 << _reconnectAttempt, _maxBackoffSeconds);
    _reconnectAttempt = math.min(_reconnectAttempt + 1, 10);
    debugPrint('sole reconnect in ${seconds}s');
    _reconnectTimer = Timer(
      Duration(seconds: seconds),
      () => unawaited(_connect()),
    );
  }

  /// Reads a UTF-8 string characteristic on the active session.
  Future<Result<String>> readString(String characteristicUuid) async {
    final char = _characteristic(characteristicUuid);
    if (char == null) {
      return Result.error(Exception('not connected: $characteristicUuid'));
    }
    try {
      return Result.ok(utf8.decode(await char.read()).trim());
    } catch (e) {
      return Result.error(Exception('readString failed: $e'));
    }
  }

  /// Writes `'1'` / `'0'` to a characteristic on the active session.
  Future<Result<void>> writeBool(
    String characteristicUuid,
    bool value, {
    bool withoutResponse = false,
  }) => writeString(
    characteristicUuid,
    value ? '1' : '0',
    withoutResponse: withoutResponse,
  );

  /// Writes a UTF-8 string to a characteristic on the active session.
  Future<Result<void>> writeString(
    String characteristicUuid,
    String value, {
    bool withoutResponse = false,
  }) async {
    final char = _characteristic(characteristicUuid);
    if (char == null) {
      return Result.error(Exception('not connected: $characteristicUuid'));
    }
    try {
      await char.write(utf8.encode(value), withoutResponse: withoutResponse);
      return Result.ok(null);
    } catch (e) {
      return Result.error(Exception('writeString failed: $e'));
    }
  }

  /// Serializes the per-connection handshake.
  ///
  /// A flapping link can deliver a second `connected` event while the first
  /// pass is still awaiting a GATT round-trip. Dropping that event would leave
  /// us connected with no notify subscriptions, so it is queued instead.
  Future<void> _setUpSession() async {
    if (_settingUp) {
      _setupPending = true;
      return;
    }
    _settingUp = true;
    try {
      do {
        _setupPending = false;
        await _runHandshake();
      } while (_setupPending && isConnected);
    } finally {
      _settingUp = false;
    }
  }

  Future<void> _runHandshake() async {
    final device = _device;
    final handlers = _handlers;
    if (device == null || handlers == null) return;
    try {
      // autoConnect rules out the `mtu` connect argument, so the bump happens
      // here instead. Android-only in fbp.
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await device.requestMtu(_preferredMtu);
        } catch (e) {
          debugPrint('requestMtu failed: $e');
        }
      }

      // Once per connection. Every characteristic below comes out of this one
      // discovery rather than re-running it per GATT operation.
      final services = await device.discoverServices();
      final service = services.firstWhereOrNull(
        (s) => s.uuid == Guid(serviceUuid),
      );
      if (service == null) {
        debugPrint('service not found: $serviceUuid');
        return;
      }
      _service = service;

      // Reads and writes first: the live IMU characteristic streams at 50 Hz,
      // and enabling it before the handshake leaves every remaining round-trip
      // competing with that flood.
      String? deviceId;
      switch (await readString(deviceIdCharUuid)) {
        case Ok(:final value):
          // The firmware declares the device-id characteristic but never
          // populates it, so the read succeeds with 0 bytes. Treat blank as
          // unknown — otherwise '' is persisted as the paired device's id and
          // uploaded as a real one by the heartbeat ingest.
          if (value.isEmpty) {
            debugPrint('device id is blank — firmware never set it');
          } else {
            deviceId = value;
          }
        case Error(:final error):
          debugPrint('read device id failed: $error');
      }

      final syncResult = await writeString(
        baseTimestampCharUuid,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
      switch (syncResult) {
        case Error(:final error):
          debugPrint('write base timestamp failed: $error');
        case Ok():
          debugPrint('base timestamp synced');
      }

      handlers.onReady?.call(deviceId);

      // Notifications last.
      await _subscribe(device, notifyCharUuid, handlers.onImu);
      await _subscribe(device, recordNotifyCharUuid, handlers.onRecordImu);
      await _subscribe(device, fallDetectCharUuid, handlers.onFallDetect);
      await _subscribe(device, deviceStatusCharUuid, handlers.onDeviceStatus);
    } catch (e) {
      debugPrint('session setup failed: $e');
    }
  }

  Future<void> _subscribe(
    BluetoothDevice device,
    String characteristicUuid,
    BleNotifyHandler onData,
  ) async {
    final char = _characteristic(characteristicUuid);
    if (char == null) {
      debugPrint('characteristic not found: $characteristicUuid');
      return;
    }
    if (!char.properties.notify && !char.properties.indicate) {
      debugPrint('characteristic does not notify: $characteristicUuid');
      return;
    }
    try {
      // onValueReceived rather than lastValueStream, so a read() elsewhere
      // does not replay the last packet through the telemetry pipeline.
      // cancelWhenDisconnected retires the subscription on link loss, which is
      // what keeps reconnects from stacking duplicate listeners.
      device.cancelWhenDisconnected(char.onValueReceived.listen(onData));
      await char.setNotifyValue(true);
    } catch (e) {
      debugPrint('subscribe failed $characteristicUuid: $e');
    }
  }

  BluetoothCharacteristic? _characteristic(String characteristicUuid) =>
      _service?.characteristics.firstWhereOrNull(
        (c) => c.uuid == Guid(characteristicUuid),
      );

  /// Parses a live IMU notify payload. The firmware sends packed binary
  /// (not JSON): 6x int16 little-endian (ax, ay, az, gx, gy, gz), then
  /// 2x float32 (pitch, roll), 3x int16 pressure, battery (u8), charging (u8).
  ImuNotifyDataModel parseImuNotify(List<int> value) {
    final d = ByteData.sublistView(Uint8List.fromList(value));
    return ImuNotifyDataModel(
      ax: d.getInt16(0, Endian.little),
      ay: d.getInt16(2, Endian.little),
      az: d.getInt16(4, Endian.little),
      gx: d.getInt16(6, Endian.little),
      gy: d.getInt16(8, Endian.little),
      gz: d.getInt16(10, Endian.little),
      pitch: d.getFloat32(12, Endian.little), // 單位：度
      roll: d.getFloat32(16, Endian.little), // 單位：度
      pressure: [
        d.getInt16(20, Endian.little),
        d.getInt16(22, Endian.little),
        d.getInt16(24, Endian.little),
      ],
      batteryPercent: d.getUint8(26),
      isCharging: d.getUint8(27) != 0,
    );
  }

  /// Decodes a UTF-8 JSON notify payload. Record and device-status
  /// notifications still arrive as JSON text.
  Map<String, dynamic> parseJsonNotify(List<int> value) {
    final text = utf8.decode(value);
    return jsonDecode(text) as Map<String, dynamic>;
  }
}
