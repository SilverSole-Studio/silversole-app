class UserData {
  final String email;
  final String uuid;
  String? localDeviceId;

  UserData({required this.email, required this.uuid, this.localDeviceId});
}
