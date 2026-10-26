import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests [permissions] and reports each one's status. Injectable for tests.
typedef PermissionRequester =
    Future<Map<Permission, PermissionStatus>> Function(
      List<Permission> permissions,
    );

Future<Map<Permission, PermissionStatus>> _requestAll(
  List<Permission> permissions,
) => permissions.request();

/// What scanning for soles needs. The first entry decides the verdict.
///
/// Android 12+ splits Bluetooth into scan and connect, and the pairing sheet
/// has always asked for location alongside. iOS has one Bluetooth
/// permission: permission_handler answers the Android-only scan/connect
/// permissions with `permanentlyDenied` there, and CoreBluetooth needs no
/// location.
List<Permission> bleScanPermissions(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
    ? const [Permission.bluetooth]
    : const [Permission.bluetoothScan, Permission.locationWhenInUse];

/// What connecting to a sole needs. The first entry decides the verdict.
List<Permission> bleConnectPermissions(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
    ? const [Permission.bluetooth]
    : const [Permission.bluetoothConnect];

Future<bool> requestBleScanPermission({PermissionRequester? request}) =>
    _granted(bleScanPermissions(defaultTargetPlatform), request ?? _requestAll);

Future<bool> requestBleConnectPermission({PermissionRequester? request}) =>
    _granted(
      bleConnectPermissions(defaultTargetPlatform),
      request ?? _requestAll,
    );

Future<bool> _granted(
  List<Permission> permissions,
  PermissionRequester request,
) async {
  final statuses = await request(permissions);
  return statuses[permissions.first]?.isGranted ?? false;
}

/// Only Android shows the foreground service's ongoing notification, which is
/// what the notification permission is for.
bool get bleNeedsNotificationPermission =>
    defaultTargetPlatform == TargetPlatform.android;
