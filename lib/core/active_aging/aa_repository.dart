import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/active_aging/aa_bridge.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The 銀足樂齡 mode's server calls (`supabase/migrations/20261113120000_active_aging.sql`).
/// The page reaches them through [AaBridge]; the 「我的」 page uses [isActive] and
/// [redeem] directly.
///
/// Every answer is a plain map: `{ok: true, data}` or `{ok: false, reason}`
/// ([AaBridge.wrap]). A call that never reached the server is `offline`.
class AaRepository {
  AaRepository(this._rpc, this._signedIn);

  /// Calls a Supabase RPC; injected so tests need no client.
  final Future<dynamic> Function(String fn, Map<String, dynamic> params) _rpc;
  final bool Function() _signedIn;

  /// One call from the page ([AaBridge.parse] of what the handler received).
  Future<Map<String, Object?>> handle(List<dynamic> handlerArgs) async {
    final call = AaBridge.parse(handlerArgs);
    if (!call.ok) return AaBridge.refusal(call.reason!);
    return _call(call.rpc!, call.params!);
  }

  /// Whether this account has the 銀足樂齡 role (`aa_me().active`). Any failure
  /// (no network, not applied yet, signed out) is false.
  Future<bool> isActive() async {
    final res = await _call('aa_me', const {});
    final data = res['data'];
    return res['ok'] == true && data is Map && data['active'] == true;
  }

  /// Turns the mode on with an invite code. `{ok: true, data: {role}}`, or the
  /// reason: `invalid` (wrong, used up or stopped code, or not 8 digits),
  /// `rate_limited` (too many wrong tries), `forbidden` (this account was
  /// stopped by the company), `offline`, `signed_out`.
  Future<Map<String, Object?>> redeem(String code) {
    final trimmed = code.trim();
    if (!AaBridge.isInviteCode(trimmed)) {
      return Future.value(AaBridge.refusal('invalid'));
    }
    return _call('aa_invite_redeem', {'p_code': trimmed});
  }

  Future<Map<String, Object?>> _call(
    String rpc,
    Map<String, Object?> params,
  ) async {
    if (!_signedIn()) return AaBridge.refusal('signed_out');
    try {
      return AaBridge.wrap(await _rpc(rpc, Map<String, dynamic>.of(params)));
    } catch (_) {
      return AaBridge.refusal('offline');
    }
  }
}

final aaRepositoryProvider = Provider<AaRepository>((ref) {
  final client = Supabase.instance.client;
  return AaRepository(
    (fn, params) => client.rpc(fn, params: params),
    () => client.auth.currentUser != null,
  );
});

/// Whether the signed-in account has the role. Asked once per sign-in; call
/// `ref.invalidate(aaActiveProvider)` after an invite code was taken. False
/// while loading, when signed out, or while `Constants.activeAgingOnSupabase`
/// is off (the migration is not applied yet).
final aaActiveProvider = FutureProvider<bool>((ref) async {
  if (!Constants.activeAgingOnSupabase) return false;
  if (ref.watch(authUserProvider) == null) return false;
  return ref.watch(aaRepositoryProvider).isActive();
});

/// What `features.activeAging` and the 「我的」 entry follow.
final activeAgingEnabledProvider = Provider<bool>(
  (ref) => ref.watch(aaActiveProvider).value ?? false,
);
