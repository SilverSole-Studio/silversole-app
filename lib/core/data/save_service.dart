import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveDeviceId(String deviceId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('device_id', deviceId);
}

Future<String?> loadDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('device_id');
}