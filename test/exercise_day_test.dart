import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/diamonds/exercise_day.dart';

void main() {
  final noon = DateTime(2026, 11, 3, 12);

  test('15 minutes is the line: 14:59 is not enough, 15:00 is', () {
    var day = ExerciseDay.empty('u1', noon);
    day = day.addSeconds(899, userId: 'u1', now: noon);
    expect(day.minutes, 14);
    expect(day.readyToEarn, isFalse);
    day = day.addSeconds(1, userId: 'u1', now: noon);
    expect(day.minutes, 15);
    expect(day.readyToEarn, isTrue);
  });

  test('rounds from several games add up', () {
    var day = ExerciseDay.empty('u1', noon);
    for (final s in [300, 420, 200]) {
      day = day.addSeconds(s, userId: 'u1', now: noon);
    }
    expect(day.seconds, 920);
    expect(day.readyToEarn, isTrue);
  });

  test('once settled it does not ask again that day', () {
    final day = ExerciseDay.empty(
      'u1',
      noon,
    ).addSeconds(1200, userId: 'u1', now: noon).markSettled();
    expect(day.readyToEarn, isFalse);
    expect(day.addSeconds(600, userId: 'u1', now: noon).readyToEarn, isFalse);
  });

  test('a new day starts from zero and unsettled', () {
    final yesterday = ExerciseDay.empty(
      'u1',
      noon,
    ).addSeconds(1200, userId: 'u1', now: noon).markSettled();
    final next = yesterday.addSeconds(
      60,
      userId: 'u1',
      now: noon.add(const Duration(days: 1)),
    );
    expect(next.seconds, 60);
    expect(next.settled, isFalse);
    expect(next.day, '2026-11-04');
  });

  test('another account on the same phone does not inherit the minutes', () {
    final mine = ExerciseDay.empty(
      'u1',
      noon,
    ).addSeconds(1200, userId: 'u1', now: noon);
    final theirs = mine.addSeconds(30, userId: 'u2', now: noon);
    expect(theirs.userId, 'u2');
    expect(theirs.seconds, 30);
  });

  test('zero and negative seconds add nothing; a day holds at most 24 h', () {
    var day = ExerciseDay.empty('u1', noon);
    expect(day.addSeconds(0, userId: 'u1', now: noon).seconds, 0);
    expect(day.addSeconds(-50, userId: 'u1', now: noon).seconds, 0);
    for (var i = 0; i < 10; i++) {
      day = day.addSeconds(10800, userId: 'u1', now: noon);
    }
    expect(day.seconds, maxExerciseSecondsPerDay);
  });

  group('stored form', () {
    test('round trips for the same account and day', () {
      final day = ExerciseDay.empty(
        'u1',
        noon,
      ).addSeconds(500, userId: 'u1', now: noon).markSettled();
      final back = ExerciseDay.decode(day.encode(), userId: 'u1', now: noon);
      expect(back.seconds, 500);
      expect(back.settled, isTrue);
    });

    test('yesterday, someone else or garbage reads as a fresh day', () {
      final stored = ExerciseDay.empty(
        'u1',
        noon,
      ).addSeconds(500, userId: 'u1', now: noon).encode();
      final tomorrow = noon.add(const Duration(days: 1));
      expect(
        ExerciseDay.decode(stored, userId: 'u1', now: tomorrow).seconds,
        0,
      );
      expect(ExerciseDay.decode(stored, userId: 'u2', now: noon).seconds, 0);
      for (final bad in [
        null,
        '',
        'x',
        '[]',
        '{"uid":"u1","day":"2026-11-03","seconds":-1}',
      ]) {
        expect(ExerciseDay.decode(bad, userId: 'u1', now: noon).seconds, 0);
      }
    });
  });
}
