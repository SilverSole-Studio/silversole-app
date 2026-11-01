import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';

/// The days from 1 January to [day], counting 1 January as 1 (1–366).
///
/// Counted on UTC dates so a daylight-saving change never shifts it.
int dayOfYear(DateTime day) =>
    DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(day.year, 1, 1)).inDays +
    1;

/// Whole calendar days from [from] to [to], by local date.
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Every mission the app knows, by id. The ids are shared with the server
/// function that may write the missions' wording, so they must not change.
///
/// `racer` and `golf` are hidden stages the wearer is meant to find in the
/// town, so they are never a mission.
abstract final class MissionCatalog {
  static const String footCheck = 'foot_check';
  static const String laojie = 'laojie';

  /// The games a mission can ask for, in the order their rotation runs.
  static const List<String> gameIds = [
    'walkgroup',
    'bike',
    'canoe',
    'fish',
    'ski',
    'hop',
    'rhythm',
    'quiz',
    'pool',
    laojie,
  ];

  static const List<String> ids = [footCheck, ...gameIds];

  static bool isKnown(String id) => ids.contains(id);

  static bool isGame(String id) => gameIds.contains(id);

  /// Translation key of the mission's title.
  static String titleKey(String id) =>
      id == footCheck ? 'mission_measure_title' : 'mission_play_$id';

  /// The (theme, stage) of 踩進老街 offered on a day: five that have a
  /// stage ready, handed out by day of the year.
  static const List<({String theme, String stage})> laojieStages = [
    (theme: 'xinbei', stage: 'lantern'),
    (theme: 'taipei', stage: 'goldfish'),
    (theme: 'taoyuan', stage: 'peach'),
    (theme: 'yilan', stage: 'qiangu'),
    (theme: 'hualien', stage: 'qixingtan'),
  ];

  static ({String theme, String stage}) laojieStageOn(DateTime day) =>
      laojieStages[dayOfYear(day) % laojieStages.length];

  /// Where a game mission opens, to append to `Constants.gameUrl`; null for
  /// the foot check, which is not a web game.
  static String? gamePath(String id, DateTime day) {
    if (!isGame(id)) return null;
    if (id != laojie) return 'game/$id/';
    final s = laojieStageOn(day);
    return 'game/$laojie/${s.stage}/?theme=${s.theme}&from=world';
  }

  /// Whether the mission is done today. Only what the app itself recorded
  /// counts: a foot check finished today, or a round of that very game
  /// reported today.
  static bool isCompleted(
    String id, {
    required DateTime today,
    required GameActivityLog activity,
    required FootCheckRecord? lastFootCheck,
  }) {
    if (id == footCheck) return lastFootCheck?.isOnDay(today) ?? false;
    return isGame(id) && activity.playedOn(id, today);
  }
}
