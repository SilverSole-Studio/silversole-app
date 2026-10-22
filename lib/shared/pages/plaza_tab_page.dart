import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/constants.dart';
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
/// friends screen.
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
  double _progress = 0;
  bool _loaded = false;

  @override
  InAppWebViewController? get soleForwardTarget => _controller;

  Future<void> _syncBack() async {
    final can = await _controller?.canGoBack() ?? false;
    if (mounted && can != _canGoBack) setState(() => _canGoBack = can);
  }

  Map<String, Object> _appInfo() {
    final friends = ref.read(friendsEnabledProvider);
    return PlazaBridge.info(
      friends: friends,
      friendRequests: friends ? ref.read(incomingRequestCountProvider) : 0,
    );
  }

  /// Tells the page what it may show. Called after each load and whenever the
  /// values change while a page is up.
  Future<void> _publishAppInfo() async {
    final controller = _controller;
    if (!_loaded || controller == null) return;
    await controller.evaluateJavascript(
      source: PlazaBridge.publishScript(_appInfo()),
    );
  }

  Future<bool> _openFriends() async {
    if (!mounted || !ref.read(friendsEnabledProvider)) return false;
    // Don't wait for the screen to close: the page's call resolves now. Coming
    // back, re-read the lists so the red dot is current.
    context.push('/friends').then((_) {
      if (mounted) refreshFriendsData(ref);
    });
    return true;
  }

  void _registerBridge(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.appInfo,
      callback: (_) => _appInfo(),
    );
    controller.addJavaScriptHandler(
      handlerName: PlazaBridge.openFriends,
      callback: (_) => _openFriends(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(friendsEnabledProvider)) {
      ref.listen(incomingRequestCountProvider, (_, _) => _publishAppInfo());
    }

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
                initialSettings: InAppWebViewSettings(
                  isInspectable: kDebugMode,
                  mediaPlaybackRequiresUserGesture: false,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                  _registerBridge(controller);
                },
                // Camera mode in the games asks for the camera from the page.
                onPermissionRequest: (controller, request) async =>
                    PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    ),
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
