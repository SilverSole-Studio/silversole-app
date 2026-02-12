class AppSettings {
  final String? identity;
  final String? deviceId;
  final bool? _darkMode;
  bool get darkMode => _darkMode ?? true;

  const AppSettings({this.identity, this.deviceId, bool? darkMode}) : _darkMode = darkMode;

  AppSettings copyWith({String? identity, String? deviceId, bool? darkMode}) {
    return AppSettings(
      identity: identity ?? this.identity,
      deviceId: deviceId ?? this.deviceId,
      darkMode: darkMode ?? _darkMode,
    );
  }
}
