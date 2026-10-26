import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.dongyutech.silversole/ble_service');

/// Only Android has the foreground service (MainActivity.kt). iOS keeps BLE
/// alive through the `bluetooth-central` background mode instead, so off
/// Android every call here is a no-op rather than a MissingPluginException.
bool get _hasService => defaultTargetPlatform == TargetPlatform.android;

Future<void> startBleService() async {
  if (_hasService) await _channel.invokeMethod('startBleService');
}

Future<void> stopBleService() async {
  if (_hasService) await _channel.invokeMethod('stopBleService');
}

/// Rewrites the service's ongoing notification. Safe to call while the service
/// is stopped: the text is kept for its next start.
Future<void> updateBleNotification({
  required String title,
  required String text,
}) async {
  if (_hasService) {
    await _channel.invokeMethod('updateNotification', {
      'title': title,
      'text': text,
    });
  }
}
