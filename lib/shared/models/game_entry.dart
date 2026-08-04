import 'package:silversole/constants.dart';

/// One playable title in the games hub.
///
/// Both themes render the same catalog — only the framing differs — so the
/// list lives here rather than being duplicated per page.
class GameEntry {
  const GameEntry({
    required this.nameKey,
    required this.art,
    required this.url,
  });

  /// Translation key for the display name.
  final String nameKey;

  /// Cover art from the mascot pack. Used by BOTH themes: the artwork is
  /// content, not decoration, so the classic theme shows it too.
  final String art;

  /// Opened in the in-app HTML5 web view.
  final String url;
}

/// The catalog. Every entry currently points at the one shipped HTML5 build
/// ([Constants.gameUrl]); per-title URLs land when those games exist.
List<GameEntry> gameCatalog() {
  final url = Constants.gameUrl;
  const art = 'assets/mascot-assets/cards';
  return [
    GameEntry(nameKey: 'game_group_hop', art: '$art/card_hop.png', url: url),
    GameEntry(
      nameKey: 'game_chase_zombie',
      art: '$art/card_zombie.png',
      url: url,
    ),
    GameEntry(nameKey: 'game_catch_fish', art: '$art/card_fish.png', url: url),
    GameEntry(nameKey: 'skiing_game', art: '$art/card_ski.png', url: url),
    GameEntry(nameKey: 'game_ride_bike', art: '$art/card_bike.png', url: url),
    GameEntry(
      nameKey: 'game_paddle_canoe',
      art: '$art/card_canoe.png',
      url: url,
    ),
    GameEntry(
      nameKey: 'game_rhythm_step',
      art: '$art/card_rhythm.png',
      url: url,
    ),
    GameEntry(nameKey: 'game_memory_quiz', art: '$art/card_quiz.png', url: url),
  ];
}
