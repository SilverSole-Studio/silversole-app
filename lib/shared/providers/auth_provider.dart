import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/auth/auth_service.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUserNotifier extends Notifier<UserData?> {
  @override
  UserData? build() {
    final auth = Supabase.instance.client.auth;

    final sub = auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      state = user != null ? UserData(email: user.email ?? '', uuid: user.id) : null;
    });
    ref.onDispose(sub.cancel);

    final user = auth.currentUser;
    return user != null ? UserData(email: user.email ?? '', uuid: user.id) : null;
  }

  void setUser(UserData? data) => state = data;
}

final authUserProvider = NotifierProvider<AuthUserNotifier, UserData?>(AuthUserNotifier.new);

final authServiceProvider = Provider<AuthService>((_) => AuthService());
