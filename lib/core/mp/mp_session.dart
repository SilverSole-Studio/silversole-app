import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A login token and when it runs out (seconds since the epoch, null when the
/// token has no readable expiry).
typedef MpTokens = ({String accessToken, int? expiresAt});

/// What the H5 games get for online play (`callHandler('mpSession')`, see
/// `docs/plaza-bridge.md`): the connection details of *the signed-in user*, so
/// the page can talk to Supabase (RPCs and Realtime) as that user.
///
/// This is the only thing the app does for online play. Rooms, moves and
/// invites live in the database (`supabase/migrations/20261103120000_mp_rooms.sql`)
/// and the page calls them directly, so a new online game needs no app release.
///
/// [url] and [anonKey] are the public values already inside the app. The
/// access token is the user's own login token: whoever holds it can call any
/// of that user's RPCs. That is why the handler only answers pages on the
/// games' own site ([PlazaBridge.isGameOrigin]) and why the token is never
/// stored or logged here.
class MpSessionService {
  MpSessionService({
    required this.url,
    required this.anonKey,
    required this.current,
    required this.refresh,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String url;
  final String anonKey;

  /// The login token the Supabase client holds now (null when signed out).
  final MpTokens? Function() current;

  /// Asks Supabase for a fresh token; null when that did not work.
  final Future<MpTokens?> Function() refresh;
  final DateTime Function() _clock;

  /// A token with less than this left is renewed before it is handed out.
  static const renewBefore = Duration(minutes: 2);

  /// `{url, anonKey, accessToken, expiresAt}` (`expiresAt` in milliseconds
  /// since the epoch, so the page can compare it with `Date.now()`), or null
  /// when nobody is signed in, the backend is not configured, or the only
  /// token left has run out.
  Future<Map<String, Object>?> session() async {
    if (url.isEmpty || anonKey.isEmpty) return null;
    final first = current();
    if (first == null || first.accessToken.isEmpty) return null;
    var tokens = first;
    if (_leftMs(tokens) < renewBefore.inMilliseconds) {
      try {
        tokens = await refresh() ?? first;
      } catch (_) {
        // Offline: hand out the old one if it is still good.
      }
    }
    final t = tokens;
    if (t.accessToken.isEmpty || _leftMs(t) <= 0) return null;
    return {
      'url': url,
      'anonKey': anonKey,
      'accessToken': t.accessToken,
      'expiresAt': _expiresMs(t),
    };
  }

  /// A token with no expiry we can read is treated as good for one minute, so
  /// the page asks again soon instead of holding on to it.
  int _expiresMs(MpTokens t) => t.expiresAt == null
      ? _clock().millisecondsSinceEpoch + 60000
      : t.expiresAt! * 1000;

  int _leftMs(MpTokens t) => _expiresMs(t) - _clock().millisecondsSinceEpoch;
}

final mpSessionServiceProvider = Provider<MpSessionService>((ref) {
  final client = Supabase.instance.client;
  ({String accessToken, int? expiresAt})? fromSession(Session? s) =>
      s == null ? null : (accessToken: s.accessToken, expiresAt: s.expiresAt);
  return MpSessionService(
    url: dotenv.env[Constants.supabaseUrlKey] ?? '',
    anonKey: dotenv.env[Constants.supabasePublicDefaultKey] ?? '',
    current: () => fromSession(client.auth.currentSession),
    refresh: () async =>
        fromSession((await client.auth.refreshSession()).session),
  );
});
