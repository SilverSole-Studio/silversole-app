import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:silversole/core/ble/ble_uuids.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/pressure_channel_fix.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

/// Raw notify payload from the sole.
typedef BleNotifyHandler = void Function(List<int> value);

/// What one connection's handshake learned about the sole.
@immutable
class SoleSessionInfo {
  const SoleSessionInfo({
    this.deviceId,
    this.firmwareVersion,
    required this.dfuSupported,
  });

  /// The chip ID, or null on firmware from before the ID existed.
  final String? deviceId;

  /// The DFU `version` string as the sole reports it, e.g. `0.4.0-rc.1`.
  final String? firmwareVersion;

  /// False on firmware without the DFU service: it can only be updated by
  /// wire.
  final bool dfuSupported;
}

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
  /// [SoleSessionInfo.deviceId] is null when the sole reported no chip ID
  /// (firmware from before the ID existed, or a failed read).
  final void Function(SoleSessionInfo info)? onReady;

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
  /// The firmware's `conn_gatt.att_mtu`. OTA needs at least 68 (APPLY is 65
  /// bytes plus the 3-byte ATT header) and fills each data packet up to
  /// `mtu − 3`; the negotiated value is `min(request, firmware)` anyway.
  static const _preferredMtu = 247;

  static const _connectTimeout = Duration(seconds: 15);
  static const _maxBackoffSeconds = 30;

  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _stateSub;
  BluetoothService? _service;
  BluetoothService? _dfuService;
  BleSessionHandlers? _handlers;
  bool _settingUp = false;
  bool _setupPending = false;

  /// True between [attach] and [detach]. Gates the reconnect loop so a
  /// deliberate teardown is not immediately undone by it.
  bool _wanted = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  /// Bumped on every link loss and on [detach]. A [_BleDfuLink] captures the
  /// epoch at creation, so once its session has dropped it stays reported as
  /// disconnected even if the service's own backoff brings the same MAC back
  /// within the page-wait: that reconnect is a new session, and resending
  /// into it would hit a sole that has reset to IDLE.
  int _sessionEpoch = 0;

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
            _sessionEpoch++;
            _service = null;
            _dfuService = null;
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
    _sessionEpoch++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;

    await _stateSub?.cancel();
    _stateSub = null;
    _service = null;
    _dfuService = null;
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

  /// The connected sole's DFU service as a [DfuLink], or null when nothing is
  /// connected or the firmware has no DFU service.
  DfuLink? dfuLink() {
    final device = _device;
    final dfu = _dfuService;
    if (device == null || dfu == null || !device.isConnected) return null;
    BluetoothCharacteristic? find(String uuid) =>
        dfu.characteristics.firstWhereOrNull((c) => c.uuid == Guid(uuid));
    final control = find(dfuControlCharUuid);
    final data = find(dfuDataCharUuid);
    if (control == null || data == null) return null;
    return _BleDfuLink(
      device,
      control,
      data,
      _sessionEpoch,
      () => _sessionEpoch,
    );
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
      // The chip ID comes from the Device Information Service's Serial
      // Number — deliberately not the main service's old device-id
      // characteristic, which the firmware declares but never fills in.
      final deviceId = await _readText(
        services,
        deviceInfoServiceUuid,
        serialNumberCharUuid,
      );
      // Firmware without the DFU service can only be updated by wire, which
      // is worth knowing before offering an update.
      final dfu = services.firstWhereOrNull(
        (s) => s.uuid == Guid(dfuServiceUuid),
      );
      _dfuService = dfu;
      final firmwareVersion = dfu == null
          ? null
          : await _readText(services, dfuServiceUuid, dfuVersionCharUuid);

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

      handlers.onReady?.call(
        SoleSessionInfo(
          deviceId: deviceId,
          firmwareVersion: firmwareVersion,
          dfuSupported: dfu != null,
        ),
      );

      // Notifications last.
      await _subscribe(device, notifyCharUuid, handlers.onImu);
      await _subscribe(device, recordNotifyCharUuid, handlers.onRecordImu);
      await _subscribe(device, fallDetectCharUuid, handlers.onFallDetect);
      await _subscribe(device, deviceStatusCharUuid, handlers.onDeviceStatus);
    } catch (e) {
      debugPrint('session setup failed: $e');
    }
  }

  /// Reads a UTF-8 characteristic out of this connection's one discovery, or
  /// null when the sole does not have it (older firmware) or the read fails.
  Future<String?> _readText(
    List<BluetoothService> services,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final char = services
        .firstWhereOrNull((s) => s.uuid == Guid(serviceUuid))
        ?.characteristics
        .firstWhereOrNull((c) => c.uuid == Guid(characteristicUuid));
    if (char == null) {
      debugPrint('no $characteristicUuid — the firmware predates it');
      return null;
    }
    try {
      final text = utf8.decode(await char.read()).trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('read $characteristicUuid failed: $e');
      return null;
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
      // Hardware workaround, see fixPressureChannels: this board's heel and
      // big-toe-ball pads are swapped.
      pressure: fixPressureChannels([
        d.getInt16(20, Endian.little),
        d.getInt16(22, Endian.little),
        d.getInt16(24, Endian.little),
      ]),
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

class _BleDfuLink implements DfuLink {
  _BleDfuLink(
    this._device,
    this._control,
    this._data,
    this._epoch,
    this._epochNow,
  );

  final BluetoothDevice _device;
  final BluetoothCharacteristic _control;
  final BluetoothCharacteristic _data;

  /// The service's [BleConnectionService._sessionEpoch] when this link was
  /// created.
  final int _epoch;

  /// The service's current epoch, read live.
  final int Function() _epochNow;

  @override
  int get mtu => _device.mtuNow;

  @override
  bool get isConnected => _device.isConnected && _epochNow() == _epoch;

  @override
  Future<Stream<List<int>>> subscribeStatus() async {
    await _control.setNotifyValue(true);
    // onValueReceived, not lastValueStream: a stale STATUS must not be
    // replayed into a new transfer.
    return _control.onValueReceived;
  }

  @override
  Future<void> writeControl(List<int> bytes) =>
      _write(_control, bytes, withoutResponse: false);

  @override
  Future<void> writeData(List<int> bytes) =>
      _write(_data, bytes, withoutResponse: true);

  /// One ATT packet per write, always: the sole cannot take long writes (it
  /// stalls for ~30 s, then drops the link).
  Future<void> _write(
    BluetoothCharacteristic char,
    List<int> bytes, {
    required bool withoutResponse,
  }) async {
    final max = _device.mtuNow - 3;
    if (bytes.length > max) {
      throw ArgumentError('${bytes.length} bytes exceed one ATT write ($max)');
    }
    await char.write(
      bytes,
      withoutResponse: withoutResponse,
      allowLongWrite: false,
    );
  }
}
