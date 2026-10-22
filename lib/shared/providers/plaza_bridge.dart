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
abstract final class PlazaBridge {
  static const String openFriends = 'openFriends';
  static const String appInfo = 'appInfo';
  static const String infoEvent = 'silversoleapp';

  /// What the plaza needs to know: whether to show the friends building, and
  /// the red-dot count on it (always 0 while friends are off).
  static Map<String, Object> info({
    required bool friends,
    required int friendRequests,
  }) => {
    'features': {'friends': friends},
    'friendRequests': friends ? friendRequests : 0,
  };

  /// JavaScript that publishes [info] as `window.silversoleApp` and fires the
  /// [infoEvent] event with it as `detail`.
  static String publishScript(Map<String, Object> info) =>
      'window.silversoleApp=${jsonEncode(info)};'
      'window.dispatchEvent(new CustomEvent("$infoEvent",'
      '{detail:window.silversoleApp}));';
}
