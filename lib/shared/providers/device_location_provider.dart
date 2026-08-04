import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/sole_provider.dart';

/// The device's most recent reported position, or null when the device is
/// unbound or has never reported one.
///
/// Both themes' map screens read this, so "last located" means the same thing
/// on either design. Rows come back newest-first from
/// `SilverSoleService.getRecentDeviceLocation`.
final latestDeviceLocationProvider = FutureProvider<DeviceLocationModel?>((
  ref,
) async {
  final deviceId = ref.watch(settingsProvider).deviceId;
  if (deviceId == null || deviceId.isEmpty) return null;

  final result = await ref
      .read(soleProvider)
      .getRecentDeviceLocation(deviceId: deviceId);

  return switch (result) {
    Ok<List<DeviceLocationModel>>() =>
      result.value.isEmpty ? null : result.value.first,
    Error() => throw result.error,
  };
});
