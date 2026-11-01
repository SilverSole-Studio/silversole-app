import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/missions/game_activity_store.dart';

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
      );
    } catch (_) {
      // Unreadable storage: start empty rather than fail every later record.
    }
    if (!ref.mounted) return;
    state = saved;
  }

  /// Keeps [activity] and saves. Waits for the stored log first, so an early
  /// round can never overwrite the days already kept.
  Future<void> record(GameActivity activity) async {
    await _loading;
    if (!ref.mounted) return;
    state = state.add(activity);
    await saveLocalValue(LocalSavableKey.gameActivity, state.encode());
  }
}

final gameActivityProvider =
    NotifierProvider<GameActivityNotifier, GameActivityLog>(
      GameActivityNotifier.new,
    );

/// What a game page gets back from `gameActivity`: `{ok: true}` once the
/// round is kept, `{ok: false}` when [args] was not a valid report.
Future<Map<String, Object>> recordGameActivity(
  WidgetRef ref,
  List<dynamic> args,
) async {
  final activity = GameActivity.tryParse(args.firstOrNull, DateTime.now());
  if (activity == null) return const {'ok': false};
  await ref.read(gameActivityProvider.notifier).record(activity);
  return const {'ok': true};
}
