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
  /// Debug and release both point at the deployed site. Debug used to default
  /// to a local Cocos preview on :7456, which silently broke every game once
  /// the H5 build moved to Cloudflare — the preview server is usually not even
  /// running, so debug builds just opened a dead URL.
  ///
  /// To serve the games from your machine instead (repo: `silversole-little-
  /// games-html-demo`, `./serve.sh`), point this at it for that run:
  ///
  ///     adb reverse tcp:8080 tcp:8080          # once per USB session
  ///     flutter run --dart-define=GAME_URL=http://localhost:8080/
  ///
  /// `--dart-define` is baked in at launch — a hot restart will not pick up a
  /// change to it.
  ///
  /// Keep the trailing slash — `GameEntry.url` builds `'${gameUrl}game/<slug>/'`.
  static const String _gameUrlOverride = String.fromEnvironment('GAME_URL');
  static String get gameUrl => _gameUrlOverride.isNotEmpty
      ? _gameUrlOverride
      : 'https://h5.silversole.dongyu.company/';
}
