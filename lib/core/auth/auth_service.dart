import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/auth_model.dart';
import '../error/result.dart';

class AuthService {
  Future<Result<UserData>> supabaseSignIn(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);

      final user = res.user;
      final session = res.session;

      if (session == null || user == null) {
        return Result.error(Exception('Sign in failed.'));
      }

      return Result.ok(UserData(email: user.email ?? '', uuid: user.id));
    } on AuthApiException catch (e) {
      return Result.error(Exception(e.code.toString().tr()));
    } on AuthException catch(e) {
      return Result.error(e);
    } catch (e) {
      return Result.error(Exception('Sign in failed.'));
    }
  }

  Future<Result<void>> supabaseSignUp(String email, String password) async {
    final res = await Supabase.instance.client.auth.signUp(email: email, password: password);

    if (res.user == null) {
      return Result.error(Exception('Sign up failed.'));
    }

    // return supabaseSignIn(email, password);
    return Result.ok(null);
  }

  Future<Result<void>> supabaseSignOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      return const Result.ok(null);
    } catch (e) {
      return Result.error(Exception('Sign out failed.\n$e'));
    }
  }
}
