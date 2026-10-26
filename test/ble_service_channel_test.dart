import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.dongyutech.silversole/ble_service');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Android drives the foreground service exactly as before', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await startBleService();
    await updateBleNotification(title: 't', text: 'x');
    await stopBleService();
    expect(calls, ['startBleService', 'updateNotification', 'stopBleService']);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    test(
      '$platform has no foreground service: no channel call, no throw',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        messenger.setMockMethodCallHandler(
          channel,
          null,
        ); // like the real iOS app
        await startBleService();
        await updateBleNotification(title: 't', text: 'x');
        await stopBleService();
      },
    );
  }
}
