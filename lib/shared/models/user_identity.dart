enum UserIdentity {
  transmitter('transmitter'),
  observer('observer');

  const UserIdentity(this.value);
  final String value;
}