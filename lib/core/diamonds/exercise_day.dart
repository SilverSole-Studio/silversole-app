import 'dart:convert';

import 'package:silversole/core/diamonds/diamond_repository.dart';
import 'package:silversole/core/gait/daily_gait.dart';

/// A day cannot hold more than 24 hours of exercise.
const maxExerciseSecondsPerDay = 24 * 3600;

/// Today's insole exercise on this phone: the seconds the games reported
/// while a sole was connected, plus whether today's payout was settled.
///
/// Kept per account and per local calendar day: a new day, or another account
/// on the same phone, starts from zero.
class ExerciseDay {
  const ExerciseDay({
    required this.userId,
    required this.day,
    this.seconds = 0,
    this.settled = false,
  });

  /// A fresh day for [userId] at [now].
  factory ExerciseDay.empty(String userId, DateTime now) =>
      ExerciseDay(userId: userId, day: gaitDateKey(now));

  final String userId;

  /// Local calendar day, a [gaitDateKey].
  final String day;

  /// Seconds of exercise with a sole connected.
  final int seconds;

  /// The server has dealt with today's payout (paid, already paid, or the
  /// month is full): no need to ask again today.
  final bool settled;

  int get minutes => seconds ~/ 60;

  /// Enough exercise to ask for the payout, and not asked yet.
  bool get readyToEarn => !settled && minutes >= DiamondRules.minMinutes;

  /// This day with [add] seconds more; a different [userId] or day starts
  /// over. Zero or negative seconds add nothing.
  ExerciseDay addSeconds(
    int add, {
    required String userId,
    required DateTime now,
  }) {
    final base = (this.userId == userId && day == gaitDateKey(now))
        ? this
        : ExerciseDay.empty(userId, now);
    if (add <= 0) return base;
    final total = base.seconds + add;
    return ExerciseDay(
      userId: base.userId,
      day: base.day,
      seconds: total > maxExerciseSecondsPerDay
          ? maxExerciseSecondsPerDay
          : total,
      settled: base.settled,
    );
  }

  ExerciseDay markSettled() =>
      ExerciseDay(userId: userId, day: day, seconds: seconds, settled: true);

  String encode() => jsonEncode({
    'uid': userId,
    'day': day,
    'seconds': seconds,
    'settled': settled,
  });

  /// The stored day for [userId] if it is today's; otherwise a fresh one.
  static ExerciseDay decode(
    String? raw, {
    required String userId,
    required DateTime now,
  }) {
    final fresh = ExerciseDay.empty(userId, now);
    if (raw == null) return fresh;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return fresh;
      final seconds = m['seconds'];
      if (m['uid'] != userId ||
          m['day'] != fresh.day ||
          seconds is! int ||
          seconds < 0) {
        return fresh;
      }
      return ExerciseDay(
        userId: userId,
        day: fresh.day,
        seconds: seconds > maxExerciseSecondsPerDay
            ? maxExerciseSecondsPerDay
            : seconds,
        settled: m['settled'] == true,
      );
    } on FormatException {
      return fresh;
    }
  }
}
