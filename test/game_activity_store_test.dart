import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/missions/game_activity_store.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';

void main() {
  final at = DateTime(2026, 11, 1, 9, 30);

  GameActivity act(
    String slug,
    DateTime when, {
    int seconds = 60,
    String? stage,
  }) => GameActivity(slug: slug, stage: stage, seconds: seconds, at: when);

  group('GameActivity.tryParse', () {
    test('a valid report', () {
      expect(
        GameActivity.tryParse({'slug': 'fish', 'seconds': 95}, at),
        act('fish', at, seconds: 95),
      );
    });

    test('the stage may be left out or null, and is kept when given', () {
      expect(
        GameActivity.tryParse({
          'slug': 'laojie',
          'stage': 'lantern',
          'seconds': 40,
        }, at)?.stage,
        'lantern',
      );
      expect(
        GameActivity.tryParse({
          'slug': 'fish',
          'stage': null,
          'seconds': 1,
        }, at)?.stage,
        isNull,
      );
    });

    test('a slug in capitals, too long, or with a space is refused', () {
      for (final slug in [
        'Fish',
        'a' * 33,
        'my game',
        '',
        'fish\n',
        'a/b',
        5,
        null,
      ]) {
        expect(
          GameActivity.tryParse({'slug': slug, 'seconds': 10}, at),
          isNull,
          reason: '$slug',
        );
      }
      expect(
        GameActivity.tryParse({'slug': 'a' * 32, 'seconds': 10}, at),
        isNotNull,
      );
    });

    test('a bad stage is refused', () {
      for (final stage in ['Lantern', 'a b', 'x' * 33, '', 3]) {
        expect(
          GameActivity.tryParse({
            'slug': 'laojie',
            'stage': stage,
            'seconds': 10,
          }, at),
          isNull,
          reason: '$stage',
        );
      }
    });

    test('seconds must be a whole number from 0 to 10800', () {
      for (final s in [
        -1,
        10801,
        1.5,
        double.nan,
        double.infinity,
        '60',
        null,
      ]) {
        expect(
          GameActivity.tryParse({'slug': 'fish', 'seconds': s}, at),
          isNull,
          reason: '$s',
        );
      }
      expect(
        GameActivity.tryParse({'slug': 'fish', 'seconds': 0}, at),
        isNotNull,
      );
      expect(
        GameActivity.tryParse({'slug': 'fish', 'seconds': 10800}, at),
        isNotNull,
      );
      // A JavaScript whole number can arrive as 12.0.
      expect(
        GameActivity.tryParse({'slug': 'fish', 'seconds': 12.0}, at)?.seconds,
        12,
      );
    });

    test('anything that is not a map is refused', () {
      expect(GameActivity.tryParse(null, at), isNull);
      expect(GameActivity.tryParse('fish', at), isNull);
      expect(GameActivity.tryParse(['fish', 3], at), isNull);
    });

    test('an unknown slug is kept as it is', () {
      expect(
        GameActivity.tryParse({'slug': 'newgame', 'seconds': 5}, at)?.slug,
        'newgame',
      );
    });
  });

  group('GameActivityLog', () {
    test('groups by local day and answers the queries', () {
      final log = const GameActivityLog().addAll([
        act('fish', DateTime(2026, 11, 1, 8), seconds: 60),
        act('fish', DateTime(2026, 11, 1, 20), seconds: 30),
        act('quiz', DateTime(2026, 11, 1, 21), seconds: 100),
        act('fish', DateTime(2026, 10, 30, 12)),
        act('bike', DateTime(2026, 10, 29, 12)),
      ], today: DateTime(2026, 11, 1, 23));
      final today = DateTime(2026, 11, 1, 23, 59);
      expect(log.byDay.keys.toSet(), {
        '2026-11-01',
        '2026-10-30',
        '2026-10-29',
      });
      expect(log.slugsOn(today), {'fish', 'quiz'});
      expect(log.playedOn('fish', today), isTrue);
      expect(log.playedOn('bike', today), isFalse);
      expect(log.secondsOn(today), {'fish': 90, 'quiz': 100});
      expect(log.lastPlayed('fish'), DateTime(2026, 11, 1));
      expect(log.lastPlayed('bike'), DateTime(2026, 10, 29));
      expect(log.lastPlayed('pool'), isNull);
      expect(log.slugsOn(DateTime(2026, 10, 31)), isEmpty);
    });

    test('keeps only the newest eight days', () {
      final log = const GameActivityLog().addAll([
        for (var d = 0; d < 12; d++)
          act('fish', DateTime(2026, 11, 12 - d, 12)),
      ], today: DateTime(2026, 11, 12, 20));
      expect(log.byDay.length, gameActivityDays);
      expect(
        log.byDay.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b),
        '2026-11-05',
      );
      expect(log.playedOn('fish', DateTime(2026, 11, 4)), isFalse);
      expect(log.playedOn('fish', DateTime(2026, 11, 5)), isTrue);
    });

    test('the window counts back across a month change', () {
      final log = const GameActivityLog().addAll([
        act('fish', DateTime(2026, 10, 25)),
        act('fish', DateTime(2026, 10, 24)),
        act('fish', DateTime(2026, 11, 1)),
      ], today: DateTime(2026, 11, 1, 20));
      expect(log.byDay.keys.toSet(), {'2026-10-25', '2026-11-01'});
    });

    test('survives an encode and decode round trip', () {
      final log = const GameActivityLog().addAll([
        act('laojie', DateTime(2026, 11, 1, 8), stage: 'lantern', seconds: 45),
        act('fish', DateTime(2026, 10, 31, 8)),
      ], today: DateTime(2026, 11, 1, 20));
      final back = GameActivityLog.decode(
        log.encode(),
        today: DateTime(2026, 11, 1, 20),
      );
      expect(back.all.toList(), log.all.toList());
      expect(back.all.first.stage, isNull);
      expect(back.all.last.stage, 'lantern');
    });

    test('anything unreadable decodes to an empty log', () {
      expect(GameActivityLog.decode(null, today: at).isEmpty, isTrue);
      expect(GameActivityLog.decode('nope', today: at).isEmpty, isTrue);
      expect(GameActivityLog.decode('{"a":1}', today: at).isEmpty, isTrue);
      final partly = GameActivityLog.decode(
        '[{"slug":"fish","seconds":5,"at":${at.millisecondsSinceEpoch}},{"slug":3}]',
        today: at,
      );
      expect(partly.all.length, 1);
    });
  });

  group('GameActivityLog limits', () {
    test('a day keeps its newest 200 rounds', () {
      final day = DateTime(2026, 11, 1);
      final log = const GameActivityLog().addAll([
        for (var i = 0; i < 250; i++)
          act('fish', day.add(Duration(seconds: i * 10)), seconds: i),
      ], today: DateTime(2026, 11, 1, 23));
      final kept = log.byDay['2026-11-01']!;
      expect(kept, hasLength(maxGameActivitiesPerDay));
      // The oldest 50 went: seconds 0..49 are gone, 50..249 stay.
      expect(kept.first.seconds, 50);
      expect(kept.last.seconds, 249);
      // Another day is not touched by it.
      final more = log.add(
        act('quiz', DateTime(2026, 10, 31, 9)),
        today: DateTime(2026, 11, 1, 23),
      );
      expect(more.byDay['2026-10-31'], hasLength(1));
      expect(more.byDay['2026-11-01'], hasLength(maxGameActivitiesPerDay));
    });

    test('isRepeat: the same report less than a second after the last', () {
      final first = act('fish', at, seconds: 60);
      final log = const GameActivityLog().add(first, today: at);
      GameActivity again(
        Duration after, {
        String slug = 'fish',
        String? stage,
        int seconds = 60,
      }) => GameActivity(
        slug: slug,
        stage: stage,
        seconds: seconds,
        at: at.add(after),
      );
      expect(log.isRepeat(again(const Duration(milliseconds: 999))), isTrue);
      expect(log.isRepeat(again(Duration.zero)), isTrue);
      expect(log.isRepeat(again(const Duration(seconds: 1))), isFalse);
      expect(
        log.isRepeat(again(const Duration(milliseconds: 100), seconds: 61)),
        isFalse,
      );
      expect(
        log.isRepeat(again(const Duration(milliseconds: 100), slug: 'quiz')),
        isFalse,
      );
      expect(
        log.isRepeat(again(const Duration(milliseconds: 100), stage: 'x')),
        isFalse,
      );
      expect(
        log.isRepeat(again(const Duration(milliseconds: -100))),
        isFalse,
        reason: 'not after it',
      );
      expect(const GameActivityLog().isRepeat(first), isFalse);
    });

    test('a stored entry dated 2030 does not wipe the real days', () {
      final real = [
        act('fish', DateTime(2026, 10, 30, 9)),
        act('bike', DateTime(2026, 10, 31, 9)),
      ];
      final stored = GameActivityLog({
        '2030-01-01': [act('hop', DateTime(2030, 1, 1, 9))],
        for (final a in real) a.day: [a],
      });
      final now = DateTime(2026, 11, 1, 10);
      final after = stored.add(act('quiz', now), today: now);
      expect(after.playedOn('fish', DateTime(2026, 10, 30)), isTrue);
      expect(after.playedOn('bike', DateTime(2026, 10, 31)), isTrue);
      expect(after.playedOn('quiz', now), isTrue, reason: 'today is kept');

      // Loaded from the phone, the entry from the future is not believed
      // and the real days stay.
      final raw = GameActivityLog({...stored.byDay}).encode();
      final loaded = GameActivityLog.decode(raw, today: now);
      expect(loaded.playedOn('hop', DateTime(2030, 1, 1)), isFalse);
      expect(loaded.playedOn('fish', DateTime(2026, 10, 30)), isTrue);
      expect(loaded.playedOn('bike', DateTime(2026, 10, 31)), isTrue);
    });

    test('a clock that jumped ahead keeps the real days a week more', () {
      final stored = const GameActivityLog().addAll([
        act('fish', DateTime(2026, 11, 1, 9)),
        act('bike', DateTime(2026, 10, 28, 9)),
      ], today: DateTime(2026, 11, 1, 10));
      final wrong = DateTime(2030, 6, 1, 10);
      final after = stored.add(act('quiz', wrong), today: wrong);
      expect(after.playedOn('fish', DateTime(2026, 11, 1)), isTrue);
      expect(after.playedOn('quiz', wrong), isTrue);
      expect(after.playedOn('bike', DateTime(2026, 10, 28)), isFalse);
    });

    test('a round dated more than a day after today is left out', () {
      final now = DateTime(2026, 11, 1, 10);
      final log = const GameActivityLog().addAll([
        act('fish', DateTime(2026, 11, 2, 9)),
        act('bike', DateTime(2026, 11, 3, 9)),
      ], today: now);
      expect(log.byDay.keys, ['2026-11-02']);
    });
  });

  group('gameActivityProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves what it records and a new container loads it back', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      first.read(gameActivityProvider);
      await withClock(
        Clock.fixed(at),
        () => first.read(gameActivityProvider.notifier).record(act('fish', at)),
      );
      expect(first.read(gameActivityProvider).playedOn('fish', at), isTrue);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      await withClock(Clock.fixed(at), () async {
        second.read(gameActivityProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      });
      expect(second.read(gameActivityProvider).playedOn('fish', at), isTrue);
    });

    test(
      'a round recorded before the load ends keeps the stored days',
      () async {
        final yesterday = at.subtract(const Duration(days: 1));
        SharedPreferences.setMockInitialValues({
          LocalSavableKey.gameActivity.value: const GameActivityLog()
              .add(act('bike', yesterday), today: at)
              .encode(),
        });
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await withClock(
          Clock.fixed(at),
          () => c.read(gameActivityProvider.notifier).record(act('quiz', at)),
        );
        final log = c.read(gameActivityProvider);
        expect(log.playedOn('bike', yesterday), isTrue);
        expect(log.playedOn('quiz', at), isTrue);
        final saved = GameActivityLog.decode(
          await loadLocalValue(LocalSavableKey.gameActivity),
          today: at,
        );
        expect(saved.all.length, 2);
      },
    );

    test('a report repeating the one before it is dropped', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(gameActivityProvider.notifier);
      await withClock(Clock.fixed(at), () async {
        expect(await notifier.record(act('fish', at, seconds: 40)), isTrue);
        expect(
          await notifier.record(
            act('fish', at.add(const Duration(milliseconds: 400)), seconds: 40),
          ),
          isTrue,
        );
        expect(
          await notifier.record(
            act('fish', at.add(const Duration(seconds: 2)), seconds: 40),
          ),
          isTrue,
        );
      });
      expect(c.read(gameActivityProvider).byDay['2026-11-01'], hasLength(2));
    });

    test('a save that fails keeps the round and answers false', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(gameActivityProvider.notifier);
      await withClock(
        Clock.fixed(at),
        () =>
            notifier.record(act('quiz', at.subtract(const Duration(days: 1)))),
      );
      SharedPreferencesStorePlatform.instance = _FailingStore();
      final ok = await withClock(
        Clock.fixed(at),
        () => notifier.record(act('fish', at)),
      );
      expect(ok, isFalse);
      expect(c.read(gameActivityProvider).playedOn('fish', at), isTrue);
    });
  });
}

/// A phone store that cannot be written (or cleared): for a full or broken disk.
class _FailingStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async => false;

  @override
  Future<Map<String, Object>> getAll() async => {};

  @override
  Future<bool> remove(String key) async => throw Exception('disk full');

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception('disk full');
}
