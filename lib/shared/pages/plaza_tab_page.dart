import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/active_aging/aa_repository.dart';
import 'package:silversole/core/game_save/game_save_repository.dart';
import 'package:silversole/core/mp/mp_session.dart';
import 'package:silversole/core/utils/game_camera_permission.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/daily_missions_bridge.dart';
import 'package:silversole/shared/providers/diamonds_provider.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/game_sole_forwarding.dart';
import 'package:silversole/shared/providers/home_tab_provider.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';

/// Games tab: the H5 「粗哥廣場」 fills the whole tab instead of a card list.
///
/// The plaza links to every game (shops, the station's daily county, the
/// 踩進老街 lobby) inside the same web view, so the system back button walks
/// the web history first and only leaves the tab when there is nothing to go
/// back to. Sole telemetry is forwarded by [GameSoleForwarding], as in
/// [GameWebViewPage].
///
/// The tab never shows the bottom bar ([HomePage] hides it for this tab). The
/// way out is the town menu's 「回 App」 ([PlazaBridge.exitPlaza]) or the back
/// button in the town ([PlazaBridge.backAction]); in a game the back button
/// returns to the town as before.
///
/// The plaza also talks to the app through [PlazaBridge]: it learns whether to
/// show the friends building (and its red dot), and asks the app to open the
/// friends screen. All of that, and the camera, is only for pages on the
/// games' own site ([PlazaBridge.isGameOrigin]); anything the plaza links out
/// to gets none of it.
class PlazaTabPage extends ConsumerStatefulWidget {
  const PlazaTabPage({super.key});

  static String get url => '${Constants.gameUrl}game/plaza/';

  @override
  ConsumerState<PlazaTabPage> createState() => _PlazaTabPageState();
}

