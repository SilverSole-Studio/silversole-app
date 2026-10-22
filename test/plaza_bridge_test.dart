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
      });
    });

    test('friends off: no building and never a count', () {
      expect(PlazaBridge.info(friends: false, friendRequests: 5), {
        'features': {'friends': false},
        'friendRequests': 0,
      });
    });
  });

  test('publishScript sets window.silversoleApp and fires the event', () {
    final info = PlazaBridge.info(friends: true, friendRequests: 1);
    final js = PlazaBridge.publishScript(info);

    final assigned = RegExp(r'^window\.silversoleApp=(\{.*?\});').firstMatch(js);
    expect(assigned, isNotNull);
    expect(jsonDecode(assigned!.group(1)!), info);
    expect(
      js,
      contains('new CustomEvent("silversoleapp",{detail:window.silversoleApp})'),
    );
  });

  test('without the Supabase define the demo repository is used', () {
    expect(Constants.friendsOnSupabase, isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(friendsRepositoryProvider), isA<FakeFriendsRepository>());
    // Tests run in debug mode, where friends are on for trying the screens.
    expect(container.read(friendsEnabledProvider), isTrue);
  });
}
