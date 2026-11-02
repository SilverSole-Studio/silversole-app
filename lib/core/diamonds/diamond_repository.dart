import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The numbers of the diamond rule (keep in step with
/// `supabase/migrations/20261102120000_diamonds.sql`; the server is the one
/// that enforces them, the app only decides when to ask).
abstract final class DiamondRules {
  /// Insole exercise needed in one day before the app asks for the payout.
  static const minMinutes = 15;

  /// Paid once a day when [minMinutes] is reached.
  static const perDay = 10;

  /// Most a subscriber can earn in one calendar month.
  static const monthlyCap = 300;
}

/// What the server says about the signed-in account's diamonds.
class DiamondBalance {
  const DiamondBalance({
    required this.balance,
    required this.month,
    required this.cap,
    required this.subscribed,
    this.activeUntil,
  });

  /// Diamonds the account holds now.
  final int balance;

  /// Earned so far this month (Taipei calendar month).
  final int month;

  /// The month's ceiling.
  final int cap;

  /// The subscription covers today (the server's `subscriptions` row has
  /// `active_until >= today`).
  final bool subscribed;

  /// Last covered day (`YYYY-MM-DD`), null when the account never subscribed.
  final String? activeUntil;

  /// Reads a server answer; null when the numbers are missing.
  static DiamondBalance? tryFromMap(Map<String, Object?> map) {
    final balance = map['balance'], month = map['month'], cap = map['cap'];
    if (balance is! int || month is! int || cap is! int) return null;
    final until = map['activeUntil'];
    return DiamondBalance(
      balance: balance,
      month: month,
      cap: cap,
      subscribed: map['subscribed'] == true,
      activeUntil: until is String ? until : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiamondBalance &&
      other.balance == balance &&
      other.month == month &&
      other.cap == cap &&
      other.subscribed == subscribed &&
      other.activeUntil == activeUntil;

  @override
  int get hashCode => Object.hash(balance, month, cap, subscribed, activeUntil);
}

/// One server answer. [reason] is the server's (`not_subscribed`,
/// `already_today`, `month_cap`, `rate_limited`, `signed_out`, ...) or
/// `offline` when the call never got an answer.
class DiamondResult {
  const DiamondResult({
    required this.ok,
    this.reason,
    this.earned = 0,
    this.balance,
  });

  final bool ok;
  final String? reason;

  /// Diamonds this call added (10, or 0).
  final int earned;

  /// The account's numbers after the call, when the server sent them.
  final DiamondBalance? balance;
}

/// The diamond ledger lives on the server only (RPCs in
/// `supabase/migrations/20261102120000_diamonds.sql`); nothing is kept on the
/// phone. Every call is answered, never thrown: a call that never reached the
/// server is `reason: 'offline'`.
class DiamondRepository {
  DiamondRepository(this._rpc, this._signedIn);

  /// Calls a Supabase RPC; injected so tests need no client.
  final Future<dynamic> Function(String fn, Map<String, dynamic> params) _rpc;
  final bool Function() _signedIn;

  /// Balance, this month's earnings and whether the subscription is live.
  Future<DiamondResult> balance() => _call('diamond_balance', const {});

  /// Asks for today's payout; the server pays only a live subscription, only
  /// once a day, only when [minutes] >= [DiamondRules.minMinutes] and the
  /// month is below the cap.
  Future<DiamondResult> earnExercise(int minutes) =>
      _call('diamond_earn_exercise', {'p_minutes': minutes});

  Future<DiamondResult> _call(String fn, Map<String, dynamic> params) async {
    if (!_signedIn()) {
      return const DiamondResult(ok: false, reason: 'signed_out');
    }
    try {
      final res = await _rpc(fn, params);
      if (res is! Map) {
        return const DiamondResult(ok: false, reason: 'offline');
      }
      final map = Map<String, Object?>.from(res);
      final earned = map['earned'];
      return DiamondResult(
        ok: map['ok'] == true,
        reason: map['reason'] as String?,
        earned: earned is int ? earned : 0,
        balance: DiamondBalance.tryFromMap(map),
      );
    } catch (_) {
      return const DiamondResult(ok: false, reason: 'offline');
    }
  }
}

final diamondRepositoryProvider = Provider<DiamondRepository>((ref) {
  final client = Supabase.instance.client;
  return DiamondRepository(
    (fn, params) => client.rpc(fn, params: params),
    () => client.auth.currentUser != null,
  );
});
