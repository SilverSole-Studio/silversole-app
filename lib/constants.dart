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

  /// OAuth *web* client in the `silversole` GCP project — the one the Supabase
  /// Google provider is configured with. Native sign-in asks Google for an ID
  /// token addressed to it, which is what lets Supabase accept the token. Not a
  /// secret.
  ///
  /// Android also needs an *Android* OAuth client in the same project for every
  /// key the app is signed with (package + SHA-1: upload key, debug keystore,
  /// Play app signing key); without the matching one Google refuses with a
  /// configuration error. iOS would need its own client ID and URL scheme,
  /// which do not exist yet, so Google sign-in is Android-only for now.
  static const String googleWebClientId =
      '350967143148-ve4gvg396r5ai2lfeveb15a60074p536.apps.googleusercontent.com';

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
