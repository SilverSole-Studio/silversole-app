import 'dart:convert';

import 'package:silversole/core/diamonds/diamond_repository.dart';
import 'package:silversole/core/utils/system_font_scale.dart';

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
/// `callHandler('exitPlaza')` is the town menu's 「回 App」: the app switches
/// back to the home tab (and its bottom bar returns) and the call resolves to
/// `true`. The games tab never shows the bar, so this is the page's way out.
///
/// Cloud save: `callHandler('gameSaveLoad')` resolves to the account's saved
/// blob, `callHandler('gameSaveStore', {rev, data})` writes it (see
/// `GameSaveRepository` for the answers).
///
/// Activity: `callHandler('gameActivity', {slug, stage?, seconds})` is what a
/// game sends when a round ends; the app keeps it for the daily missions and
/// resolves to `{ok: true}`, or `{ok: false}` for a report of the wrong shape
/// (see `GameActivity.tryParse`).
///
/// Daily missions: `callHandler('dailyMissions')` (no arguments) resolves to
/// `{day: 'YYYY-MM-DD', missions: [{id, title, done}]}` for today, read only
/// (see `dailyMissionsAnswer`); `missions` is empty when no plan can be made.
///
/// Online play: `callHandler('mpSession')` resolves to `{url, anonKey,
/// accessToken, expiresAt}` for the signed-in user (`expiresAt` in
/// milliseconds), or null when nobody is signed in (see `MpSessionService`).
/// The page then talks to Supabase itself; rooms and moves are RPCs.
///
/// Only the games' own site is served ([isGameOrigin]): the plaza links out
/// to other pages in the same web view, and none of them may read the app's
/// state, open app screens or get the camera.
/// The answer of [PlazaBridge.backAction].
enum PlazaBackAction { webBack, leaveTab }

abstract final class PlazaBridge {
  static const String openFriends = 'openFriends';
  static const String exitPlaza = 'exitPlaza';
  static const String appInfo = 'appInfo';
  static const String gameSaveLoad = 'gameSaveLoad';
  static const String gameSaveStore = 'gameSaveStore';
  static const String gameActivity = 'gameActivity';
  static const String mpSession = 'mpSession';
  static const String dailyMissions = 'dailyMissions';

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

  /// App → page: opens the town's own friends screen. A fixed string, never
  /// built from user input.
  static const String openFriendsScript =
      'window.WorldOpenFriends && window.WorldOpenFriends()';

  /// [plazaUrl] with `open=friends`, so the town opens its friends screen
  /// after loading. Other query parameters are kept.
  static String friendsUrl(String plazaUrl) {
    final uri = Uri.parse(plazaUrl);
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'open': 'friends'})
        .toString();
  }

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
  /// [diamonds] is the server's last answer about the account's diamonds
  /// (`balance`, earned this `month`, the month's `cap`); left out until the
  /// app has one.
  ///
  /// [systemFontScale] is the phone's font-size setting (1.0 = default; the
  /// app itself caps its own text, the web games can use this to switch on
  /// their large-text mode when the app does not send [textSize]).
  ///
  /// [textSize] is the settings page's 文字大小 (`"normal"` or `"large"`).
  /// When it is there the games follow it and hide their own large-text
  /// switch, so the two settings never fight.
  static Map<String, Object> info({
    required bool friends,
    required int friendRequests,
    String? accountId,
    String? accountEmail,
    double systemFontScale = 1.0,
    AppTextSize textSize = AppTextSize.normal,
    bool subscribed = false,
    DiamondBalance? diamonds,
  }) => {
    'features': {'friends': friends},
    'friendRequests': friends ? friendRequests : 0,
    if (accountId != null && accountId.isNotEmpty)
      'account': {'id': accountId, 'username': usernameOf(accountEmail)},
    'systemFontScale': systemFontScale,
    'textSize': textSize.wireName,
    // 2026-11-01：訂閱（還沒接金流，測試開關）；遊戲兌換站的實物分頁看這個
    'subscription': {'active': subscribed},
    // 2026-11-02：鑽石（伺服器帳本）；還沒問到伺服器、或沒登入時整個不存在
    if (diamonds != null)
      'diamonds': {
        'balance': diamonds.balance,
        'month': diamonds.month,
        'cap': diamonds.cap,
      },
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

  /// The town hub pages (`game/world/`, and `game/plaza/` which forwards to
  /// it). Everything else on the games' site is a game or a shop.
  static const hubPaths = ['game/world/', 'game/plaza/'];

  /// Whether [pageUrl] is a game rather than the town hub. The games tab no
  /// longer shows the bottom navigation bar at all (2026-11-03), so this only
  /// decides what the back button does: in a game it goes back to the town.
  /// Pages off the games' site never count.
  static bool isInGame(Uri? pageUrl, String gameUrl) {
    if (!isGameOrigin(pageUrl, gameUrl)) return false;
    final base = Uri.parse(gameUrl).path;
    var path = pageUrl!.path;
    if (!path.startsWith(base)) return false;
    path = path.substring(base.length);
    if (!path.startsWith('game/')) return false;
    path = path.replaceFirst(RegExp(r'index\.html$'), '');
    if (!path.endsWith('/')) path = '$path/';
    return path != 'game/' && !hubPaths.contains(path);
  }

  /// Whether [pageUrl] is the town hub itself: on the games' site and not a
  /// game. The back button leaves the games tab from here (to the home tab)
  /// instead of walking the web history.
  static bool isHub(Uri? pageUrl, String gameUrl) =>
      isGameOrigin(pageUrl, gameUrl) && !isInGame(pageUrl, gameUrl);

  /// What the system back button does on the games tab. [onHub]: the page
  /// showing is the town hub ([isHub]); [canGoBack]: the web view has history.
  /// In the hub it always leaves for the home tab (history there would only
  /// lead back into a game); in a game, or on another site, it walks the
  /// history while there is any, and leaves when there is none.
  static PlazaBackAction backAction({
    required bool onHub,
    required bool canGoBack,
  }) =>
      !onHub && canGoBack ? PlazaBackAction.webBack : PlazaBackAction.leaveTab;

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
