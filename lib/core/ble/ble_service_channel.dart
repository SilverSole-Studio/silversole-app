import 'package:flutter/services.dart';

const _channel = MethodChannel('com.andongni.silversole/ble_service');

Future<void> startBleService() => _channel.invokeMethod('startBleService');
Future<void> stopBleService() => _channel.invokeMethod('stopBleService');