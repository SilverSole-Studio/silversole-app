import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/utils/game_camera_permission.dart';
import 'package:silversole/shared/providers/game_sole_forwarding.dart';

/// Games tab: the H5 「粗哥廣場」 fills the whole tab instead of a card list.
///
/// The plaza links to every game (shops, the station's daily county, the
/// 踩進老街 lobby) inside the same web view, so the system back button walks
/// the web history first and only leaves the tab when there is nothing to go
/// back to. Sole telemetry is forwarded by [GameSoleForwarding], as in
/// [GameWebViewPage].
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

  @override
  InAppWebViewController? get soleForwardTarget => _controller;

  Future<void> _syncBack() async {
    final can = await _controller?.canGoBack() ?? false;
    if (mounted && can != _canGoBack) setState(() => _canGoBack = can);
  }

  @override
  Widget build(BuildContext context) {
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
                  allowsInlineMediaPlayback: true,
                ),
                onWebViewCreated: (controller) => _controller = controller,
                // Camera mode in the games asks for the camera from the page.
                onPermissionRequest: (controller, request) =>
                    answerGamePermission(request),
                onLoadStop: (controller, url) {
                  soleForwardReady = true;
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
