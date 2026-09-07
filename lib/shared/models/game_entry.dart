import 'package:flutter/foundation.dart';
import 'package:silversole/constants.dart';

/// One playable title in the games hub.
///
/// Both themes render the same catalog — only the framing differs — so the
/// list lives here rather than being duplicated per page.
class GameEntry {
  const GameEntry({
    required this.nameKey,
    required this.art,
    required this.slug,
  });

  /// Translation key for the display name.
  final String nameKey;

  /// Cover art from the mascot pack. Used by BOTH themes: the artwork is
  /// content, not decoration, so the classic theme shows it too.
  final String art;

  /// This title's folder under the H5 site, e.g. `hop`.
  final String slug;

  /// Opened in the in-app HTML5 web view.
  ///
  /// Built from [Constants.gameUrl] rather than stored, so the debug build's
  /// local Cocos preview and a `--dart-define=GAME_URL=...` override still
  /// reach the right title.
  ///
  /// Debug builds append `?sole=debug`, which makes the game show a corner
  /// panel with the live sole signal: which source it picked (FSR vs tilt),
  /// the raw FSR total, `pitch` / `roll`, the deviation from the neutral
  /// posture, and the event count. That distinguishes "no signal reaching the
  /// page" from "signal is there but the thresholds are off" — the two failure
  /// modes look identical from the game alone. Release builds never get it.
  String get url {
    final base = '${Constants.gameUrl}game/$slug/';
    if (!kDebugMode) return base;
    // GAME_URL may already carry a query string, so pick the right separator.
    return '$base${base.contains('?') ? '&' : '?'}sole=debug';
  }
}

/// The catalog. Every title lives at `<base>/game/<slug>/`.
List<GameEntry> gameCatalog() {
  const art = 'assets/mascot-assets/cards';
  return [
    const GameEntry(
      nameKey: 'game_group_hop',
      art: '$art/card_hop.webp',
      slug: 'hop',
    ),
    const GameEntry(
      nameKey: 'game_chase_zombie',
      art: '$art/card_zombie.webp',
      slug: 'zombie',
    ),
    const GameEntry(
      nameKey: 'game_catch_fish',
      art: '$art/card_fish.webp',
      slug: 'fish',
    ),
    const GameEntry(
      nameKey: 'skiing_game',
      art: '$art/card_ski.webp',
      slug: 'ski',
    ),
    const GameEntry(
      nameKey: 'game_ride_bike',
      art: '$art/card_bike.webp',
      slug: 'bike',
    ),
    const GameEntry(
      nameKey: 'game_paddle_canoe',
      art: '$art/card_canoe.webp',
      slug: 'canoe',
    ),
    const GameEntry(
      nameKey: 'game_rhythm_step',
      art: '$art/card_rhythm.webp',
      slug: 'rhythm',
    ),
    const GameEntry(
      nameKey: 'game_memory_quiz',
      art: '$art/card_quiz.webp',
      slug: 'quiz',
    ),
  ];
}
