import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants.dart';
import '../../shared/models/auth_model.dart';
import '../error/result.dart';

/// Android and iOS each have their own OAuth client (see
/// `Constants.googleWebClientId`). Before the App Store, guideline 4.8 also
/// requires Sign in with Apple next to this button on iOS.
bool get googleSignInAvailable =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Google's iOS SDK always puts a nonce into the ID token, and Supabase then
/// accepts the token only when handed the raw value the nonce is the SHA-256
/// (hex) of. So iOS asks Google to use [hashNonce] of this one, and hands
/// Supabase this one. Android's tokens carry no nonce and need neither.
final String _googleRawNonce = _randomNonce();

String _randomNonce() {
  final random = Random.secure();
  return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
}

/// The form Supabase compares an ID token's `nonce` claim against.
String hashNonce(String raw) => sha256.convert(utf8.encode(raw)).toString();

/// Must finish before the first `authenticate()`. A no-op where
/// [googleSignInAvailable] is false.
Future<void> initializeGoogleSignIn() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      await GoogleSignIn.instance.initialize(
        serverClientId: Constants.googleWebClientId,
      );
    case TargetPlatform.iOS:
      await GoogleSignIn.instance.initialize(
        clientId: Constants.googleIosClientId,
        serverClientId: Constants.googleWebClientId,
        nonce: hashNonce(_googleRawNonce),
      );
    default:
      return;
  }
}

/// The user closed Google's account picker. Not a failure worth a message.
class SignInCanceled implements Exception {
  const SignInCanceled();
}

/// [AuthService.deleteAccount] could not tell whether the account was
/// deleted, and signed out anyway — so the app is signed out despite the error.
class AccountDeletionUnconfirmed implements Exception {
  const AccountDeletionUnconfirmed();

  @override
  String toString() => 'delete_account_unconfirmed'.tr();
}

/// Calls the `delete-account` Edge Function and returns its HTTP status.
/// Throws when no response came back at all.
typedef DeleteAccountCall = Future<int> Function();

/// Asks the Auth server whether the signed-in user still exists: true, false,
/// or null when it cannot tell (offline).
typedef AccountExistsCheck = Future<bool?> Function();

class AuthService {
  /// The three seams exist so [deleteAccount] can be tested without Supabase;
  /// the app uses the defaults.
  AuthService({
    DeleteAccountCall? deleteAccountCall,
    AccountExistsCheck? accountStillExists,
    Future<void> Function()? localSignOut,
  }) : _deleteAccountCall = deleteAccountCall ?? _invokeDeleteAccount,
       _accountStillExists = accountStillExists ?? _checkAccountStillExists,
       _localSignOut = localSignOut ?? _signOutLocally;

  final DeleteAccountCall _deleteAccountCall;
  final AccountExistsCheck _accountStillExists;
  final Future<void> Function() _localSignOut;

  static Future<int> _invokeDeleteAccount() async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'delete-account',
        method: HttpMethod.post,
      );
      return res.status;
    } on FunctionException catch (e) {
      // Any non-2xx arrives as an exception; its status is the answer.
      return e.status;
    }
  }

  static Future<bool?> _checkAccountStillExists() async {
    try {
      final res = await Supabase.instance.client.auth.getUser();
      return res.user != null;
    } on AuthApiException catch (e) {
      // The token's user is gone: Auth answers 401/403/404 or user_not_found.
      final status = int.tryParse(e.statusCode ?? '');
      if (e.code == 'user_not_found' ||
          status == 401 ||
          status == 403 ||
          status == 404) {
        return false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Drops this phone's session without asking the server — whose answer for
  /// a deleted user would only be an error — and Google's cached account.
  static Future<void> _signOutLocally() async {
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('delete account: local sign-out failed: $e');
    }
    if (googleSignInAvailable) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('delete account: Google sign-out failed: $e');
      }
    }
  }

  /// Deletes the signed-in user's account through the `delete-account` Edge
  /// Function (`supabase/functions/delete-account`), then signs out here.
  ///
  /// Never leaves a session pointing at a deleted user: 401/404 mean the user
  /// is already gone, and when the call fails the Auth server is asked whether
  /// the user still exists. Only a user known to still exist stays signed in.
  /// When even that cannot be checked, this signs out anyway and says the
  /// deletion is unconfirmed.
  Future<Result<void>> deleteAccount() async {
    int? status;
    try {
      status = await _deleteAccountCall();
    } catch (e) {
      debugPrint('delete account: no response: $e');
    }
    if (status != null &&
        ((status >= 200 && status < 300) || status == 401 || status == 404)) {
      await _safeLocalSignOut();
      return const Result.ok(null);
    }

    switch (await _accountStillExists()) {
      case false:
        await _safeLocalSignOut();
        return const Result.ok(null);
      case true:
        return Result.error(Exception('delete_account_failed'.tr()));
      case null:
        await _safeLocalSignOut();
        return const Result.error(AccountDeletionUnconfirmed());
    }
  }

  Future<void> _safeLocalSignOut() async {
    try {
      await _localSignOut();
    } catch (e) {
      debugPrint('delete account: local sign-out failed: $e');
    }
  }

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
        nonce: defaultTargetPlatform == TargetPlatform.iOS
            ? _googleRawNonce
            : null,
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
      if (googleSignInAvailable) {
        await GoogleSignIn.instance.signOut();
      }
      return const Result.ok(null);
    } catch (e) {
      return Result.error(Exception('Sign out failed.\n$e'));
    }
  }
}
