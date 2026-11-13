import 'dart:convert';

/// The page → app channel of the 銀足樂齡 mode: `callHandler('aaRpc', {fn, args})`.
/// The contract is 動域科技總倉庫
/// `02_產品/銀足樂齡_ActiveAging/商業營運計畫_無人化外派模式/08_H5與App資料介面_RPC清單.md`.
///
/// The page never talks to Supabase. It names one of the twelve functions in
/// [functions]; anything else is refused here ([AaCallResult.invalid]) and never
/// reaches the server. The database checks everything again (who, which session,
/// ranges, sizes), so this list is the app's door and not the only lock.
///
/// Answers: `{ok: true, data}` or `{ok: false, reason}`, [reasons] being the only
/// values a page ever sees.
abstract final class AaBridge {
  static const String handlerName = 'aaRpc';

  /// The H5 mode lives under this path of the games' site.
  static const String gamePath = 'game/aa/';

  /// What `Constants.gameUrl` + [gamePath] gives: the page the 「我的」 entry opens.
  static String pageUrl(String gameUrl) => '$gameUrl$gamePath';

  /// Whether [pageUrl] is the 銀足樂齡 page itself: on the games' site (same
  /// scheme, host and port as [gameUrl]) and under [gamePath]. Only this page
  /// may call [handlerName].
  static bool isAaPage(Uri? page, String gameUrl) {
    if (page == null || page.host.isEmpty) return false;
    if (!page.isScheme('http') && !page.isScheme('https')) return false;
    final base = Uri.parse(gameUrl);
    if (page.origin != base.origin) return false;
    final prefix = '${base.path}$gamePath';
    final path = page.path.endsWith('/') ? page.path : '${page.path}/';
    return path.startsWith(prefix);
  }

  /// The server takes 100 KB a request (08 §5 item 4); refuse earlier here.
  static const int maxArgsBytes = 102400;

  /// 08 §1. `offline` is the app's own (no answer from the server); the rest are
  /// what the database says. Anything else the server might say is `invalid`.
  static const Set<String> reasons = {
    'signed_out',
    'not_member',
    'forbidden',
    'rate_limited',
    'offline',
    'invalid',
    'too_large',
    'closed',
  };

  /// The twelve functions of 08 §2 and the arguments each takes. The page names
  /// an argument as in the table of 08 §2 without the `p_` (`session_id`, `rows`);
  /// the app sends it as `p_<name>`.
  static const Map<String, Map<String, AaArg>> functions = {
    'aa_me': {},
    'aa_invite_redeem': {'code': AaArg.text},
    'aa_session_upsert': {'session': AaArg.object},
    'aa_session_close': {'id': AaArg.uuid, 'closed_at': AaArg.text},
    'aa_participants_upsert': {'session_id': AaArg.uuid, 'rows': AaArg.list},
    'aa_consents_upsert': {'session_id': AaArg.uuid, 'rows': AaArg.list},
    'aa_measurements_upsert': {'session_id': AaArg.uuid, 'rows': AaArg.list},
    'aa_events_upsert': {'session_id': AaArg.uuid, 'rows': AaArg.list},
    'aa_session_pull': {'id': AaArg.uuid},
    'aa_session_list': {'limit': AaArg.integer},
    'aa_session_delete': {'id': AaArg.uuid},
    'aa_participant_erase': {'session_id': AaArg.uuid, 'code': AaArg.text},
  };

  /// Arguments the page may leave out (the database has a default).
  static const Set<String> optionalArgs = {'limit'};

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _inviteCode = RegExp(r'^[1-9][0-9]{7}$');

  /// Whether [code] is the shape of an invite code (8 digits, no leading 0).
  static bool isInviteCode(String code) => _inviteCode.hasMatch(code);

  /// Reads what the page passed to the handler (`callHandler('aaRpc', {fn, args})`
  /// arrives as a one-element list) into a call to make, or the reason to refuse.
  static AaCallResult parse(List<dynamic> handlerArgs) {
    if (handlerArgs.isEmpty) return AaCallResult.invalid;
    final first = handlerArgs.first;
    if (first is! Map) return AaCallResult.invalid;
    final fn = first['fn'];
    if (fn is! String) return AaCallResult.invalid;
    final spec = functions[fn];
    if (spec == null) return AaCallResult.invalid;
    final raw = first['args'] ?? const <String, Object?>{};
    if (raw is! Map) return AaCallResult.invalid;
    // No other keys than the function's own: nothing rides along to the server.
    for (final k in raw.keys) {
      if (k is! String || !spec.containsKey(k)) return AaCallResult.invalid;
    }
    final params = <String, Object?>{};
    for (final entry in spec.entries) {
      final has = raw.containsKey(entry.key) && raw[entry.key] != null;
      if (!has) {
        if (optionalArgs.contains(entry.key)) continue;
        return AaCallResult.invalid;
      }
      final v = raw[entry.key];
      if (!entry.value.accepts(v)) return AaCallResult.invalid;
      params['p_${entry.key}'] = v;
    }
    final size = utf8.encode(jsonEncode(params)).length;
    if (size > maxArgsBytes) return AaCallResult.tooLarge;
    return AaCallResult._(fn, params, null);
  }

  /// The reason a page sees for what the server (or the app) said: only the
  /// values of [reasons]; anything else is `invalid`.
  static String reasonOf(Object? raw) =>
      raw is String && reasons.contains(raw) ? raw : 'invalid';

  /// The server's answer as the page gets it: `{ok: true, data: {...}}` with the
  /// server's fields minus `ok`, or `{ok: false, reason}`. A reply that is not a
  /// map at all is `offline`.
  static Map<String, Object?> wrap(Object? res) {
    if (res is! Map) return refusal('offline');
    if (res['ok'] == true) {
      final data = <String, Object?>{};
      for (final e in res.entries) {
        if (e.key is String && e.key != 'ok') data[e.key as String] = e.value;
      }
      return {'ok': true, 'data': data};
    }
    return refusal(reasonOf(res['reason']));
  }

  static Map<String, Object?> refusal(String reason) => {
    'ok': false,
    'reason': reasonOf(reason),
  };
}

/// What an argument must look like (the database re-checks the details).
enum AaArg {
  text,
  uuid,
  integer,
  object,
  list;

  bool accepts(Object? v) {
    switch (this) {
      case AaArg.text:
        return v is String;
      case AaArg.uuid:
        return v is String && AaBridge._uuid.hasMatch(v);
      case AaArg.integer:
        return v is num && v == v.truncate();
      case AaArg.object:
        return v is Map;
      case AaArg.list:
        return v is List;
    }
  }
}

/// A call the page may make ([rpc], [params]), or the [reason] it may not.
class AaCallResult {
  const AaCallResult._(this.rpc, this.params, this.reason);

  static const AaCallResult invalid = AaCallResult._(null, null, 'invalid');
  static const AaCallResult tooLarge = AaCallResult._(null, null, 'too_large');

  final String? rpc;
  final Map<String, Object?>? params;
  final String? reason;

  bool get ok => reason == null;
}
