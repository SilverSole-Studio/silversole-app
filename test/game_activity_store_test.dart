import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      ]);
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
      ]);
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
      ]);
      expect(log.byDay.keys.toSet(), {'2026-10-25', '2026-11-01'});
    });

    test('survives an encode and decode round trip', () {
      final log = const GameActivityLog().addAll([
        act('laojie', DateTime(2026, 11, 1, 8), stage: 'lantern', seconds: 45),
        act('fish', DateTime(2026, 10, 31, 8)),
      ]);
      final back = GameActivityLog.decode(log.encode());
      expect(back.all.toList(), log.all.toList());
      expect(back.all.first.stage, isNull);
      expect(back.all.last.stage, 'lantern');
    });

    test('anything unreadable decodes to an empty log', () {
      expect(GameActivityLog.decode(null).isEmpty, isTrue);
      expect(GameActivityLog.decode('nope').isEmpty, isTrue);
      expect(GameActivityLog.decode('{"a":1}').isEmpty, isTrue);
      final partly = GameActivityLog.decode(
        '[{"slug":"fish","seconds":5,"at":${at.millisecondsSinceEpoch}},{"slug":3}]',
      );
      expect(partly.all.length, 1);
    });
  });

  group('gameActivityProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves what it records and a new container loads it back', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      first.read(gameActivityProvider);
      await first.read(gameActivityProvider.notifier).record(act('fish', at));
      expect(first.read(gameActivityProvider).playedOn('fish', at), isTrue);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(gameActivityProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(gameActivityProvider).playedOn('fish', at), isTrue);
    });

    test(
      'a round recorded before the load ends keeps the stored days',
      () async {
        final yesterday = at.subtract(const Duration(days: 1));
        SharedPreferences.setMockInitialValues({
          LocalSavableKey.gameActivity.value: const GameActivityLog()
              .add(act('bike', yesterday))
              .encode(),
        });
        final c = ProviderContainer();
        addTearDown(c.dispose);
        await c.read(gameActivityProvider.notifier).record(act('quiz', at));
        final log = c.read(gameActivityProvider);
        expect(log.playedOn('bike', yesterday), isTrue);
        expect(log.playedOn('quiz', at), isTrue);
        final saved = GameActivityLog.decode(
          await loadLocalValue(LocalSavableKey.gameActivity),
        );
        expect(saved.all.length, 2);
      },
    );
  });
}
