import 'package:flutter/services.dart';

const _channel = MethodChannel('com.dongyutech.silversole/ble_service');

Future<void> startBleService() => _channel.invokeMethod('startBleService');
Future<void> stopBleService() => _channel.invokeMethod('stopBleService');

/// Rewrites the service's ongoing notification. Safe to call while the service
/// is stopped: the text is kept for its next start.
Future<void> updateBleNotification({
  required String title,
  required String text,
}) =>
    _channel.invokeMethod('updateNotification', {'title': title, 'text': text});
