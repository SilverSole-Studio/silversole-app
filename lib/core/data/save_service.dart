import 'package:shared_preferences/shared_preferences.dart';

enum LocalSavableKey {
  deviceId('device_id'),
  identity('identity');

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

Future<void> saveDeviceId(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('device_id', deviceId);
}

Future<String?> loadDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('device_id');
}