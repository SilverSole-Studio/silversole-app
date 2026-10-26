import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/auth/auth_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Google sign-in is offered only where it is wired up (Android)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(googleSignInAvailable, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(googleSignInAvailable, isFalse);
  });
}
