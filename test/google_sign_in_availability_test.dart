import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/auth/auth_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Google sign-in is offered where an OAuth client exists', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(googleSignInAvailable, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(googleSignInAvailable, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(googleSignInAvailable, isFalse);
  });

  // Guideline 4.8: wherever iOS offers Google, it must offer Apple too.
  test('Sign in with Apple is offered on iOS, next to Google', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(appleSignInAvailable, isTrue);
    expect(googleSignInAvailable, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(appleSignInAvailable, isFalse);
  });

  test('the privacy policy follows the app language', () {
    expect(Constants.privacyPolicyUrl('zh'), endsWith('/privacy/'));
    expect(Constants.privacyPolicyUrl('en'), endsWith('/privacy/en/'));
  });

  // Supabase hashes the raw nonce this way before comparing it with the
  // token's claim; any other encoding fails every iOS sign-in.
  test('the nonce Google gets is the SHA-256 hex of the raw one', () {
    expect(
      hashNonce('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
