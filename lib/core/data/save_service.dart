import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';

enum LocalSavableKey {
  deviceId('device_id'),
  identity('identity'),
  darkMode('dark_mode'),
  themeVariant('theme_variant'),
  transmissionMethod('transmission_method'),
  pairedDevices('paired_devices'),
  firmwareDevMode('firmware_dev_mode');

  const LocalSavableKey(this.value);

  final String value;
}

Future<void> saveLocalValue(LocalSavableKey key, String value) async {
  final pref = await SharedPreferences.getInstance();
  await pref.setString(key.value, value);
}

Future<String?> loadLocalValue(LocalSavableKey key) async {
  final pref = await SharedPreferences.getInstance();
  return pref.getString(key.value);
}

Future<void> setLocalPairedDevices(List<BlePairedDevice> devicesList) async {
  final prefs = await SharedPreferences.getInstance();
  final list = devicesList.map((item) => jsonEncode(item.toJson())).toList();
  await prefs.setStringList(LocalSavableKey.pairedDevices.value, list);
}

Future<void> setLocalPreferredDevice(BlePairedDevice target) async {
  final devicesList = await loadLocalPairedDevices() ?? [];
  final list = devicesList
      .map(
        (item) =>
            item.copyWith(isPreferred: item.identityKey == target.identityKey),
      )
      .toList();
  await setLocalPairedDevices(list);
}

Future<void> addOrUpdateLocalPairedDevice(BlePairedDevice device) async {
  final devicesList = await loadLocalPairedDevices() ?? [];
  await setLocalPairedDevices(upsertPairedDevice(devicesList, device));
}

/// Records [device] in [list], replacing every entry that is the same sole.
///
/// An entry is the same sole when it has the same chip ID, or the same address
/// with no conflicting ID — the latter is a sole paired on old firmware, which
/// picks up its ID here once it reports one. When several entries match (an
/// old address-only entry and a newer one with the ID), they collapse into one
/// at the first entry's position. [device] supplies every field except that
/// the entries keep a known ID and the primary-device flag.
List<BlePairedDevice> upsertPairedDevice(
  List<BlePairedDevice> list,
  BlePairedDevice device,
) {
  bool isSame(BlePairedDevice entry) {
    final id = device.deviceId;
    if (id != null && entry.deviceId == id) return true;
    if (entry.remoteId != device.remoteId) return false;
    return id == null || entry.deviceId == null;
  }

  final matches = list.where(isSame).toList();
  if (matches.isEmpty) return [...list, device];

  final merged = device.copyWith(
    deviceId:
        device.deviceId ?? matches.map((d) => d.deviceId).nonNulls.firstOrNull,
    isPreferred: matches.any((d) => d.isPreferred),
  );
  final first = list.indexWhere(isSame);
  return [
    for (var i = 0; i < list.length; i++)
      if (i == first) merged else if (!isSame(list[i])) list[i],
  ];
}

/// Marks the sole keyed [identityKey] as worn on [side], clearing that side
/// from every other entry — one foot cannot have two soles. A null [side]
/// only clears the target's own side.
List<BlePairedDevice> assignFootSide(
  List<BlePairedDevice> list,
  String identityKey,
  FootSide? side,
) => [
  for (final entry in list)
    if (entry.identityKey == identityKey)
      entry.copyWith(footSide: side)
    else if (side != null && entry.footSide == side)
      entry.copyWith(footSide: null)
    else
      entry,
];

Future<void> setLocalFootSide(String identityKey, FootSide? side) async {
  final list = await loadLocalPairedDevices() ?? [];
  await setLocalPairedDevices(assignFootSide(list, identityKey, side));
}

Future<void> removeLocalPairedDevice(BlePairedDevice targetDevice) async {
  var devicesList = await loadLocalPairedDevices();
  if (devicesList == null || devicesList.isEmpty) return;
  devicesList = devicesList
      .where((item) => item.identityKey != targetDevice.identityKey)
      .toList();
  await setLocalPairedDevices(devicesList);
}

Future<List<BlePairedDevice>?> loadLocalPairedDevices() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs
      .getStringList(LocalSavableKey.pairedDevices.value)
      ?.map(
        (item) =>
            BlePairedDevice.fromJson(jsonDecode(item) as Map<String, dynamic>),
      )
      .toList();
}