class _PlazaTabPageState extends ConsumerState<PlazaTabPage>
    with GameSoleForwarding {
  InAppWebViewController? _controller;
  bool _canGoBack = false;

  /// The page showing is the town hub ([PlazaBridge.isHub]); the tab always
  /// opens on it.
  bool _onHub = true;

  /// The friends screen opened from the plaza is still on top: another tap
  /// on the building (or a page calling twice) does not stack a second one.
  bool _friendsOpen = false;
  double _progress = 0;
  bool _loaded = false;

  /// The phone's font-size setting, handed to the page so its large-text mode
  /// can follow it (the app itself caps its own text at [kMaxAppTextScale]).
  double _systemFontScale = 1.0;

  /// The page asked to open on the friends screen (`open=friends`); it is
  /// already on its way.
  late final String _initialUrl;

  @override
  InAppWebViewController? get soleForwardTarget => _controller;

  @override
  void initState() {
    super.initState();
    // A friends entry elsewhere in the app switched to this tab: the town
    // opens its friends screen on its own.
    _initialUrl = ref.read(plazaFriendsRequestProvider.notifier).consume()
        ? PlazaBridge.friendsUrl(PlazaTabPage.url)
        : PlazaTabPage.url;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Fresh diamond balance for the redeem shop (and a retry of today's
      // payout if an earlier try did not get through).
      ref.read(diamondsProvider.notifier).refresh();
    });
  }

  void _syncOnHub(Uri? url) {
    _onHub = PlazaBridge.isHub(url, Constants.gameUrl);
  }

  /// The system back button: back through the web history in a game (or on
  /// another site), otherwise out of the games tab to the home tab.
  void _onBack() {
    switch (PlazaBridge.backAction(onHub: _onHub, canGoBack: _canGoBack)) {
      case PlazaBackAction.webBack:
        _controller?.goBack();
      case PlazaBackAction.leaveTab:
        ref.read(homeTabProvider.notifier).goHome();
    }
  }

  Future<void> _syncBack() async {
    final can = await _controller?.canGoBack() ?? false;
    if (mounted && can != _canGoBack) setState(() => _canGoBack = can);
  }

  Map<String, Object> _appInfo() {
    final friends = ref.read(friendsEnabledProvider);
    final user = ref.read(authUserProvider);
    return PlazaBridge.info(
      friends: friends,
      friendRequests: friends ? ref.read(incomingRequestCountProvider) : 0,
      activeAging: ref.read(activeAgingEnabledProvider),
      accountId: user?.uuid,
      accountEmail: user?.email,
      systemFontScale: _systemFontScale,
      textSize: ref.read(settingsProvider).textSize,
      subscribed: ref.read(subscriptionActiveProvider),
      diamonds: ref.read(diamondsProvider).balance,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scale = SystemFontScale.of(context);
    if (scale == _systemFontScale) return;
    _systemFontScale = scale;
    // The first call happens before the web view exists: nothing to publish
    // yet, the initial user script reads the value.
    _publishAppInfo();
  }

  static const _infoScriptGroup = 'silversoleApp';

  /// Sets `window.silversoleApp` before any of the page's own scripts run, so
  /// the plaza can read it on its first frame.
  UserScript _infoUserScript() => UserScript(
    groupName: _infoScriptGroup,
    // allowedOriginRules is Android-only; the guard in the script itself keeps
    // the account off other origins on iOS.
    source: PlazaBridge.guardedPublishScript(
      _appInfo(),
      PlazaBridge.originOf(Constants.gameUrl),
    ),
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    allowedOriginRules: {PlazaBridge.originOf(Constants.gameUrl)},
  );

  /// Whether the page showing now is on the games' own site.
  Future<bool> _onGamePage(InAppWebViewController controller) async =>
      PlazaBridge.isGameOrigin(await controller.getUrl(), Constants.gameUrl);

  /// Tells the page what it may show when the values change: swaps the
  /// document-start script (for the next page) and publishes to the page that
  /// is up now. After each load it is published once more, which also covers
  /// pages that load before the controller exists.
  Future<void> _publishAppInfo() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    await controller.removeUserScriptsByGroupName(groupName: _infoScriptGroup);
    if (!mounted) return;
    await controller.addUserScript(userScript: _infoUserScript());
    if (!mounted || !_loaded) return;
    if (!await _onGamePage(controller) || !mounted) return;
    await controller.evaluateJavascript(
      source: PlazaBridge.publishScript(_appInfo()),
    );
  }

  /// A friends request that arrived while the town was already up: run the
  /// town's own opener. Before the first load finishes it stays pending and
  /// [onLoadStop] picks it up.
  Future<void> _runPendingFriends() async {
    final controller = _controller;
    if (controller == null || !_loaded || !mounted) return;
    if (!ref.read(plazaFriendsRequestProvider)) return;
    if (!await _onGamePage(controller) || !mounted) return;
    if (!ref.read(plazaFriendsRequestProvider.notifier).consume()) return;
    await controller.evaluateJavascript(source: PlazaBridge.openFriendsScript);
  }

  /// Fallback only: the page calls this when the town cannot reach its server.
  /// It must open the native screen and never send the user back to the town,
  /// or the two would bounce between each other.
  Future<bool> _openFriends() async {
    if (!mounted || !ref.read(friendsEnabledProvider)) return false;
    if (_friendsOpen) return true;
    _friendsOpen = true;
    // Don't wait for the screen to close: the page's call resolves now. Coming
    // back, re-read the lists so the red dot is current.
    context.push('/friends').whenComplete(() {
      _friendsOpen = false;
      if (mounted) refreshFriendsData(ref);
    });
    return true;
  }

  /// 「回 App」: back to the home tab, where the bar is.
  bool _exitPlaza() {
    if (!mounted) return false;
    ref.read(homeTabProvider.notifier).goHome();
    return true;
  }

  void _registerBridge(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.appInfo,
      callback: (_) async {
        if (!await _onGamePage(controller) || !mounted) return null;
        return _appInfo();
      },
    );
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.openFriends,
      callback: (_) async {
        if (!await _onGamePage(controller)) return false;
        return _openFriends();
      },
    );
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.exitPlaza,
      callback: (_) async {
        if (!await _onGamePage(controller)) return false;
        return _exitPlaza();
      },
    );
    // Cloud save: only the games' own site may read or write the account's save.
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.gameSaveLoad,
      callback: (_) async {
        if (!await _onGamePage(controller) || !mounted) return null;
        return ref.read(gameSaveRepositoryProvider).load();
      },
    );
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.gameSaveStore,
      callback: (args) async {
        if (!await _onGamePage(controller) || !mounted) return null;
        final a = PlazaBridge.storeArgs(args);
        if (a == null) return const {'ok': false, 'reason': 'bad_data'};
        return ref.read(gameSaveRepositoryProvider).store(a.rev, a.data);
      },
    );
    // Online play: the signed-in user's Supabase connection, same origin rule
    // as `openFriends`; null for any other page or when nobody is signed in.
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.mpSession,
      callback: (_) async {
        if (!await _onGamePage(controller) || !mounted) return null;
        return ref.read(mpSessionServiceProvider).session();
      },
    );
    // Today's daily missions, read only: same origin rule as the save.
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.dailyMissions,
      callback: (_) async {
        if (!await _onGamePage(controller) || !mounted) return null;
        return dailyMissionsAnswer(ref);
      },
    );
    // A finished round, for the daily missions: same origin rule as the save.
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.gameActivity,
      callback: (args) async {
        if (!await _onGamePage(controller) || !mounted) return null;
        return recordGameActivity(ref, args);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(friendsEnabledProvider)) {
      ref.listen(incomingRequestCountProvider, (_, _) => _publishAppInfo());
    }
    // Sign in / out while the tab is up: tell the page who it is now.
    ref.listen(authUserProvider, (_, _) => _publishAppInfo());
    ref.listen(plazaFriendsRequestProvider, (_, want) {
      if (want) _runPendingFriends();
    });
    ref.listen(subscriptionActiveProvider, (_, _) => _publishAppInfo());
    ref.listen(activeAgingEnabledProvider, (_, _) => _publishAppInfo());
    // The settings page's 文字大小 changed: the games follow it.
    ref.listen(
      settingsProvider.select((s) => s.textSize),
      (_, _) => _publishAppInfo(),
    );
    ref.listen(
      diamondsProvider.select((s) => s.balance),
      (_, _) => _publishAppInfo(),
    );

    return PopScope(
      // Always handled here: from the town the back button goes to the home
      // tab, it never closes the app from this tab.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                initialUserScripts: UnmodifiableListView([_infoUserScript()]),
                initialSettings: InAppWebViewSettings(
                  isInspectable: kDebugMode,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  // The phone's font size must not enlarge the web text a
                  // second time; the page enlarges itself (large-text mode).
                  textZoom: 100,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  _registerBridge(controller);
                },
                // Camera mode in the games asks for the camera from the page.
                // That is all a page gets, and only on the games' own site.
                onPermissionRequest: (controller, request) =>
                    answerGamePermission(request),
                onLoadStart: (controller, url) => _loaded = false,
                onLoadStop: (controller, url) {
                  soleForwardReady = true;
                  _loaded = true;
                  _publishAppInfo();
                  _runPendingFriends();
                  _syncBack();
                },
                onUpdateVisitedHistory: (controller, url, isReload) {
                  _syncBack();
                  _syncOnHub(url);
                },
                onProgressChanged: (controller, progress) {
                  if (!mounted) return;
                  setState(() => _progress = progress / 100);
                },
              ),
              if (_progress < 1.0)
                LinearProgressIndicator(value: _progress, minHeight: 2),
            ],
          ),
        ),
      ),
    );
  }
}
