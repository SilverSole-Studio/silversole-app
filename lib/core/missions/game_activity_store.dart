import 'dart:convert';

import 'package:silversole/core/gait/daily_gait.dart';

/// Days of game activity kept, counting the newest one.
const gameActivityDays = 8;

/// Longest play session the app believes: three hours.
const maxGameSeconds = 10800;

/// Rounds kept per day: a page that reports in a loop cannot grow the stored
/// log without bound. The oldest of a day go first.
const maxGameActivitiesPerDay = 200;

/// A report the same as the one before it, this soon after, is a repeat.
const _repeatWindow = Duration(seconds: 1);

final _slugPattern = RegExp(r'^[a-z0-9_-]{1,32}$');

/// One finished round of a web game, as the game itself reported it.
///
/// The app only checks the shape: an unknown slug is kept as it is, and
/// nothing here says the round was real beyond the game page having said so.
class GameActivity {
  const GameActivity({
    required this.slug,
    this.stage,
    required this.seconds,
    required this.at,
  });

  /// The game's folder under the H5 site, e.g. `fish`.
  final String slug;

  /// The stage inside the game (only 踩進老街 sends one).
  final String? stage;

  /// Seconds actually played.
  final int seconds;

  /// When the app received it, in local time.
  final DateTime at;

  /// The local calendar day, as a [gaitDateKey].
  String get day => gaitDateKey(at);

  /// What a game page sends to `gameActivity`: `{slug, stage?, seconds}`.
  /// Null when [args] is not that shape: a slug or stage outside
  /// `^[a-z0-9_-]{1,32}$` (the stage may be left out), or seconds that are not
  /// a whole number from 0 to [maxGameSeconds].
  static GameActivity? tryParse(Object? args, DateTime at) {
    if (args is! Map) return null;
    final slug = args['slug'];
    if (slug is! String || !_slugPattern.hasMatch(slug)) return null;
    final stage = args['stage'];
    if (stage != null && (stage is! String || !_slugPattern.hasMatch(stage))) {
      return null;
    }
    final seconds = args['seconds'];
    if (seconds is! num ||
        !seconds.isFinite ||
        seconds != seconds.truncate() ||
        seconds < 0 ||
        seconds > maxGameSeconds) {
      return null;
    }
    return GameActivity(
      slug: slug,
      stage: stage as String?,
      seconds: seconds.toInt(),
      at: at,
    );
  }

  Map<String, Object> toJson() => {
    'slug': slug,
    if (stage != null) 'stage': stage!,
    'seconds': seconds,
    'at': at.millisecondsSinceEpoch,
  };

  /// Null for anything that is not an entry this app wrote.
  static GameActivity? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final slug = json['slug'], stage = json['stage'];
    final seconds = json['seconds'], at = json['at'];
    if (slug is! String || seconds is! int || at is! int) return null;
    if (stage != null && stage is! String) return null;
    return GameActivity(
      slug: slug,
      stage: stage as String?,
      seconds: seconds,
      at: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameActivity &&
      other.slug == slug &&
      other.stage == stage &&
      other.seconds == seconds &&
      other.at == at;

  @override
  int get hashCode => Object.hash(slug, stage, seconds, at);
}

/// The game rounds of the last [gameActivityDays] days, grouped by local date.
class GameActivityLog {
  const GameActivityLog([this.byDay = const {}]);

  /// Rounds per [gaitDateKey], oldest first within a day.
  final Map<String, List<GameActivity>> byDay;

  bool get isEmpty => byDay.isEmpty;

  /// Every kept round, oldest day first.
  Iterable<GameActivity> get all sync* {
    final days = byDay.keys.toList()..sort();
    for (final day in days) {
      yield* byDay[day]!;
    }
  }

