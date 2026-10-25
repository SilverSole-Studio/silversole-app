import 'dart:convert';

/// The contract between the H5 「粗哥廣場」 and the app, used by
/// `PlazaTabPage`. The page side is documented in `docs/plaza-bridge.md`.
///
/// App → page: after every load, and again whenever the values change, the app
/// sets `window.silversoleApp` to [info] and fires a `silversoleapp` event on
/// `window`. The page can also ask for it with
/// `await window.flutter_inappwebview.callHandler('appInfo')`. Opened in a
/// plain browser, neither exists, so the page shows no app-only buildings.
///
/// Page → app: `window.flutter_inappwebview.callHandler('openFriends')` opens
/// the friends screen and resolves to `true`, or `false` when friends are off.
///
/// Only the games' own site is served ([isGameOrigin]): the plaza links out
/// to other pages in the same web view, and none of them may read the app's
/// state, open app screens or get the camera.
abstract final class PlazaBridge {
  static const String openFriends = 'openFriends';
  static const String appInfo = 'appInfo';
  static const String infoEvent = 'silversoleapp';

  /// What the plaza needs to know: whether to show the friends building, and
  /// the red-dot count on it (always 0 while friends are off).
  ///
  /// [systemFontScale] is the phone's font-size setting (1.0 = default; the
  /// app itself caps its own text, the web games can use this to switch on
  /// their large-text mode).
  static Map<String, Object> info({
    required bool friends,
    required int friendRequests,
    double systemFontScale = 1.0,
  }) => {
    'features': {'friends': friends},
    'friendRequests': friends ? friendRequests : 0,
    'systemFontScale': systemFontScale,
  };

  /// The origin (`scheme://host[:port]`) of [gameUrl] — also the form
  /// `UserScript.allowedOriginRules` takes.
  static String originOf(String gameUrl) => Uri.parse(gameUrl).origin;

  /// Whether [pageUrl] is on the games' own site: same scheme, host and port
  /// as [gameUrl]. Anything that is not an http(s) page never is.
  static bool isGameOrigin(Uri? pageUrl, String gameUrl) {
    if (pageUrl == null || pageUrl.host.isEmpty) return false;
    if (!pageUrl.isScheme('http') && !pageUrl.isScheme('https')) return false;
    return pageUrl.origin == originOf(gameUrl);
  }

  /// JavaScript that publishes [info] as `window.silversoleApp` and fires the
  /// [infoEvent] event with it as `detail`.
  static String publishScript(Map<String, Object> info) =>
      'window.silversoleApp=${jsonEncode(info)};'
      'window.dispatchEvent(new CustomEvent("$infoEvent",'
      '{detail:window.silversoleApp}));';
}
