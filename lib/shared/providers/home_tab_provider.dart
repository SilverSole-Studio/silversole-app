import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-bar tab [HomePage] shows. Kept in a provider (not in the
/// page's own state) so the games tab can send the user back to the home tab:
/// that tab hides the bar, so the town menu's 「回 App」 and the back button in
/// the town leave through [HomeTabNotifier.goHome].
class HomeTabNotifier extends Notifier<int> {
  static const int home = 0;
  static const int games = 2;

  @override
  int build() => home;

  void select(int index) {
    if (state != index) state = index;
  }

  void goHome() => select(home);
}

/// Auto-disposed with the home page, so the next visit starts on the home tab.
final homeTabProvider = NotifierProvider.autoDispose<HomeTabNotifier, int>(
  HomeTabNotifier.new,
);
