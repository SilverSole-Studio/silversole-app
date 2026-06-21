import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Full-screen in-app browser for a game URL (flutter_inappwebview v6).
///
/// Currently every game points at a placeholder URL (example.com) until the
/// real game web builds exist.
class GameWebViewPage extends StatefulWidget {
  const GameWebViewPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<GameWebViewPage> createState() => _GameWebViewPageState();
}

class _GameWebViewPageState extends State<GameWebViewPage> {
  double _progress = 0;

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
          initialSettings: InAppWebViewSettings(isInspectable: kDebugMode),
          onProgressChanged: (controller, progress) {
            if (!mounted) return;
            setState(() => _progress = progress / 100);
          },
        ),
      ),
    );
  }
}
