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

/// 「打開小鎮的好友頁」的待辦：好友入口（遊戲分頁的信箱卡等）把它設成 true 並切到
/// 遊戲分頁，[PlazaTabPage] 看到後消費掉。小鎮還沒載入就改帶 `open=friends`
/// 進場，已載入就執行 `window.WorldOpenFriends()`。
/// 不 autoDispose：設定時小鎮分頁還沒建起來，沒人在聽。
class PlazaFriendsRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  /// 取走待辦；回傳取走前是不是有待辦。
  bool consume() {
    final had = state;
    if (had) state = false;
    return had;
  }
}

final plazaFriendsRequestProvider = NotifierProvider<PlazaFriendsRequest, bool>(
  PlazaFriendsRequest.new,
);

/// 好友入口統一走這裡：切到遊戲分頁（小鎮）並要求打開小鎮的好友頁。
/// 原生好友頁只剩小鎮連不上時的退路（`openFriends` handler）。
void openTownFriends(WidgetRef ref) {
  ref.read(plazaFriendsRequestProvider.notifier).request();
  ref.read(homeTabProvider.notifier).select(HomeTabNotifier.games);
}
