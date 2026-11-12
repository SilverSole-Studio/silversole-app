import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/active_aging/aa_bridge.dart';
import 'package:silversole/core/active_aging/aa_repository.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';
import 'package:silversole/shared/widgets/aa_unlock.dart';

const _id = '11111111-1111-4111-8111-111111111111';

Map<String, Object?> _call(String fn, [Map<String, Object?>? args]) => {
  'fn': fn,
  if (args != null) 'args': args,
};

void main() {
  group('AaBridge.parse: the fn whitelist', () {
    test('exactly the twelve functions of 08 §2', () {
      expect(AaBridge.functions.keys.toSet(), {
        'aa_me',
        'aa_invite_redeem',
        'aa_session_upsert',
        'aa_session_close',
        'aa_participants_upsert',
        'aa_consents_upsert',
        'aa_measurements_upsert',
        'aa_events_upsert',
        'aa_session_pull',
        'aa_session_list',
        'aa_session_delete',
        'aa_participant_erase',
      });
    });

    test('each function maps the page\'s argument names to p_<name>', () {
      final cases = <String, Map<String, Object?>>{
        'aa_me': {},
        'aa_invite_redeem': {'code': '12345678'},
        'aa_session_upsert': {
          'session': {'id': _id},
        },
        'aa_session_close': {'id': _id, 'closed_at': '2026-11-13T10:00:00Z'},
        'aa_participants_upsert': {'session_id': _id, 'rows': []},
        'aa_consents_upsert': {'session_id': _id, 'rows': []},
        'aa_measurements_upsert': {'session_id': _id, 'rows': []},
        'aa_events_upsert': {'session_id': _id, 'rows': []},
        'aa_session_pull': {'id': _id},
        'aa_session_list': {'limit': 5},
        'aa_session_delete': {'id': _id},
        'aa_participant_erase': {'session_id': _id, 'code': 'P01'},
      };
      expect(cases.keys.toSet(), AaBridge.functions.keys.toSet());
      for (final e in cases.entries) {
        final r = AaBridge.parse([_call(e.key, e.value)]);
        expect(r.ok, isTrue, reason: e.key);
        expect(r.rpc, e.key);
        expect(r.params, {
          for (final a in e.value.entries) 'p_${a.key}': a.value,
        });
      }
    });

    test('any other name, or no name, is refused without a call', () {
      for (final bad in [
        'aa_admin_invite_create',
        'aa_gate',
        'game_save_store',
        'select',
        'aa_me; drop table x',
        'AA_ME',
        '',
      ]) {
        final r = AaBridge.parse([_call(bad)]);
        expect(r.ok, isFalse, reason: bad);
        expect(r.reason, 'invalid', reason: bad);
        expect(r.rpc, isNull);
      }
      expect(AaBridge.parse([]).reason, 'invalid');
      expect(AaBridge.parse(['aa_me']).reason, 'invalid');
      expect(
        AaBridge.parse([
          {'args': {}},
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          {'fn': 5},
        ]).reason,
        'invalid',
      );
      expect(AaBridge.parse([null]).reason, 'invalid');
    });

    test(
      'an argument the function does not take is refused (nothing rides along)',
      () {
        expect(
          AaBridge.parse([
            _call('aa_me', {'p_x': 1}),
          ]).reason,
          'invalid',
        );
        expect(
          AaBridge.parse([
            _call('aa_session_pull', {'id': _id, 'owner': 'x'}),
          ]).reason,
          'invalid',
        );
        // The p_ names are the app's, not the page's.
        expect(
          AaBridge.parse([
            _call('aa_session_pull', {'p_id': _id}),
          ]).reason,
          'invalid',
        );
      },
    );

    test('missing, null or wrong-typed arguments are refused', () {
      expect(AaBridge.parse([_call('aa_session_pull')]).reason, 'invalid');
      expect(
        AaBridge.parse([
          _call('aa_session_pull', {'id': null}),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_session_pull', {'id': 'not-a-uuid'}),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_session_pull', {'id': 5}),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_session_upsert', {'session': 'x'}),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_session_upsert', {
            'session': [1],
          }),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_measurements_upsert', {
            'session_id': _id,
            'rows': {'a': 1},
          }),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_measurements_upsert', {'session_id': _id}),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_session_list', {'limit': 1.5}),
        ]).reason,
        'invalid',
      );
      expect(
        AaBridge.parse([
          _call('aa_invite_redeem', {'code': 12345678}),
        ]).reason,
        'invalid',
      );
    });

    test('limit is optional', () {
      final r = AaBridge.parse([_call('aa_session_list')]);
      expect(r.ok, isTrue);
      expect(r.params, isEmpty);
      expect(
        AaBridge.parse([
          _call('aa_session_list', {'limit': null}),
        ]).ok,
        isTrue,
      );
    });

    test('a request over 100 KB is too_large', () {
      final rows = [
        {'note': 'x' * 120000},
      ];
      final r = AaBridge.parse([
        _call('aa_measurements_upsert', {'session_id': _id, 'rows': rows}),
      ]);
      expect(r.reason, 'too_large');
      expect(r.rpc, isNull);
      final ok = AaBridge.parse([
        _call('aa_measurements_upsert', {
          'session_id': _id,
          'rows': [
            {'note': 'x' * 1000},
          ],
        }),
      ]);
      expect(ok.ok, isTrue);
    });

    test('size counts UTF-8 bytes, not characters', () {
      // 40,000 Chinese characters are 120,000 bytes.
      final rows = [
        {'note': '腳' * 40000},
      ];
      expect(
        AaBridge.parse([
          _call('aa_events_upsert', {'session_id': _id, 'rows': rows}),
        ]).reason,
        'too_large',
      );
      expect(
        utf8.encode('腳' * 40000).length,
        greaterThan(AaBridge.maxArgsBytes),
      );
    });
  });

  group('reasons and answers', () {
    test('the reason list is 08 §1 plus the app\'s own offline', () {
      expect(AaBridge.reasons, {
        'signed_out',
        'not_member',
        'forbidden',
        'rate_limited',
        'offline',
        'invalid',
        'too_large',
        'closed',
      });
    });

    test('a known reason passes, an unknown one is invalid', () {
      for (final r in AaBridge.reasons) {
        expect(AaBridge.reasonOf(r), r);
      }
      expect(AaBridge.reasonOf('no_consent'), 'invalid');
      expect(AaBridge.reasonOf('42501: permission denied'), 'invalid');
      expect(AaBridge.reasonOf(null), 'invalid');
      expect(AaBridge.reasonOf(7), 'invalid');
    });

    test('ok answers keep the server\'s fields under data, without ok', () {
      expect(
        AaBridge.wrap({
          'ok': true,
          'accepted': 2,
          'rejected': [
            {'mid': 'a', 'reason': 'no_consent'},
          ],
        }),
        {
          'ok': true,
          'data': {
            'accepted': 2,
            'rejected': [
              {'mid': 'a', 'reason': 'no_consent'},
            ],
          },
        },
      );
      expect(AaBridge.wrap({'ok': true}), {
        'ok': true,
        'data': <String, Object?>{},
      });
    });

    test('failures become {ok:false, reason} with a known reason only', () {
      expect(AaBridge.wrap({'ok': false, 'reason': 'closed'}), {
        'ok': false,
        'reason': 'closed',
      });
      expect(AaBridge.wrap({'ok': false, 'reason': 'weird'}), {
        'ok': false,
        'reason': 'invalid',
      });
      expect(AaBridge.wrap({'ok': false}), {'ok': false, 'reason': 'invalid'});
      expect(AaBridge.wrap({'reason': 'closed'}), {
        'ok': false,
        'reason': 'closed',
      });
    });

    test('an answer that is not a map is offline', () {
      expect(AaBridge.wrap(null), {'ok': false, 'reason': 'offline'});
      expect(AaBridge.wrap('x'), {'ok': false, 'reason': 'offline'});
    });
  });

  group('AaRepository', () {
    test('signed out never calls the server', () async {
      var called = false;
      final repo = AaRepository((fn, params) async {
        called = true;
        return {'ok': true};
      }, () => false);
      expect(await repo.handle([_call('aa_me')]), {
        'ok': false,
        'reason': 'signed_out',
      });
      expect(await repo.isActive(), isFalse);
      expect(called, isFalse);
    });

    test('a refused call never reaches the server', () async {
      var called = false;
      final repo = AaRepository((fn, params) async {
        called = true;
        return {'ok': true};
      }, () => true);
      expect(await repo.handle([_call('aa_admin_purge_expired')]), {
        'ok': false,
        'reason': 'invalid',
      });
      expect(
        await repo.handle([
          _call('aa_session_pull', {'id': 'x'}),
        ]),
        {'ok': false, 'reason': 'invalid'},
      );
      expect(called, isFalse);
    });

    test('passes the rpc name and p_ params, and wraps the answer', () async {
      final seen = <String>[];
      final repo = AaRepository((fn, params) async {
        seen.add('$fn ${jsonEncode(params)}');
        return {'ok': true, 'n': 3};
      }, () => true);
      final res = await repo.handle([
        _call('aa_participants_upsert', {'session_id': _id, 'rows': []}),
      ]);
      expect(res, {
        'ok': true,
        'data': {'n': 3},
      });
      expect(seen, [
        'aa_participants_upsert {"p_session_id":"$_id","p_rows":[]}',
      ]);
    });

    test('a thrown error is offline, a server reason passes through', () async {
      final boom = AaRepository(
        (fn, params) async => throw Exception('no network'),
        () => true,
      );
      expect(await boom.handle([_call('aa_me')]), {
        'ok': false,
        'reason': 'offline',
      });
      final closed = AaRepository(
        (fn, params) async => {'ok': false, 'reason': 'closed'},
        () => true,
      );
      expect(
        await closed.handle([
          _call('aa_session_close', {'id': _id, 'closed_at': 'x'}),
        ]),
        {'ok': false, 'reason': 'closed'},
      );
    });

    test('isActive is true only for aa_me().active == true', () async {
      Future<bool> answered(Object? answer) =>
          AaRepository((fn, params) async => answer, () => true).isActive();
      expect(
        await answered({'ok': true, 'active': true, 'role': 'instructor'}),
        isTrue,
      );
      expect(
        await answered({'ok': true, 'active': false, 'role': null}),
        isFalse,
      );
      expect(await answered({'ok': false, 'reason': 'not_member'}), isFalse);
      expect(await answered({'ok': true, 'active': 'true'}), isFalse);
      expect(await answered(null), isFalse);
    });

    test('redeem checks the code\'s shape before asking the server', () async {
      var calls = 0;
      final repo = AaRepository((fn, params) async {
        calls++;
        expect(fn, 'aa_invite_redeem');
        expect(params, {'p_code': '12345678'});
        return {'ok': true, 'role': 'assistant'};
      }, () => true);
      for (final bad in [
        '',
        '1234567',
        '123456789',
        '02345678',
        'abcdefgh',
        '1234 5678',
      ]) {
        expect(await repo.redeem(bad), {
          'ok': false,
          'reason': 'invalid',
        }, reason: bad);
      }
      expect(calls, 0);
      expect(await repo.redeem(' 12345678 '), {
        'ok': true,
        'data': {'role': 'assistant'},
      });
      expect(calls, 1);
    });
  });

  group('the page it serves', () {
    const game = 'https://h5.silversole.dongyu.company/';

    test('the entry opens game/aa/ on the games\' site', () {
      expect(
        AaBridge.pageUrl(game),
        'https://h5.silversole.dongyu.company/game/aa/',
      );
    });

    test('only pages under game/aa/ of the same origin count', () {
      bool at(String u) => AaBridge.isAaPage(Uri.parse(u), game);
      expect(at('https://h5.silversole.dongyu.company/game/aa/'), isTrue);
      expect(at('https://h5.silversole.dongyu.company/game/aa'), isTrue);
      expect(
        at('https://h5.silversole.dongyu.company/game/aa/index.html'),
        isTrue,
      );
      expect(
        at('https://h5.silversole.dongyu.company/game/aa/session/?x=1'),
        isTrue,
      );
      expect(at('https://h5.silversole.dongyu.company/game/world/'), isFalse);
      expect(at('https://h5.silversole.dongyu.company/game/aaa/'), isFalse);
      expect(at('https://h5.silversole.dongyu.company/game/'), isFalse);
      expect(
        at('https://h5.silversole.dongyu.company/other/game/aa/'),
        isFalse,
      );
      expect(at('https://evil.example/game/aa/'), isFalse);
      expect(at('http://h5.silversole.dongyu.company/game/aa/'), isFalse);
      expect(at('https://h5.silversole.dongyu.company:8443/game/aa/'), isFalse);
      expect(at('file:///game/aa/'), isFalse);
      expect(AaBridge.isAaPage(null, game), isFalse);
    });

    test('a game url with a path prefix keeps the prefix', () {
      expect(
        AaBridge.isAaPage(
          Uri.parse('https://x.example/app/game/aa/'),
          'https://x.example/app/',
        ),
        isTrue,
      );
      expect(
        AaBridge.isAaPage(
          Uri.parse('https://x.example/game/aa/'),
          'https://x.example/app/',
        ),
        isFalse,
      );
    });
  });

  group('features.activeAging', () {
    test('not there for an ordinary account, true only when the role is', () {
      final plain = PlazaBridge.info(friends: false, friendRequests: 0);
      expect((plain['features']! as Map).containsKey('activeAging'), isFalse);
      final off = PlazaBridge.info(
        friends: true,
        friendRequests: 0,
        activeAging: false,
      );
      expect(off['features'], {'friends': true});
      final on = PlazaBridge.info(
        friends: false,
        friendRequests: 0,
        activeAging: true,
      );
      expect(on['features'], {'friends': false, 'activeAging': true});
    });

    test('the published script carries it', () {
      final info = PlazaBridge.info(
        friends: false,
        friendRequests: 0,
        activeAging: true,
      );
      expect(PlazaBridge.publishScript(info), contains('"activeAging":true'));
    });

    test(
      'the flag provider is false while the backend is off (no Supabase here)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        expect(container.read(activeAgingEnabledProvider), isFalse);
        expect(await container.read(aaActiveProvider.future), isFalse);
      },
    );
  });

  group('the hidden code entry', () {
    test('error keys: wrong, used up and stopped codes read the same', () {
      expect(aaCodeErrorKey('invalid'), 'aa_code_err_invalid');
      expect(aaCodeErrorKey('weird'), 'aa_code_err_invalid');
      expect(aaCodeErrorKey(null), 'aa_code_err_invalid');
      expect(aaCodeErrorKey('rate_limited'), 'aa_code_err_rate_limited');
      expect(aaCodeErrorKey('forbidden'), 'aa_code_err_forbidden');
      expect(aaCodeErrorKey('offline'), 'aa_code_err_offline');
      expect(aaCodeErrorKey('signed_out'), 'aa_code_err_signed_out');
    });

    Future<int> tapVersion(
      WidgetTester tester, {
      required int times,
      Duration gap = const Duration(milliseconds: 200),
    }) async {
      var unlocked = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VersionTag(
                onUnlockTap: () => unlocked++,
                versionLoader: () async => 'v1.2.3',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('v1.2.3'), findsOneWidget);
      var now = DateTime(2026, 11, 13, 10);
      for (var i = 0; i < times; i++) {
        await withClock(Clock.fixed(now), () async {
          await tester.tap(find.text('v1.2.3'));
        });
        now = now.add(gap);
      }
      return unlocked;
    }

    testWidgets('seven quick taps ask for the code', (tester) async {
      expect(await tapVersion(tester, times: 7), 1);
    });

    testWidgets('six taps do not', (tester) async {
      expect(await tapVersion(tester, times: 6), 0);
    });

    testWidgets('slow taps never add up', (tester) async {
      expect(
        await tapVersion(tester, times: 14, gap: const Duration(seconds: 2)),
        0,
      );
    });

    testWidgets('without a callback the taps do nothing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: VersionTag(versionLoader: () async => null)),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byType(VersionTag));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
