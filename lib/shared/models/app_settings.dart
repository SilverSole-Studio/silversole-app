import 'package:easy_localization/easy_localization.dart';

enum TransmissionMethod { bluetooth, wifi }

extension TransmissionMethodValue on TransmissionMethod {
  static TransmissionMethod? fromValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final method in TransmissionMethod.values) {
      if (method.name == value) return method;
    }
    return null;
  }

  static String toFormatString(TransmissionMethod method) => method.name.tr();
}

class AppSettings {
  final String? identity;
  final String? deviceId;
  final bool? _darkMode;
  final TransmissionMethod? _transmissionMethod;

  bool get darkMode => _darkMode ?? true;

  TransmissionMethod get transmissionMethod => _transmissionMethod ?? TransmissionMethod.bluetooth;

  const AppSettings({this.identity, this.deviceId, bool? darkMode, TransmissionMethod? transmissionMethod})
    : _darkMode = darkMode,
      _transmissionMethod = transmissionMethod;

  AppSettings copyWith({String? identity, String? deviceId, bool? darkMode, TransmissionMethod? transmissionMethod}) {
    return AppSettings(
      identity: identity ?? this.identity,
      deviceId: deviceId ?? this.deviceId,
      darkMode: darkMode ?? _darkMode,
      transmissionMethod: transmissionMethod ?? _transmissionMethod,
    );
  }
}
