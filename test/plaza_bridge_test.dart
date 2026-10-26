import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';

void main() {
  group('PlazaBridge.info', () {
    test('friends on: the building shows with its red-dot count', () {
      expect(PlazaBridge.info(friends: true, friendRequests: 2), {
        'features': {'friends': true},
        'friendRequests': 2,
        'systemFontScale': 1.0,
      });
    });

    test('passes on the phone font scale so the page can pick large text', () {
      expect(
        PlazaBridge.info(
          friends: false,
          friendRequests: 0,
          systemFontScale: 1.5,
        )['systemFontScale'],
        1.5,
      );
    });

    test('friends off: no building and never a count', () {
      expect(PlazaBridge.info(friends: false, friendRequests: 5), {
        'features': {'friends': false},
        'friendRequests': 0,
        'systemFontScale': 1.0,
      });
    });
  });

  group('PlazaBridge.info account', () {
    test('signed in: id and the email prefix as username', () {
      final info = PlazaBridge.info(
        friends: false,
        friendRequests: 0,
        accountId: 'u-1',
        accountEmail: 'ricky951102@gmail.com',
      );
      expect(info['account'], {'id': 'u-1', 'username': 'ricky951102'});
    });

    test('signed out: no account key', () {
      expect(
        PlazaBridge.info(
          friends: false,
          friendRequests: 0,
        ).containsKey('account'),
        isFalse,
      );
      expect(
        PlazaBridge.info(
          friends: false,
          friendRequests: 0,
          accountId: '',
        ).containsKey('account'),
        isFalse,
      );
    });

    test('no email: empty username', () {
      expect(PlazaBridge.usernameOf(null), '');
      expect(PlazaBridge.usernameOf(''), '');
      expect(PlazaBridge.usernameOf('abc'), 'abc');
    });
  });

  test('publishScript sets window.silversoleApp and fires the event', () {
    final info = PlazaBridge.info(friends: true, friendRequests: 1);
    final js = PlazaBridge.publishScript(info);

    final assigned = RegExp(
      r'^window\.silversoleApp=(\{.*?\});',
    ).firstMatch(js);
    expect(assigned, isNotNull);
    expect(jsonDecode(assigned!.group(1)!), info);
    expect(
      js,
      contains(
        'new CustomEvent("silversoleapp",{detail:window.silversoleApp})',
      ),
    );
  });

  group('PlazaBridge.isGameOrigin', () {
    const game = 'https://h5.silversole.dongyu.company/';

    test('pages on the games site are trusted, whatever the path', () {
      for (final url in [
        'https://h5.silversole.dongyu.company/game/plaza/',
        'https://h5.silversole.dongyu.company/game/laojie/?x=1#y',
        'https://h5.silversole.dongyu.company:443/',
        'https://H5.SilverSole.dongyu.company/',
      ]) {
        expect(
          PlazaBridge.isGameOrigin(Uri.parse(url), game),
          isTrue,
          reason: url,
        );
      }
    });

    test('anything else is not', () {
      for (final url in [
        'http://h5.silversole.dongyu.company/game/plaza/', // not https
        'https://h5.silversole.dongyu.company:8443/',
        'https://evil.example/game/plaza/',
        'https://h5.silversole.dongyu.company.evil.example/',
        'https://evil.example/?u=https://h5.silversole.dongyu.company/',
        'about:blank',
        'data:text/html,hi',
        'file:///android_asset/index.html',
        'javascript:alert(1)',
      ]) {
        expect(
          PlazaBridge.isGameOrigin(Uri.parse(url), game),
          isFalse,
          reason: url,
        );
      }
      expect(PlazaBridge.isGameOrigin(null, game), isFalse);
    });

    test('a local games server is matched on its port', () {
      const local = 'http://localhost:8080/';
      expect(
        PlazaBridge.isGameOrigin(
          Uri.parse('http://localhost:8080/game/plaza/'),
          local,
        ),
        isTrue,
      );
      expect(
        PlazaBridge.isGameOrigin(
          Uri.parse('http://localhost:9090/game/plaza/'),
          local,
        ),
        isFalse,
      );
      expect(PlazaBridge.originOf(local), 'http://localhost:8080');
      expect(
        PlazaBridge.originOf(game),
        'https://h5.silversole.dongyu.company',
      );
    });
  });

  test('without the Supabase define the demo repository is used', () {
    expect(Constants.friendsOnSupabase, isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(friendsRepositoryProvider),
      isA<FakeFriendsRepository>(),
    );
    // Tests run in debug mode, where friends are on for trying the screens.
    expect(container.read(friendsEnabledProvider), isTrue);
  });

  test('the document-start script only publishes on the game origin', () {
    final info = <String, Object>{'accountId': 'u-1', 'accountEmail': 'a@b.c'};
    final js = PlazaBridge.guardedPublishScript(
      info,
      'https://games.example.com',
    );
    expect(
      js,
      startsWith('if(location.origin==="https://games.example.com"){'),
    );
    expect(js, endsWith('}'));
    expect(js, contains(PlazaBridge.publishScript(info)));
  });

  test('a quote in the origin cannot break out of the guard', () {
    final js = PlazaBridge.guardedPublishScript(
      const {},
      'https://x.com"};alert(1);//',
    );
    // jsonEncode escapes the quote, so the whole origin stays one string literal.
    expect(
      js,
      startsWith(r'if(location.origin==="https://x.com\"};alert(1);//"){'),
    );
  });
}
