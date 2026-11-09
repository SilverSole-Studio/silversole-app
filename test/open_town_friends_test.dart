import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/providers/home_tab_provider.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';

void main() {
  test('friendsUrl adds open=friends and keeps other parameters', () {
    expect(
      PlazaBridge.friendsUrl('https://x.example/game/plaza/'),
      'https://x.example/game/plaza/?open=friends',
    );
    expect(
      PlazaBridge.friendsUrl('https://x.example/game/plaza/?a=1&open=no'),
      'https://x.example/game/plaza/?a=1&open=friends',
    );
  });

  test('the injected script is the fixed town opener', () {
    expect(
      PlazaBridge.openFriendsScript,
      'window.WorldOpenFriends && window.WorldOpenFriends()',
    );
  });

  testWidgets(
    'a friends entry switches to the games tab and asks for friends',
    (tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SizedBox)),
      );
      container.listen(homeTabProvider, (_, _) {});

      expect(container.read(plazaFriendsRequestProvider), isFalse);
      openTownFriends(captured);
      expect(container.read(homeTabProvider), HomeTabNotifier.games);
      expect(container.read(plazaFriendsRequestProvider), isTrue);

      // The town takes the request once; a second take finds nothing.
      expect(
        container.read(plazaFriendsRequestProvider.notifier).consume(),
        isTrue,
      );
      expect(
        container.read(plazaFriendsRequestProvider.notifier).consume(),
        isFalse,
      );
    },
  );
}
