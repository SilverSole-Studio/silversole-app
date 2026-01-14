import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/auth/auth_service.dart';
import 'package:silversole/shared/models/auth_model.dart';

class AuthUserNotifier extends Notifier<UserData?> {
  @override
  UserData? build() => null;

  void setUser(UserData? data) => state = data;
}

final authUserProvider = NotifierProvider<AuthUserNotifier, UserData?>(AuthUserNotifier.new);

final authServiceProvider = Provider<AuthService>((_) => AuthService());
