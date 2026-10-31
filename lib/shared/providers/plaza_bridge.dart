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
/// Cloud save: `callHandler('gameSaveLoad')` resolves to the account's saved
/// blob, `callHandler('gameSaveStore', {rev, data})` writes it (see
/// `GameSaveRepository` for the answers).
///
/// Only the games' own site is served ([isGameOrigin]): the plaza links out
/// to other pages in the same web view, and none of them may read the app's
/// state, open app screens or get the camera.
abstract final class PlazaBridge {
  static const String openFriends = 'openFriends';
  static const String appInfo = 'appInfo';
  static const String gameSaveLoad = 'gameSaveLoad';
  static const String gameSaveStore = 'gameSaveStore';

  /// The `{rev, data}` the page passes to [gameSaveStore], or null when it is
  /// not that shape (the call then answers `bad_data` without a round trip).
  static ({int rev, String data})? storeArgs(List<dynamic> args) {
    if (args.isEmpty) return null;
    final a = args.first;
    if (a is! Map) return null;
    final rev = a['rev'], data = a['data'];
    if (rev is! num || rev < 0 || rev != rev.truncate() || data is! String) {
      return null;
    }
    return (rev: rev.toInt(), data: data);
  }
  static const String infoEvent = 'silversoleapp';

  /// What the plaza needs to know: whether to show the friends building, the
  /// red-dot count on it (always 0 while friends are off), who is signed in,
  /// and the phone's font scale. `account` is left out when nobody is signed
  /// in ([accountId] null or empty).
  ///
  /// The app has no separate username: sign-in is by email (or Google), so
  /// `account.username` is the part of [accountEmail] before the `@`
  /// (`ricky951102@gmail.com` → `ricky951102`). It is empty when there is no
  /// email. It is only a name to match on, not proof of who the user is.
  ///
  /// [systemFontScale] is the phone's font-size setting (1.0 = default; the
  /// app itself caps its own text, the web games can use this to switch on
  /// their large-text mode).
  static Map<String, Object> info({
    required bool friends,
    required int friendRequests,
    String? accountId,
    String? accountEmail,
    double systemFontScale = 1.0,
  }) => {
    'features': {'friends': friends},
    'friendRequests': friends ? friendRequests : 0,
    if (accountId != null && accountId.isNotEmpty)
      'account': {'id': accountId, 'username': usernameOf(accountEmail)},
    'systemFontScale': systemFontScale,
  };

  /// The part of [email] before the first `@`, or '' when there is none.
  static String usernameOf(String? email) {
    if (email == null) return '';
    final at = email.indexOf('@');
    return (at < 0 ? email : email.substring(0, at)).trim();
  }

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

  /// [publishScript] guarded by the page's origin. `allowedOriginRules` on a
  /// UserScript is honoured only on Android, so on iOS this guard is what keeps
  /// the account fields off every other site the plaza navigates to.
  static String guardedPublishScript(Map<String, Object> info, String origin) =>
      'if(location.origin===${jsonEncode(origin)}){${publishScript(info)}}';
}
