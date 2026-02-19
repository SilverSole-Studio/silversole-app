import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

enum LocalSavableKey {
  deviceId('device_id'),
  identity('identity'),
  darkMode('dark_mode'),
  transmissionMethod('transmission_method'),
  pairedDevices('paired_devices');

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
  final list = devicesList.map((item) => item.copyWith(isPreferred: item.remoteId == target.remoteId)).toList();
  await setLocalPairedDevices(list);
}

Future<void> addOrUpdateLocalPairedDevice(BlePairedDevice device) async {
  var devicesList = await loadLocalPairedDevices() ?? [];
  final index = devicesList.indexWhere((item) => item.remoteId == device.remoteId);
  if (index >= 0) {
    final current = devicesList[index];
    devicesList[index] = device.copyWith(isPreferred: current.isPreferred);
  } else {
    devicesList.add(device);
  }
  await setLocalPairedDevices(devicesList);
}

Future<void> removeLocalPairedDevice(BlePairedDevice targetDevice) async {
  var devicesList = await loadLocalPairedDevices();
  if (devicesList == null || devicesList.isEmpty) return;
  devicesList = devicesList.where((item) => item.remoteId != targetDevice.remoteId).toList();
  await setLocalPairedDevices(devicesList);
}

Future<List<BlePairedDevice>?> loadLocalPairedDevices() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs
      .getStringList(LocalSavableKey.pairedDevices.value)
      ?.map((item) => BlePairedDevice.fromJson(jsonDecode(item) as Map<String, dynamic>))
      .toList();
}
