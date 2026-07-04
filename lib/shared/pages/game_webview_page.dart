import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';

/// Full-screen in-app browser for a game URL (flutter_inappwebview v6).
///
/// Bridges the smart-sole telemetry to the web game:
///  • Flutter → JS: streams each live IMU sample to `window.onImuData(<json>)`.
///  • JS → Flutter: the game reports its score via the `gameScore` handler
///    (`window.flutter_inappwebview.callHandler('gameScore', score)`).
class GameWebViewPage extends ConsumerStatefulWidget {
  const GameWebViewPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  ConsumerState<GameWebViewPage> createState() => _GameWebViewPageState();
}

class _GameWebViewPageState extends ConsumerState<GameWebViewPage> {
  InAppWebViewController? _controller;
  bool _ready = false; // page loaded → window.onImuData should be installed
  double _progress = 0;

  /// Push the latest IMU sample to the game. Guarded with `&&` so it no-ops
  /// until the page defines window.onImuData. No setState — pushing must never
  /// rebuild this widget (it fires at BLE rate).
  void _pushImu() {
    if (!_ready) return;
    final imu = ref.read(telemetryViewProvider).recentImu;
    if (imu.isEmpty) return;
    final json = jsonEncode(imu.last.toJson());
    _controller?.evaluateJavascript(
      source: 'window.onImuData && window.onImuData($json);',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Forward every new live sample to the game (the game itself throttles by
    // reading the latest value on its own update() loop).
    ref.listen(telemetryViewProvider, (_, _) => _pushImu());

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
          initialSettings: InAppWebViewSettings(isInspectable: kDebugMode),
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
          onLoadStop: (controller, url) {
            _ready = true;
            _pushImu(); // send an initial sample once the page is ready
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
