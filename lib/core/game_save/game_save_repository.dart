import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The H5 games' cloud save: one JSON blob per account, behind the
/// `game_save_load` / `game_save_store` RPCs
/// (`supabase/migrations/20261031120000_game_saves.sql`). The plaza page calls
/// these through [PlazaBridge.gameSaveLoad] / [PlazaBridge.gameSaveStore];
/// both directions are documented in `docs/plaza-bridge.md`.
///
/// Every answer is a plain map the page can read as-is: `{ok: true, ...}` or
/// `{ok: false, reason}`. Anything that never reached the server is
/// `reason: 'offline'`, so the page just keeps playing on its local copy.
class GameSaveRepository {
  GameSaveRepository(this._rpc, this._signedIn);

  /// Calls a Supabase RPC; injected so tests need no client.
  final Future<dynamic> Function(String fn, Map<String, dynamic> params) _rpc;
  final bool Function() _signedIn;

  /// Biggest blob the server takes (keep in step with the migration).
  static const maxBytes = 262144;

  /// `{ok, rev, savedAt, data}`; `data` is null when nothing is saved yet.
  Future<Map<String, Object?>> load() => _call('game_save_load', const {});

  /// Saves [data] (a JSON string) if [rev] is the stored version; answers
  /// `{ok: true, rev: <new>}` or `{ok: false, reason: 'conflict', rev}`.
  Future<Map<String, Object?>> store(int rev, String data) {
    // Count bytes the way Postgres does (UTF-8), not UTF-16 code units.
    if (data.length > maxBytes || _utf8Length(data) > maxBytes) {
      return Future.value(const {'ok': false, 'reason': 'too_big'});
    }
    return _call('game_save_store', {'p_rev': rev, 'p_data': data});
  }

  Future<Map<String, Object?>> _call(
    String fn,
    Map<String, dynamic> params,
  ) async {
    if (!_signedIn()) return const {'ok': false, 'reason': 'signed_out'};
    try {
      final res = await _rpc(fn, params);
      if (res is Map) return Map<String, Object?>.from(res);
      return const {'ok': false, 'reason': 'offline'};
    } catch (_) {
      return const {'ok': false, 'reason': 'offline'};
    }
  }

  static int _utf8Length(String s) {
    var n = 0;
    for (final r in s.runes) {
      n += r < 0x80
          ? 1
          : r < 0x800
          ? 2
          : r < 0x10000
          ? 3
          : 4;
    }
    return n;
  }
}

final gameSaveRepositoryProvider = Provider<GameSaveRepository>((ref) {
  final client = Supabase.instance.client;
  return GameSaveRepository(
    (fn, params) => client.rpc(fn, params: params),
    () => client.auth.currentUser != null,
  );
});
