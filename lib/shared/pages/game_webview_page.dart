import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/utils/game_camera_permission.dart';
import 'package:silversole/core/utils/game_path.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/game_activity_provider.dart';
import 'package:silversole/shared/providers/game_sole_forwarding.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';

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
  const GameWebViewPage({
    super.key,
    required this.url,
    this.title,
    this.closeOnLeavePath = false,
  });

  final String url;
  final String? title;

  /// Close the page instead of loading a page of this site at a different
  /// path than [url] (see [staysOnGamePath]). Set for a game opened from a
  /// daily mission, where the game's own "back to the town" would otherwise
  /// load the whole town inside the mission's page; off for every other use.
  final bool closeOnLeavePath;

  @override
  ConsumerState<GameWebViewPage> createState() => _GameWebViewPageState();
}

class _GameWebViewPageState extends ConsumerState<GameWebViewPage>
    with GameSoleForwarding {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _closing = false;

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
            useShouldOverrideUrlLoading: widget.closeOnLeavePath,
          ),
          shouldOverrideUrlLoading: widget.closeOnLeavePath
              ? (controller, action) async {
                  // Only the page itself: frames and sub-requests are left alone.
                  if (!action.isForMainFrame) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  if (staysOnGamePath(
                    Uri.tryParse(widget.url),
                    action.request.url?.uriValue,
                  )) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  if (!_closing && mounted) {
                    _closing = true;
                    Navigator.of(context).maybePop();
                  }
                  return NavigationActionPolicy.CANCEL;
                }
              : null,
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
            // A finished round, for the daily missions (a mission opens its
            // game in this page): only the games' own site may report one.
            controller.addJavaScriptHandler(
              handlerName: PlazaBridge.gameActivity,
              callback: (args) async {
                final onGameSite = PlazaBridge.isGameOrigin(
                  await controller.getUrl(),
                  Constants.gameUrl,
                );
                if (!onGameSite || !mounted) return null;
                return recordGameActivity(ref, args);
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
