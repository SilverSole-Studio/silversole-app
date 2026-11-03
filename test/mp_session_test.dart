import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/mp/mp_session.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  int sec(Duration d) => now.add(d).millisecondsSinceEpoch ~/ 1000;

  MpSessionService service({
    String url = 'https://x.supabase.co',
    String key = 'anon-key',
    ({String accessToken, int? expiresAt})? Function()? current,
    Future<({String accessToken, int? expiresAt})?> Function()? refresh,
  }) => MpSessionService(
    url: url,
    anonKey: key,
    current: current ?? () => null,
    refresh: refresh ?? () async => null,
    clock: () => now,
  );

  group('MpSessionService.session', () {
    test(
      'signed out answers null and never asks Supabase to refresh',
      () async {
        var refreshed = false;
        final s = service(
          current: () => null,
          refresh: () async {
            refreshed = true;
            return null;
          },
        );
        expect(await s.session(), isNull);
        expect(refreshed, isFalse);
      },
    );

    test('hands out url, key, token and the expiry in milliseconds', () async {
      final s = service(
        current: () =>
            (accessToken: 'jwt-1', expiresAt: sec(const Duration(minutes: 50))),
      );
      expect(await s.session(), {
        'url': 'https://x.supabase.co',
        'anonKey': 'anon-key',
        'accessToken': 'jwt-1',
        'expiresAt': now
            .add(const Duration(minutes: 50))
            .millisecondsSinceEpoch,
      });
    });

    test('a token about to run out is renewed first', () async {
      var refreshed = 0;
      final s = service(
        current: () =>
            (accessToken: 'old', expiresAt: sec(const Duration(seconds: 30))),
        refresh: () async {
          refreshed++;
          return (accessToken: 'new', expiresAt: sec(const Duration(hours: 1)));
        },
      );
      final r = await s.session();
      expect(refreshed, 1);
      expect(r!['accessToken'], 'new');
    });

    test('a healthy token is not renewed', () async {
      var refreshed = false;
      final s = service(
        current: () =>
            (accessToken: 'ok', expiresAt: sec(const Duration(minutes: 10))),
        refresh: () async {
          refreshed = true;
          return null;
        },
      );
      expect((await s.session())!['accessToken'], 'ok');
      expect(refreshed, isFalse);
    });

    test(
      'offline: a failed renewal still hands out a token that is not out yet',
      () async {
        final s = service(
          current: () => (
            accessToken: 'still-good',
            expiresAt: sec(const Duration(seconds: 45)),
          ),
          refresh: () async => throw Exception('no network'),
        );
        expect((await s.session())!['accessToken'], 'still-good');
      },
    );

    test(
      'offline with an expired token answers null, not a dead token',
      () async {
        final s = service(
          current: () => (
            accessToken: 'dead',
            expiresAt: sec(const Duration(seconds: -5)),
          ),
          refresh: () async => throw Exception('no network'),
        );
        expect(await s.session(), isNull);
        final s2 = service(
          current: () => (
            accessToken: 'dead',
            expiresAt: sec(const Duration(seconds: -5)),
          ),
          refresh: () async => null,
        );
        expect(await s2.session(), isNull);
      },
    );

    test('a token with no readable expiry is good for one minute', () async {
      final s = service(
        current: () => (accessToken: 'jwt', expiresAt: null),
        refresh: () async => null,
      );
      final r = await s.session();
      expect(r!['expiresAt'], now.millisecondsSinceEpoch + 60000);
    });

    test('no backend configured answers null', () async {
      final tokens = (
        accessToken: 'jwt',
        expiresAt: sec(const Duration(hours: 1)),
      );
      expect(await service(url: '', current: () => tokens).session(), isNull);
      expect(await service(key: '', current: () => tokens).session(), isNull);
    });

    test('an empty token is not a session', () async {
      final s = service(
        current: () =>
            (accessToken: '', expiresAt: sec(const Duration(hours: 1))),
      );
      expect(await s.session(), isNull);
    });
  });

  group('the handler is only for the games\' own site', () {
    // plaza_tab_page.dart and game_webview_page.dart answer mpSession with the
    // same PlazaBridge.isGameOrigin check as openFriends.
    const gameUrl = 'https://h5.silversole.dongyu.company/';

    test('the handler name', () {
      expect(PlazaBridge.mpSession, 'mpSession');
    });

    test('the games\' site passes, anything else does not', () {
      expect(
        PlazaBridge.isGameOrigin(
          Uri.parse('${gameUrl}game/parlor/xiangqi/'),
          gameUrl,
        ),
        isTrue,
      );
      for (final other in [
        'https://evil.example/game/parlor/xiangqi/',
        'https://h5.silversole.dongyu.company.evil.example/',
        'http://h5.silversole.dongyu.company/',
        'https://h5.silversole.dongyu.company:8443/',
        'file:///android_asset/x.html',
        'javascript:alert(1)',
      ]) {
        expect(
          PlazaBridge.isGameOrigin(Uri.parse(other), gameUrl),
          isFalse,
          reason: other,
        );
      }
      expect(PlazaBridge.isGameOrigin(null, gameUrl), isFalse);
    });
  });
}
