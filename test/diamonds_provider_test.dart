import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/diamonds/diamond_repository.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/diamonds_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';

class _SignedIn extends AuthUserNotifier {
  _SignedIn(this.user);
  final UserData? user;
  @override
  UserData? build() => user;
}

class _Settings extends SettingsNotifier {
  _Settings(this.devMode);
  final bool devMode;
  @override
  AppSettings build() => AppSettings(firmwareDevMode: devMode);
}

/// A server that answers from a script and remembers the calls.
class _FakeServer {
  _FakeServer({bool subscribed = true}) : _subscribed = subscribed;

  bool _subscribed;
  int balance = 0;
  int month = 0;
  bool paidToday = false;
  final List<String> calls = [];

  /// Answers with these before behaving normally: a reason, or 'throw'.
  final List<String> failures = [];

  void setSubscribed(bool v) => _subscribed = v;

  Map<String, Object?> _numbers() => {
    'balance': balance,
    'month': month,
    'cap': 300,
    'subscribed': _subscribed,
    'activeUntil': _subscribed ? '2026-12-31' : null,
  };

  Future<dynamic> rpc(String fn, Map<String, dynamic> params) async {
    calls.add(params.isEmpty ? fn : '$fn ${params['p_minutes']}');
    if (failures.isNotEmpty) {
      final f = failures.removeAt(0);
      if (f == 'throw') throw Exception('offline');
      return {'ok': false, 'reason': f};
    }
    if (fn == 'diamond_balance') return {'ok': true, ..._numbers()};
    if (!_subscribed) {
      return {'ok': false, 'reason': 'not_subscribed', ..._numbers()};
    }
    if (paidToday) {
      return {'ok': false, 'reason': 'already_today', ..._numbers()};
    }
    paidToday = true;
    balance += 10;
    month += 10;
    return {'ok': true, 'earned': 10, ..._numbers()};
  }
}

