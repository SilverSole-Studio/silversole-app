import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/diamonds/diamond_repository.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';

class _Auth extends AuthUserNotifier {
  @override
  UserData? build() => const UserData(email: 'a@b.c', uuid: 'u1');
}

class _OneSole extends ConnectedSolesNotifier {
  @override
  Map<String, ConnectedSole> build() => const {
    'L': ConnectedSole(
      device: BlePairedDevice(remoteId: 'l', name: 'SilverSole', deviceId: 'L'),
      dfuSupported: true,
    ),
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<String>> run(
    WidgetTester tester, {
    required bool soleConnected,
    required List<Map<String, Object>> reports,
  }) async {
    final calls = <String>[];
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith(_Auth.new),
          if (soleConnected) connectedSolesProvider.overrideWith(_OneSole.new),
          diamondRepositoryProvider.overrideWithValue(
            DiamondRepository((fn, params) async {
              calls.add(params.isEmpty ? fn : '$fn ${params['p_minutes']}');
              return {
                'ok': true,
                'earned': fn == 'diamond_earn_exercise' ? 10 : 0,
                'balance': 10,
                'month': 10,
                'cap': 300,
                'subscribed': true,
              };
            }, () => true),
          ),
        ],
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final report in reports) {
      await tester.runAsync(() async {
        final res = await recordGameActivity(ref, [report]);
        expect(res, {'ok': true});
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    }
    return calls;
  }

  testWidgets('rounds with a sole connected add up and pay at 15 minutes', (
    tester,
  ) async {
    final calls = await run(
      tester,
      soleConnected: true,
      reports: [
        {'slug': 'fish', 'seconds': 500},
        {'slug': 'farm', 'seconds': 400},
      ],
    );
    expect(calls, ['diamond_balance', 'diamond_earn_exercise 15']);
  });

  testWidgets('rounds without a sole count for missions but not diamonds', (
    tester,
  ) async {
    final calls = await run(
      tester,
      soleConnected: false,
      reports: [
        {'slug': 'fish', 'seconds': 3000},
      ],
    );
    expect(calls, isEmpty);
  });

  testWidgets('a page that reports the same round twice counts it once', (
    tester,
  ) async {
    final calls = await run(
      tester,
      soleConnected: true,
      reports: [
        {'slug': 'fish', 'seconds': 600},
        {'slug': 'fish', 'seconds': 600},
      ],
    );
    // 10 minutes counted once; had it counted twice it would have asked.
    expect(calls, ['diamond_balance']);
  });
}
