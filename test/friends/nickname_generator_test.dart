import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/friends/nickname_generator.dart';

void main() {
  group('suggestion pool', () {
    test('has at least 300 names, and plenty to roll through', () {
      expect(allNicknameSuggestions().length, greaterThanOrEqualTo(300));
      expect(allNicknameSuggestions().length, greaterThanOrEqualTo(1000));
    });

    test('every combination passes the nickname rules', () {
      // Not a sample: the whole pool, so a bad word or an over-long pairing
      // added to the lists fails here instead of reaching a user.
      final failures = <String>[
        for (final name in allNicknameSuggestions())
          if (validateNickname(name) != null)
            '$name: ${validateNickname(name)!.name}',
      ];
      expect(failures, isEmpty);
    });

    test('nothing is dropped as a duplicate by accident', () {
      final expected =
          kNicknameDescriptions.length * kNicknameCompanions.length +
          kNicknameGroups.fold<int>(0, (sum, g) => sum + g.size);
      expect(allNicknameSuggestions().length, expected);
    });

    test('names are plain, trimmed, full-width-punctuation-free text', () {
      for (final name in allNicknameSuggestions()) {
        expect(name, isNotEmpty);
        expect(trimNickname(name), name, reason: name);
        // Traditional Chinese characters only: no ASCII, no punctuation.
        expect(
          RegExp(r'^[\u4E00-\u9FFF]+$').hasMatch(name),
          isTrue,
          reason: name,
        );
        expect(name.runes.length, inInclusiveRange(2, kNicknameMaxLength));
      }
    });

    test('the examples from the brief are in the pool', () {
      expect(
        allNicknameSuggestions(),
        containsAll(['愛散步的阿桃', '健走小隊長', '菜園小農夫', '早起的阿伯']),
      );
    });
  });

  group('NicknameGenerator', () {
    test('1000 rolls are never empty and always valid', () {
      final gen = NicknameGenerator(Random(7));
      for (var i = 0; i < 1000; i++) {
        final name = gen.next();
        expect(name, isNotEmpty);
        expect(validateNickname(name), isNull, reason: name);
      }
    });

    test('1000 rolls mostly differ from each other', () {
      final gen = NicknameGenerator(Random(11));
      final seen = {for (var i = 0; i < 1000; i++) gen.next()};
      // Drawn from ~1400 names, so some repeats are expected (about 20%);
      // a broken picker that favours a few names would fall far below this.
      expect(seen.length, greaterThan(600));
    });

    test('the dice never hands back the name that is already showing', () {
      final gen = NicknameGenerator(Random(3));
      var current = gen.next();
      for (var i = 0; i < 1000; i++) {
        final next = gen.next(not: current);
        expect(next, isNot(current));
        current = next;
      }
    });

    test('the same seed gives the same sequence', () {
      final a = NicknameGenerator(Random(5));
      final b = NicknameGenerator(Random(5));
      expect(
        [for (var i = 0; i < 20; i++) a.next()],
        [for (var i = 0; i < 20; i++) b.next()],
      );
    });

    test('the last-resort name is itself valid', () {
      expect(validateNickname(kFallbackNickname), isNull);
    });
  });
}
