import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/diamonds/diamond_repository.dart';
import 'package:silversole/core/diamonds/exercise_day.dart';
import 'package:silversole/shared/providers/auth_provider.dart';

/// What the app knows about the account's diamonds right now.
class DiamondsState {
  const DiamondsState({this.balance, this.exercise});

  /// The server's last answer; null before the first one (or signed out).
  final DiamondBalance? balance;

  /// Today's insole exercise on this phone; null when signed out.
  final ExerciseDay? exercise;

  DiamondsState copyWith({DiamondBalance? balance, ExerciseDay? exercise}) =>
      DiamondsState(
        balance: balance ?? this.balance,
        exercise: exercise ?? this.exercise,
      );
}

/// Diamonds (design: `_鑽石設計_2026-11-02.md`). The ledger is the server's;
/// this notifier keeps the last balance it was told, counts the day's insole
/// exercise, and asks for the payout once that reaches 15 minutes.
///
/// It rebuilds, and starts from zero, whenever the signed-in account changes.
class DiamondsNotifier extends Notifier<DiamondsState> {
  Future<void>? _loading;
  bool _asking = false;

  @override
  DiamondsState build() {
    final user = ref.watch(authUserProvider);
    if (user == null) {
      _loading = null;
      return const DiamondsState();
    }
    _loading = _init(user.uuid);
    return const DiamondsState();
  }

  String? get _userId => ref.read(authUserProvider)?.uuid;

  Future<void> _init(String userId) async {
    var day = ExerciseDay.empty(userId, clock.now());
    try {
      day = ExerciseDay.decode(
        await loadLocalValue(LocalSavableKey.diamondExercise),
        userId: userId,
        now: clock.now(),
      );
    } catch (_) {
      // Unreadable storage: start the day empty.
    }
    if (!ref.mounted) return;
    state = state.copyWith(exercise: day);
    await _fetch();
  }

  /// Asks the server for the balance and, if today's exercise is already
  /// enough and unpaid, for the payout. Safe to call often (the server
  /// rate-limits, a failure is simply ignored).
  Future<void> refresh() async {
    await _loading;
    await _fetch();
  }

  Future<void> _fetch() async {
    if (!ref.mounted || _userId == null) return;
    final repo = _repository();
    if (repo == null) return;
    final res = await repo.balance();
    if (!ref.mounted) return;
    final balance = res.balance;
    if (balance != null) state = state.copyWith(balance: balance);
    await _maybeEarn();
  }

  /// [seconds] of exercise with a sole connected, just reported by a game.
  Future<void> addExerciseSeconds(int seconds) async {
    await _loading;
    final userId = _userId;
    if (!ref.mounted || userId == null) return;
    final day = (state.exercise ?? ExerciseDay.empty(userId, clock.now()))
        .addSeconds(seconds, userId: userId, now: clock.now());
    state = state.copyWith(exercise: day);
    await _saveExercise(day);
    await _maybeEarn();
  }

  DiamondRepository? _repository() {
    try {
      return ref.read(diamondRepositoryProvider);
    } catch (_) {
      // No Supabase client (tests, or before init): nothing to ask.
      return null;
    }
  }

  Future<void> _saveExercise(ExerciseDay day) async {
    try {
      await saveLocalValue(LocalSavableKey.diamondExercise, day.encode());
    } catch (_) {
      // Kept in memory for this run.
    }
  }

  /// Asks for the payout when it is due. A failure that says nothing about
  /// today (offline, rate limited) leaves it open, so the next report or
  /// refresh tries again.
  Future<void> _maybeEarn() async {
    final userId = _userId;
    final day = state.exercise;
    if (_asking || userId == null || day == null || !day.readyToEarn) return;
    final known = state.balance;
    if (known != null && !known.subscribed) return;
    final repo = _repository();
    if (repo == null) return;
    _asking = true;
    try {
      final res = await repo.earnExercise(day.minutes);
      if (!ref.mounted || _userId != userId) return;
      final balance = res.balance;
      if (balance != null) state = state.copyWith(balance: balance);
      if (res.ok || _settledReasons.contains(res.reason)) {
        final settled = (state.exercise ?? day).markSettled();
        state = state.copyWith(exercise: settled);
        await _saveExercise(settled);
      }
    } finally {
      _asking = false;
    }
  }

  /// Answers after which there is no point asking again today.
  static const _settledReasons = {'already_today', 'month_cap'};
}

final diamondsProvider = NotifierProvider<DiamondsNotifier, DiamondsState>(
  DiamondsNotifier.new,
);
