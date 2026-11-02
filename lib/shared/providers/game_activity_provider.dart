import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/diamonds_provider.dart';

/// The game rounds of the last few days, kept on the phone: what the games
/// report through `gameActivity` (see `PlazaBridge.gameActivity`).
class GameActivityNotifier extends Notifier<GameActivityLog> {
  Future<void>? _loading;

  @override
  GameActivityLog build() {
    _loading = _load();
    return const GameActivityLog();
  }

  Future<void> _load() async {
    var saved = const GameActivityLog();
    try {
      saved = GameActivityLog.decode(
        await loadLocalValue(LocalSavableKey.gameActivity),
        today: clock.now(),
      );
    } catch (_) {
      // Unreadable storage: start empty rather than fail every later record.
    }
    if (!ref.mounted) return;
    state = saved;
  }

  /// Keeps [activity] and saves; true when it is kept on the phone. A report
  /// that repeats the one just before it is dropped (and still counts as
  /// kept). Waits for the stored log first, so an early round can never
  /// overwrite the days already kept. When saving fails the round stays in
  /// memory for this run and the answer is false.
  Future<bool> record(GameActivity activity) async {
    await _loading;
    if (!ref.mounted) return false;
    if (state.isRepeat(activity)) return true;
    state = state.add(activity, today: clock.now());
    try {
      await saveLocalValue(LocalSavableKey.gameActivity, state.encode());
      return true;
    } catch (_) {
      return false;
    }
  }
}

final gameActivityProvider =
    NotifierProvider<GameActivityNotifier, GameActivityLog>(
      GameActivityNotifier.new,
    );

/// What a game page gets back from `gameActivity`: `{ok: true}` once the
/// round is kept, `{ok: false}` when [args] was not a valid report or the
/// phone could not save it.
Future<Map<String, Object>> recordGameActivity(
  WidgetRef ref,
  List<dynamic> args,
) async {
  final activity = GameActivity.tryParse(args.firstOrNull, clock.now());
  if (activity == null) return const {'ok': false};
  final repeat = ref.read(gameActivityProvider).isRepeat(activity);
  final saved = await ref.read(gameActivityProvider.notifier).record(activity);
  // Diamonds: only a round played with a sole connected counts as insole
  // exercise (a page that reports twice for one round counts once). The
  // seconds are the game's own word; the server caps what that can earn.
  if (saved && !repeat && ref.read(connectedSolesProvider).isNotEmpty) {
    unawaited(
      ref.read(diamondsProvider.notifier).addExerciseSeconds(activity.seconds),
    );
  }
  return {'ok': saved};
}
