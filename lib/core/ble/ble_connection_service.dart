import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

class BleConnectionService {
  final _notifySubMap = <String, StreamSubscription<List<int>>>{};
  final _notifyCharMap = <String, BluetoothCharacteristic>{};

  /// Builds a stable cache key from [remoteId], [serviceUuid], and [characteristicUuid].
  String _notifyKey({
    required String remoteId,
    required String serviceUuid,
    required String characteristicUuid,
  }) =>
      '$remoteId|${serviceUuid.toLowerCase()}|${characteristicUuid.toLowerCase()}';

  /// Connects to the BLE [device] and returns the corresponding [BluetoothDevice].
  ///
  /// If the target is already connected, this is a no-op and returns immediately.
  Future<BluetoothDevice> connect(BlePairedDevice device) async {
    final target = BluetoothDevice.fromId(device.remoteId);

    // Reconnect
    if (target.isDisconnected) {
      await target.connect(
        license: License.free,
        timeout: Duration(seconds: 20),
        autoConnect: false,
        mtu: 512,
      );
    }
    return target;
  }

  bool checkConnect(BlePairedDevice device) =>
      BluetoothDevice.fromId(device.remoteId).isConnected;

  /// Disconnects the BLE [device] and clears all notify subscriptions for that device.
  ///
  /// This method:
  /// - Cancels cached stream subscriptions.
  /// - Attempts to disable notifications via [BluetoothCharacteristic.setNotifyValue].
  /// - Disconnects only when the device is currently connected.
  Future<void> disconnect(BlePairedDevice device) async {
    // Clear cache with same remoteId
    final remoteId = device.remoteId;
    final keys = _notifySubMap.keys
        .where((key) => key.startsWith('$remoteId|'))
        .toList();
    for (final key in keys) {
      final sub = _notifySubMap.remove(key);
      await sub?.cancel();

      final ch = _notifyCharMap.remove(key);
      try {
        await ch?.setNotifyValue(false);
      } catch (_) {}
    }

    // Disconnect
    final target = BluetoothDevice.fromId(device.remoteId);
    if (target.isConnected) {
      await target.disconnect();
    }
  }

  /// Discovers all GATT services for the given [device].
  ///
  /// The caller should ensure the device is connected before calling this method.
  Future<void> discoverServices(BlePairedDevice device) async {
    final target = BluetoothDevice.fromId(device.remoteId);
    await target.discoverServices();
  }

  /// Subscribes to notifications for a specific characteristic on [device].
  ///
  /// The subscription target is identified by [serviceUuid] and [characteristicUuid].
  /// Received payloads are forwarded to [onData].
  ///
  /// Returns:
  /// - [Result.ok] with the created [StreamSubscription] on success.
  /// - [Result.error] if connection/discovery/subscription fails.
  ///
  /// If an existing subscription for the same key already exists, it will be
  /// canceled and replaced by the new one.
  Future<Result<StreamSubscription<List<int>>>> subscribeNotify(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
    required void Function(List<int> value) onData,
  }) async {
    try {
      // Get device detail
      final target = await connect(device);
      final services = await target.discoverServices();

      final sUuid = Guid(serviceUuid);
      final cUuid = Guid(characteristicUuid);

      final targetChar = services
          .firstWhereOrNull((s) => s.uuid == sUuid)
          ?.characteristics
          .firstWhereOrNull((c) => c.uuid == cUuid);

      // Check device detail exist
      if (targetChar == null) {
        return Result.error(
          Exception(
            'Characteristic not found: $serviceUuid / $characteristicUuid',
          ),
        );
      }

      if (!targetChar.properties.notify && !targetChar.properties.indicate) {
        return Result.error(
          Exception('Characteristic not support notify or indicate'),
        );
      }

      // Alter Map cache
      final key = _notifyKey(
        remoteId: device.remoteId,
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
      );

      final oldSub = _notifySubMap.remove(key);
      await oldSub?.cancel();

      final oldChar = _notifyCharMap.remove(key);
      try {
        await oldChar?.setNotifyValue(false);
      } catch (_) {}

      // Subscribe Notify
      await targetChar.setNotifyValue(true);
      final sub = targetChar.onValueReceived.listen(onData);

      _notifySubMap[key] = sub;
      _notifyCharMap[key] = targetChar;

      return Result.ok(sub);
    } catch (e) {
      return Result.error(Exception('subscribeNotify failed: $e'));
    }
  }

  /// Unsubscribes notifications for [device], [serviceUuid], and [characteristicUuid].
  ///
  /// This cancels the cached stream subscription and attempts to disable
  /// notifications on the characteristic.
  Future<void> unsubscribeNotify(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    final key = _notifyKey(
      remoteId: device.remoteId,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
    );

    final sub = _notifySubMap.remove(key);
    await sub?.cancel();

    final ch = _notifyCharMap.remove(key);
    try {
      await ch?.setNotifyValue(false);
    } catch (_) {}
  }

  Future<Result<String>> readStringCharacteristic(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    try {
      // check characteristic exist
      final target = await connect(device);
      final services = await target.discoverServices();
      final s = services.firstWhereOrNull((s) => s.uuid == Guid(serviceUuid));
      final c = s?.characteristics.firstWhereOrNull(
        (c) => c.uuid == Guid(characteristicUuid),
      );
      if (c == null) return Result.error(Exception('Characteristic not found'));

      final bytes = await c.read();
      return Result.ok(utf8.decode(bytes).trim());
    } catch (e) {
      return Result.error(Exception('readStringCharacteristic failed: $e'));
    }
  }

  Future<Result<void>> writeCharacteristic(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
    required List<int> value,
    bool withoutResponse = false,
  }) async {
    try {
      // check characteristic exist
      final target = await connect(device);
      final services = await target.discoverServices();
      final s = services.firstWhereOrNull((s) => s.uuid == Guid(serviceUuid));
      final c = s?.characteristics.firstWhereOrNull(
        (c) => c.uuid == Guid(characteristicUuid),
      );
      if (c == null) return Result.error(Exception('Characteristic not found'));

      await c.write(value, withoutResponse: withoutResponse);
      return Result.ok(null);
    } catch (e) {
      return Result.error(Exception('WriteCharacteristic failed: $e'));
    }
  }

  Future<Result<void>> writeBoolCharacteristic(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
    required bool value,
    bool withoutResponse = false,
  }) async {
    return writeCharacteristic(
      device,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      value: utf8.encode(value ? '1' : '0'),
      withoutResponse: withoutResponse,
    );
  }

  Future<Result<void>> writeStringCharacteristic(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
    required String value,
    bool withoutResponse = false,
  }) async {
    return writeCharacteristic(
      device,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      value: utf8.encode(value),
      withoutResponse: withoutResponse,
    );
  }

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
