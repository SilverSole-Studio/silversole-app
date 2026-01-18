class AppSettings {
  final String? identity;
  final String? deviceId;

  const AppSettings({this.identity, this.deviceId});

  AppSettings copyWith({String? identity, String? deviceId}) {
    return AppSettings(identity: identity ?? this.identity, deviceId: deviceId ?? this.deviceId);
  }
}
