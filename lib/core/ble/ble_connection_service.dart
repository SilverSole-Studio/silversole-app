import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

class BleConnectionService {
  final _notifySubMap = <String, StreamSubscription<List<int>>>{};
  final _notifyCharMap = <String, BluetoothCharacteristic>{};

  /// Builds a stable cache key from [remoteId], [serviceUuid], and [characteristicUuid].
  String _notifyKey({required String remoteId, required String serviceUuid, required String characteristicUuid}) =>
      '$remoteId|${serviceUuid.toLowerCase()}|${characteristicUuid.toLowerCase()}';

  /// Connects to the BLE [device] and returns the corresponding [BluetoothDevice].
  ///
  /// If the target is already connected, this is a no-op and returns immediately.
  Future<BluetoothDevice> connect(BlePairedDevice device) async {
    final target = BluetoothDevice.fromId(device.remoteId);

    // Reconnect
    if (target.isDisconnected) {
      await target.connect(license: License.free, timeout: Duration(seconds: 20), autoConnect: false, mtu: 512);
    }
    return target;
  }

  /// Disconnects the BLE [device] and clears all notify subscriptions for that device.
  ///
  /// This method:
  /// - Cancels cached stream subscriptions.
  /// - Attempts to disable notifications via [BluetoothCharacteristic.setNotifyValue].
  /// - Disconnects only when the device is currently connected.
  Future<void> disconnect(BlePairedDevice device) async {
    // Clear cache with same remoteId
    final remoteId = device.remoteId;
    final keys = _notifySubMap.keys.where((key) => key.startsWith('$remoteId|')).toList();
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
        return Result.error(Exception('Characteristic not found: $serviceUuid / $characteristicUuid'));
      }

      if (!targetChar.properties.notify && !targetChar.properties.indicate) {
        return Result.error(Exception('Characteristic not support notify or indicate'));
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
    final key = _notifyKey(remoteId: device.remoteId, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid);

    final sub = _notifySubMap.remove(key);
    await sub?.cancel();

    final ch = _notifyCharMap.remove(key);
    try {
      await ch?.setNotifyValue(false);
    } catch (_) {}
  }

  /// Reconnects to [device] if needed, then re-subscribes notify callbacks.
  ///
  /// This is a convenience wrapper around [connect] and [subscribeNotify].
  /// It returns the same [Result] contract as [subscribeNotify].
  Future<Result<StreamSubscription<List<int>>>> reconnectIfNeed(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
    required void Function(List<int> value) onData,
  }) async {
    try {
      final target = BluetoothDevice.fromId(device.remoteId);
      if (target.isDisconnected) await connect(device);
      return await subscribeNotify(
        device,
        serviceUuid: serviceUuid,
        characteristicUuid: characteristicUuid,
        onData: onData,
      );
    } catch (e) {
      return Result.error(Exception('reconnectIfNeed failed: $e'));
    }
  }

  Future<Result<String>> readStringCharacteristic(
    BlePairedDevice device, {
    required String serviceUuid,
    required String characteristicUuid,
  }) async {
    try {
      final target = await connect(device);
      final services = await target.discoverServices();

      final s = services.firstWhereOrNull((s) => s.uuid == Guid(serviceUuid));
      final c = s?.characteristics.firstWhereOrNull((c) => c.uuid == Guid(characteristicUuid));
      if (c == null) return Result.error(Exception('Characteristic not found'));

      final bytes = await c.read();
      return Result.ok(utf8.decode(bytes).trim());
    } catch (e) {
      return Result.error(Exception('readStringCharacteristic failed: $e'));
    }
  }

  Map<String, dynamic> parseImuNotify(List<int> value) {
    final text = utf8.decode(value);
    return jsonDecode(text) as Map<String, dynamic>;
  }
}
