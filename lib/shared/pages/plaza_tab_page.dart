import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/game_save/game_save_repository.dart';
import 'package:silversole/core/utils/game_camera_permission.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/providers/game_sole_forwarding.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';

/// Games tab: the H5 「粗哥廣場」 fills the whole tab instead of a card list.
///
/// The plaza links to every game (shops, the station's daily county, the
/// 踩進老街 lobby) inside the same web view, so the system back button walks
/// the web history first and only leaves the tab when there is nothing to go
/// back to. Sole telemetry is forwarded by [GameSoleForwarding], as in
/// [GameWebViewPage].
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

  /// The friends screen opened from the plaza is still on top: another tap
  /// on the building (or a page calling twice) does not stack a second one.
  bool _friendsOpen = false;
  double _progress = 0;
  bool _loaded = false;

  /// The phone's font-size setting, handed to the page so its large-text mode
  /// can follow it (the app itself caps its own text at [kMaxAppTextScale]).
  double _systemFontScale = 1.0;

  @override
  InAppWebViewController? get soleForwardTarget => _controller;

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
      accountId: user?.uuid,
      accountEmail: user?.email,
      systemFontScale: _systemFontScale,
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
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(friendsEnabledProvider)) {
      ref.listen(incomingRequestCountProvider, (_, _) => _publishAppInfo());
    }
    // Sign in / out while the tab is up: tell the page who it is now.
    ref.listen(authUserProvider, (_, _) => _publishAppInfo());

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller?.goBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(PlazaTabPage.url)),
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
                  _syncBack();
                },
                onUpdateVisitedHistory: (controller, url, isReload) =>
                    _syncBack(),
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
