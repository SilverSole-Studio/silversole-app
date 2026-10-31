import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/game_save/game_save_repository.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';

void main() {
  group('GameSaveRepository', () {
    test('passes the server answer through and the args by name', () async {
      final calls = <String>[];
      final repo = GameSaveRepository((fn, params) async {
        calls.add('$fn ${params['p_rev']} ${params['p_data']}');
        return {'ok': true, 'rev': 4};
      }, () => true);
      expect(await repo.store(3, '{"coins":5}'), {'ok': true, 'rev': 4});
      expect(calls, ['game_save_store 3 {"coins":5}']);
    });

    test('signed out never calls the server', () async {
      var called = false;
      final repo = GameSaveRepository((fn, params) async {
        called = true;
        return {};
      }, () => false);
      expect(await repo.load(), {'ok': false, 'reason': 'signed_out'});
      expect(called, isFalse);
    });

    test('a failed call is offline, not a crash', () async {
      final repo = GameSaveRepository(
        (fn, params) async => throw Exception('no network'),
        () => true,
      );
      expect(await repo.load(), {'ok': false, 'reason': 'offline'});
    });

    test('too big is refused before sending (counted in UTF-8 bytes)', () async {
      var called = false;
      final repo = GameSaveRepository((fn, params) async {
        called = true;
        return {'ok': true, 'rev': 1};
      }, () => true);
      // 87,382 CJK characters are 262,146 UTF-8 bytes but only 87,382 code units.
      final big = '{"x":"${'粗' * 87382}"}';
      expect(await repo.store(0, big), {'ok': false, 'reason': 'too_big'});
      expect(called, isFalse);
    });
  });

  group('PlazaBridge.storeArgs', () {
    test('takes {rev, data}', () {
      expect(PlazaBridge.storeArgs([
        {'rev': 2, 'data': '{}'},
      ]), (rev: 2, data: '{}'));
      expect(PlazaBridge.storeArgs([
        {'rev': 2.0, 'data': '{}'},
      ])?.rev, 2);
    });

    test('anything else is refused', () {
      for (final bad in <List<dynamic>>[
        [],
        ['{}'],
        [
          {'rev': -1, 'data': '{}'},
        ],
        [
          {'rev': 1.5, 'data': '{}'},
        ],
        [
          {'rev': '1', 'data': '{}'},
        ],
        [
          {'rev': 1, 'data': 5},
        ],
      ]) {
        expect(PlazaBridge.storeArgs(bad), isNull, reason: '$bad');
      }
    });
  });
}