  /// This log with [activities] added, every day out of the window dropped,
  /// and each day cut to its newest [maxGameActivitiesPerDay].
  ///
  /// The window is the last [gameActivityDays] days counted back from
  /// [today], but never from further than a week past the newest day already
  /// in this log (the way `mergeGaitHistory` does it): a phone clock that is
  /// wrong and ahead cannot wipe the real days, and a stored entry dated far
  /// in the future cannot either. An added round dated more than a day after
  /// [today] is not believed and is left out.
  GameActivityLog addAll(
    Iterable<GameActivity> activities, {
    required DateTime today,
  }) {
    final todayDay = DateTime(today.year, today.month, today.day);
    final latestDay = gaitDateKey(
      DateTime(todayDay.year, todayDay.month, todayDay.day + 1),
    );
    final merged = {
      for (final e in byDay.entries) e.key: [...e.value],
    };
    for (final a in activities) {
      if (a.day.compareTo(latestDay) > 0) continue;
      merged.putIfAbsent(a.day, () => []).add(a);
    }
    var anchor = todayDay;
    if (byDay.isNotEmpty) {
      final newest = DateTime.parse(
        byDay.keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b),
      );
      final limit = DateTime(newest.year, newest.month, newest.day + 7);
      if (limit.isBefore(anchor)) anchor = limit;
    }
    final cutoff = gaitDateKey(
      DateTime(anchor.year, anchor.month, anchor.day - (gameActivityDays - 1)),
    );
    merged.removeWhere((day, _) => day.compareTo(cutoff) < 0);
    for (final entry in merged.entries) {
      final list = entry.value..sort((a, b) => a.at.compareTo(b.at));
      if (list.length > maxGameActivitiesPerDay) {
        entry.value.removeRange(0, list.length - maxGameActivitiesPerDay);
      }
    }
    return GameActivityLog(merged);
  }

  GameActivityLog add(GameActivity activity, {required DateTime today}) =>
      addAll([activity], today: today);

  /// Whether [activity] is the same report (slug, stage, seconds) as the
  /// latest one kept, less than a second after it: a page that sends twice
  /// for one round.
  bool isRepeat(GameActivity activity) {
    GameActivity? last;
    for (final a in all) {
      if (last == null || !a.at.isBefore(last.at)) last = a;
    }
    if (last == null) return false;
    final gap = activity.at.difference(last.at);
    return last.slug == activity.slug &&
        last.stage == activity.stage &&
        last.seconds == activity.seconds &&
        !gap.isNegative &&
        gap < _repeatWindow;
  }

  /// The slugs played on [day].
  Set<String> slugsOn(DateTime day) => {
    for (final a in byDay[gaitDateKey(day)] ?? const <GameActivity>[]) a.slug,
  };

  bool playedOn(String slug, DateTime day) => slugsOn(day).contains(slug);

  /// The day [slug] was last played, as a local date at midnight, or null
  /// when it is not in the log.
  DateTime? lastPlayed(String slug) {
    String? latest;
    for (final entry in byDay.entries) {
      if (entry.value.any((a) => a.slug == slug) &&
          (latest == null || entry.key.compareTo(latest) > 0)) {
        latest = entry.key;
      }
    }
    return latest == null ? null : DateTime.parse(latest);
  }

  /// Seconds played on [day], summed per slug.
  Map<String, int> secondsOn(DateTime day) {
    final totals = <String, int>{};
    for (final a in byDay[gaitDateKey(day)] ?? const <GameActivity>[]) {
      totals[a.slug] = (totals[a.slug] ?? 0) + a.seconds;
    }
    return totals;
  }

  String encode() => jsonEncode([for (final a in all) a.toJson()]);

  /// The stored log; empty for nothing or anything unreadable, and an entry
  /// that cannot be read is skipped rather than failing the rest.
  static GameActivityLog decode(String? raw, {required DateTime today}) {
    if (raw == null) return const GameActivityLog();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const GameActivityLog();
    }
    if (decoded is! List) return const GameActivityLog();
    return const GameActivityLog().addAll([
      for (final item in decoded)
        if (GameActivity.tryFromJson(item) case final a?) a,
    ], today: today);
  }
}
