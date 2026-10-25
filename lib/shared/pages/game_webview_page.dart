import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/utils/game_camera_permission.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/game_sole_forwarding.dart';

/// Full-screen in-app browser for a game URL (flutter_inappwebview v6).
///
/// Bridges the smart-sole telemetry to the web game:
///  • Flutter → JS: streams every sole's raw samples to the page — see
///    [GameSoleForwarding].
///  • JS → Flutter: the game reports its score via the `gameScore` handler
///    (`window.flutter_inappwebview.callHandler('gameScore', score)`).
///
/// A game's camera mode asks for the camera from the page; only that, and only
/// for the game site, is granted — see [answerGamePermission].
class GameWebViewPage extends ConsumerStatefulWidget {
  const GameWebViewPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  ConsumerState<GameWebViewPage> createState() => _GameWebViewPageState();
}

class _GameWebViewPageState extends ConsumerState<GameWebViewPage>
    with GameSoleForwarding {
  InAppWebViewController? _controller;
  double _progress = 0;

  @override
  InAppWebViewController? get soleForwardTarget => _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Compact header for a content page (default kToolbarHeight 56 felt tall).
        toolbarHeight: 48,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text(widget.title ?? '', style: context.textTheme.titleLarge),
        // Thin loading bar under the app bar while the page loads.
        bottom: _progress < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress, minHeight: 2),
              )
            : null,
      ),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialSettings: InAppWebViewSettings(
            isInspectable: kDebugMode,
            // Camera mode: the preview autoplays, inline rather than full screen on iOS.
            mediaPlaybackRequiresUserGesture: false,
            allowsInlineMediaPlayback: true,
            // The phone's font size must not enlarge the web text a second
            // time; the game has its own large-text mode.
            textZoom: 100,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            // Game → Flutter: the game reports its score here.
            controller.addJavaScriptHandler(
              handlerName: 'gameScore',
              callback: (args) {
                // TODO: persist the score (Supabase). For now just log it.
                debugPrint('[Game] gameScore: $args');
              },
            );
          },
          onPermissionRequest: (controller, request) =>
              answerGamePermission(request),
          onLoadStop: (controller, url) {
            // The page's sole handlers are installed → start forwarding.
            soleForwardReady = true;
          },
          onProgressChanged: (controller, progress) {
            if (!mounted) return;
            setState(() => _progress = progress / 100);
          },
        ),
      ),
    );
  }
}