void main() {
  final noon = DateTime(2026, 11, 3, 12);
  const user = UserData(email: 'a@b.c', uuid: 'u1');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer make(
    _FakeServer server, {
    UserData? who = user,
    bool devMode = false,
  }) {
    final c = ProviderContainer(
      overrides: [
        authUserProvider.overrideWith(() => _SignedIn(who)),
        settingsProvider.overrideWith(() => _Settings(devMode)),
        diamondRepositoryProvider.overrideWithValue(
          DiamondRepository(server.rpc, () => who != null),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('opening asks the server for the balance', () async {
    await withClock(Clock.fixed(noon), () async {
      final server = _FakeServer()..balance = 70;
      final c = make(server);
      c.read(diamondsProvider);
      await settle();
      expect(server.calls, ['diamond_balance']);
      expect(c.read(diamondsProvider).balance?.balance, 70);
      expect(c.read(serverSubscribedProvider), isTrue);
    });
  });

  test('signed out: nothing is asked and nothing counts', () async {
    await withClock(Clock.fixed(noon), () async {
      final server = _FakeServer();
      final c = make(server, who: null);
      c.read(diamondsProvider);
      await c.read(diamondsProvider.notifier).addExerciseSeconds(3600);
      await settle();
      expect(server.calls, isEmpty);
      expect(c.read(diamondsProvider).balance, isNull);
    });
  });

  test('14 minutes asks for nothing; the 15th minute asks once', () async {
    await withClock(Clock.fixed(noon), () async {
      final server = _FakeServer();
      final c = make(server);
      final n = c.read(diamondsProvider.notifier);
      await n.refresh();
      server.calls.clear();
      await n.addExerciseSeconds(14 * 60 + 59);
      expect(server.calls, isEmpty);
      await n.addExerciseSeconds(1);
      expect(server.calls, ['diamond_earn_exercise 15']);
      expect(c.read(diamondsProvider).balance?.balance, 10);
      expect(c.read(diamondsProvider).balance?.month, 10);
      // More play the same day: no second ask.
      await n.addExerciseSeconds(1800);
      expect(server.calls, ['diamond_earn_exercise 15']);
    });
  });

  test('a failed ask is retried on the next report, then stops', () async {
    await withClock(Clock.fixed(noon), () async {
      final server = _FakeServer();
      final c = make(server);
      final n = c.read(diamondsProvider.notifier);
      await n.refresh();
      server.calls.clear();
      server.failures.add('throw');
      await n.addExerciseSeconds(1200);
      expect(c.read(diamondsProvider).exercise?.settled, isFalse);
      await n.addExerciseSeconds(60);
      expect(c.read(diamondsProvider).exercise?.settled, isTrue);
      expect(server.calls, [
        'diamond_earn_exercise 20',
        'diamond_earn_exercise 21',
      ]);
      await n.addExerciseSeconds(60);
      expect(server.calls.length, 2);
    });
  });

  test(
    'rate limited is retried later; already_today is final for the day',
    () async {
      await withClock(Clock.fixed(noon), () async {
        final server = _FakeServer()..paidToday = true;
        final c = make(server);
        final n = c.read(diamondsProvider.notifier);
        await n.refresh();
        server.failures.add('rate_limited');
        await n.addExerciseSeconds(1200);
        expect(c.read(diamondsProvider).exercise?.settled, isFalse);
        await n.addExerciseSeconds(10);
        expect(c.read(diamondsProvider).exercise?.settled, isTrue);
        expect(c.read(diamondsProvider).balance?.balance, 0);
      });
    },
  );

  test('not subscribed: the exercise is counted but never asked for', () async {
    await withClock(Clock.fixed(noon), () async {
      final server = _FakeServer(subscribed: false);
      final c = make(server);
      final n = c.read(diamondsProvider.notifier);
      await n.refresh();
      server.calls.clear();
      await n.addExerciseSeconds(3600);
      expect(server.calls, isEmpty);
      expect(c.read(diamondsProvider).exercise?.minutes, 60);
      expect(c.read(serverSubscribedProvider), isFalse);
      // The subscription gets opened; the next refresh pays out.
      server.setSubscribed(true);
      await n.refresh();
      expect(server.calls, ['diamond_balance', 'diamond_earn_exercise 60']);
      expect(c.read(diamondsProvider).balance?.balance, 10);
    });
  });

  test('the day survives a restart: minutes and "already paid"', () async {
    await withClock(Clock.fixed(noon), () async {
      final server = _FakeServer();
      final first = make(server);
      await first.read(diamondsProvider.notifier).refresh();
      await first.read(diamondsProvider.notifier).addExerciseSeconds(1200);
      expect(server.balance, 10);

      server.calls.clear();
      final second = make(server);
      second.read(diamondsProvider);
      await settle();
      expect(second.read(diamondsProvider).exercise?.minutes, 20);
      expect(second.read(diamondsProvider).exercise?.settled, isTrue);
      expect(server.calls, ['diamond_balance']);
    });
  });

  group('subscriptionActiveProvider', () {
    test('the server decides', () async {
      await withClock(Clock.fixed(noon), () async {
        final on = make(_FakeServer());
        on.read(diamondsProvider);
        await settle();
        expect(on.read(subscriptionActiveProvider), isTrue);

        final off = make(_FakeServer(subscribed: false));
        off.read(diamondsProvider);
        await settle();
        expect(off.read(subscriptionActiveProvider), isFalse);
      });
    });

    test('offline or signed out is not subscribed', () async {
      await withClock(Clock.fixed(noon), () async {
        final server = _FakeServer()..failures.add('throw');
        final c = make(server);
        c.read(diamondsProvider);
        await settle();
        expect(c.read(subscriptionActiveProvider), isFalse);
        final out = make(_FakeServer(), who: null);
        expect(out.read(subscriptionActiveProvider), isFalse);
      });
    });

    test('the test switch pretends in debug builds / developer mode', () async {
      await withClock(Clock.fixed(noon), () async {
        final c = make(_FakeServer(subscribed: false), devMode: true);
        c.read(diamondsProvider);
        await c.read(fakeSubscriptionProvider.notifier).setFake(true);
        await settle();
        expect(c.read(subscriptionActiveProvider), isTrue);
        await c.read(fakeSubscriptionProvider.notifier).setFake(false);
        expect(c.read(subscriptionActiveProvider), isFalse);
      });
    });
  });
}
