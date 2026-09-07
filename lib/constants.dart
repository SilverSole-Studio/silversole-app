import 'package:flutter/foundation.dart';

abstract class Constants {
  /// Dev escape hatch: land guests on the home screen instead of bouncing them
  /// to `/sign-in`, so device/BLE work does not need a Supabase session.
  ///
  /// Honoured in **debug builds only** — the router ANDs this with
  /// [kDebugMode], so a release build always enforces the gate no matter what
  /// this is set to. Every screen that needs a user already degrades to a
  /// `not_signed_in` message, so the app is usable as a guest; anything backed
  /// by Supabase (recent data, binding, analytics) will simply stay empty.
  ///
  /// Set to `false` to get the normal sign-in flow back. `/sign-in` is still
  /// reachable by hand while this is on.
  static const bool skipAuthGate = true;

  static const String supabaseUrlKey = 'PUBLIC_SUPABASE_URL';
  static const String supabasePublicDefaultKey =
      'PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY';
  static const String apiLatestReleaseUrl =
      'https://api.github.com/repos/andongni0723/silversole-app/releases/latest';
  static const String latestReleaseUrl =
      'https://github.com/andongni0723/silversole-app/releases/latest';
  static const String releaseDownloadUrl =
      'https://github.com/andongni0723/silversole-app/releases/download';
  static const String appGithubUrl =
      'https://api.github.com/andongni0723/silversole-app';

  /// Base URL for the H5 mini-games loaded in [GameWebViewPage].
  ///
  /// Override at run time with `--dart-define=GAME_URL=...` (e.g. point it at
  /// the Cocos preview server). Otherwise: debug → local dev server, release →
  /// the production site.
  /// Keep the trailing slash — `GameEntry.url` builds `'${gameUrl}game/<slug>/'`.
  static const String _gameUrlOverride = String.fromEnvironment('GAME_URL');
  static String get gameUrl => _gameUrlOverride.isNotEmpty
      ? _gameUrlOverride
      // Debug → local Cocos preview. Requires `adb reverse tcp:7456 tcp:7456`
      // (run once per session); works on both USB devices and emulators.
      // (10.0.2.2 would only work on an emulator — this device is USB.)
      : (kDebugMode
            ? 'http://localhost:7456/'
            : 'https://h5.silversole.dongyu.company/');
}
