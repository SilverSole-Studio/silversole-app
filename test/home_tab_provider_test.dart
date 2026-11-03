import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/providers/home_tab_provider.dart';

void main() {
  test('starts on the home tab; the games tab can send the user back', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(homeTabProvider, (_, _) {});

    expect(container.read(homeTabProvider), HomeTabNotifier.home);
    container.read(homeTabProvider.notifier).select(HomeTabNotifier.games);
    expect(container.read(homeTabProvider), HomeTabNotifier.games);

    // 「回 App」 / back in the town.
    container.read(homeTabProvider.notifier).goHome();
    expect(container.read(homeTabProvider), HomeTabNotifier.home);
  });
}
