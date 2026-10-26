import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/auth_model.dart';
import '../error/result.dart';

/// iOS has no OAuth client yet (see `Constants.googleWebClientId`), and App
/// Store guideline 4.8 would also require Sign in with Apple. Until both
/// exist, the button is hidden there rather than always failing.
bool get googleSignInAvailable =>
    defaultTargetPlatform == TargetPlatform.android;

/// The user closed Google's account picker. Not a failure worth a message.
class SignInCanceled implements Exception {
  const SignInCanceled();
}

class AuthService {
  Future<Result<UserData>> supabaseSignIn(String email, String password) async {
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      final session = res.session;

      if (session == null || user == null) {
        return Result.error(Exception('Sign in failed.'));
      }

      return Result.ok(UserData(email: user.email ?? '', uuid: user.id));
    } on AuthApiException catch (e) {
      return Result.error(Exception(e.code.toString().tr()));
    } on AuthException catch (e) {
      return Result.error(e);
    } catch (e) {
      return Result.error(Exception('Sign in failed.'));
    }
  }

  /// Native Google sign-in, then a Supabase session from Google's ID token.
  /// A first sign-in creates the Supabase account, so this serves sign-up too.
  /// Android-only for now (see `Constants.googleWebClientId`).
  Future<Result<UserData>> supabaseSignInWithGoogle() async {
    if (!googleSignInAvailable) {
      return Result.error(Exception('google_sign_in_unsupported'.tr()));
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return Result.error(Exception('google_sign_in_failed'.tr()));
      }
      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: await _googleAccessToken(account),
      );
      final user = res.user;
      if (res.session == null || user == null) {
        return Result.error(Exception('google_sign_in_failed'.tr()));
      }
      return Result.ok(UserData(email: user.email ?? '', uuid: user.id));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Result.error(SignInCanceled());
      }
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      return Result.error(
        Exception('${'google_sign_in_failed'.tr()} (${e.code.name})'),
      );
    } on AuthApiException catch (e) {
      debugPrint(
        'Supabase Google sign-in failed: ${e.statusCode} ${e.code} ${e.message}',
      );
      // Supabase leaves `code` null for some rejections (e.g. a token whose
      // audience the Google provider does not list); its message is then the
      // only clue, so show that rather than translating "null".
      final code = e.code;
      return Result.error(Exception(code == null ? e.message : code.tr()));
    } on AuthException catch (e) {
      return Result.error(e);
    }
  }

  /// Supabase only uses the access token to cross-check the ID token, so a
  /// missing one is not fatal: ask only for what was already granted, without
  /// a second consent screen.
  Future<String?> _googleAccessToken(GoogleSignInAccount account) async {
    try {
      final authorization = await account.authorizationClient
          .authorizationForScopes(const ['email', 'profile']);
      return authorization?.accessToken;
    } on GoogleSignInException {
      return null;
    }
  }

  Future<Result<void>> supabaseSignUp(String email, String password) async {
    final res = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );

    if (res.user == null) {
      return Result.error(Exception('Sign up failed.'));
    }

    // return supabaseSignIn(email, password);
    return Result.ok(null);
  }

  Future<Result<void>> supabaseSignOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      // Otherwise the next Google sign-in silently reuses this account
      // instead of offering the picker.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await GoogleSignIn.instance.signOut();
      }
      return const Result.ok(null);
    } catch (e) {
      return Result.error(Exception('Sign out failed.\n$e'));
    }
  }
}
