import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/diamonds/diamond_repository.dart';

void main() {
  group('DiamondRepository', () {
    test('earn sends the minutes by name and reads the answer', () async {
      final calls = <String>[];
      final repo = DiamondRepository((fn, params) async {
        calls.add('$fn ${params['p_minutes']}');
        return {
          'ok': true,
          'earned': 10,
          'balance': 40,
          'month': 40,
          'cap': 300,
          'subscribed': true,
          'activeUntil': '2026-12-31',
        };
      }, () => true);
      final res = await repo.earnExercise(18);
      expect(calls, ['diamond_earn_exercise 18']);
      expect(res.ok, isTrue);
      expect(res.earned, 10);
      expect(
        res.balance,
        const DiamondBalance(
          balance: 40,
          month: 40,
          cap: 300,
          subscribed: true,
          activeUntil: '2026-12-31',
        ),
      );
    });

    test('a refusal keeps the reason and the numbers', () async {
      final repo = DiamondRepository(
        (fn, params) async => {
          'ok': false,
          'reason': 'already_today',
          'balance': 10,
          'month': 10,
          'cap': 300,
          'subscribed': true,
          'activeUntil': null,
        },
        () => true,
      );
      final res = await repo.earnExercise(30);
      expect(res.ok, isFalse);
      expect(res.reason, 'already_today');
      expect(res.earned, 0);
      expect(res.balance?.balance, 10);
    });

    test('balance calls diamond_balance with no arguments', () async {
      Map<String, dynamic>? seen;
      String? called;
      final repo = DiamondRepository((fn, params) async {
        called = fn;
        seen = params;
        return {
          'ok': true,
          'balance': 0,
          'month': 0,
          'cap': 300,
          'subscribed': false,
        };
      }, () => true);
      final res = await repo.balance();
      expect(called, 'diamond_balance');
      expect(seen, isEmpty);
      expect(res.balance?.subscribed, isFalse);
      expect(res.balance?.activeUntil, isNull);
    });

    test('signed out never calls the server', () async {
      var called = false;
      final repo = DiamondRepository((fn, params) async {
        called = true;
        return {};
      }, () => false);
      expect((await repo.balance()).reason, 'signed_out');
      expect((await repo.earnExercise(20)).reason, 'signed_out');
      expect(called, isFalse);
    });

    test('a failed call or a strange answer is offline, not a crash', () async {
      final broken = DiamondRepository(
        (fn, params) async => throw Exception('no network'),
        () => true,
      );
      expect((await broken.balance()).reason, 'offline');
      final odd = DiamondRepository((fn, params) async => 'nope', () => true);
      expect((await odd.earnExercise(20)).reason, 'offline');
    });

    test('an answer without numbers has no balance', () async {
      final repo = DiamondRepository(
        (fn, params) async => {'ok': false, 'reason': 'rate_limited'},
        () => true,
      );
      final res = await repo.balance();
      expect(res.reason, 'rate_limited');
      expect(res.balance, isNull);
    });
  });
}
