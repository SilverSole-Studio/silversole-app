import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
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

  // Supabase hashes the raw nonce this way before comparing it with the
  // token's claim; any other encoding fails every iOS sign-in.
  test('the nonce Google gets is the SHA-256 hex of the raw one', () {
    expect(
      hashNonce('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
