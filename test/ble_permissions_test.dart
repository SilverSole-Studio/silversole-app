import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/ble/ble_permissions.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android keeps the scan/connect/location set it always asked for', () {
    expect(bleScanPermissions(TargetPlatform.android), [
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ]);
    expect(bleConnectPermissions(TargetPlatform.android), [
      Permission.bluetoothConnect,
    ]);
  });

  test(
    'iOS asks for Bluetooth alone — no location, no Android-only scan/connect',
    () {
      expect(bleScanPermissions(TargetPlatform.iOS), [Permission.bluetooth]);
      expect(bleConnectPermissions(TargetPlatform.iOS), [Permission.bluetooth]);
    },
  );

  test(
    'the verdict is the first (Bluetooth) permission, not location',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      List<Permission>? asked;
      final granted = await requestBleScanPermission(
        request: (ps) async {
          asked = ps;
          return {
            Permission.bluetoothScan: PermissionStatus.granted,
            Permission.locationWhenInUse: PermissionStatus.denied,
          };
        },
      );
      expect(asked, [Permission.bluetoothScan, Permission.locationWhenInUse]);
      expect(granted, isTrue);
    },
  );

  test('a refused Bluetooth permission on iOS is false, not a throw', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      await requestBleScanPermission(
        request: (_) async => {
          Permission.bluetooth: PermissionStatus.permanentlyDenied,
        },
      ),
      isFalse,
    );
    expect(
      await requestBleConnectPermission(
        request: (_) async => {Permission.bluetooth: PermissionStatus.denied},
      ),
      isFalse,
    );
  });

  test('only Android asks for the notification permission', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(bleNeedsNotificationPermission, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(bleNeedsNotificationPermission, isFalse);
  });
}
