import 'dart:collection';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/active_aging/aa_bridge.dart';
import 'package:silversole/core/active_aging/aa_repository.dart';
import 'package:silversole/core/utils/game_camera_permission.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/plaza_bridge.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// 銀足樂齡 mode: the H5 pages under `game/aa/` in a full-screen web view.
/// Opened only from the hidden 「銀足樂齡」 row on the 「我的」 page, which shows
/// for accounts with the role ([activeAgingEnabledProvider]).
///
/// What the page gets, and only while it is on [AaBridge.isAaPage]:
///  - `window.silversoleApp.features.activeAging === true` (and `appInfo`);
///  - `callHandler('aaRpc', {fn, args})` ([AaRepository.handle]);
///  - the camera, for the games' own site ([answerGamePermission]).
/// A main-frame navigation to anywhere else is cancelled, so the camera and the
/// handler never reach another page. No sole data, game save, diamonds or
/// friends go through here: the elders' sessions stay apart from game accounts.
class ActiveAgingPage extends ConsumerStatefulWidget {
  const ActiveAgingPage({super.key});

  @override
  ConsumerState<ActiveAgingPage> createState() => _ActiveAgingPageState();
}

class _ActiveAgingPageState extends ConsumerState<ActiveAgingPage> {
  double _progress = 0;

  Map<String, Object> _appInfo() => PlazaBridge.info(
    friends: false,
    friendRequests: 0,
    activeAging: ref.read(activeAgingEnabledProvider),
    textSize: ref.read(settingsProvider).textSize,
  );

  Future<bool> _onAaPage(InAppWebViewController controller) async =>
      mounted &&
      ref.read(activeAgingEnabledProvider) &&
      AaBridge.isAaPage(await controller.getUrl(), Constants.gameUrl);

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(aaActiveProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text('aa_title'.tr(), style: context.textTheme.titleLarge),
        bottom: _progress < 1.0 && active.value == true
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress, minHeight: 2),
              )
            : null,
      ),
      body: SafeArea(
        child: switch (active) {
          AsyncData(value: true) => _web(),
          AsyncData() || AsyncError() => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'aa_not_available'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge,
              ),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _web() {
    final origin = PlazaBridge.originOf(Constants.gameUrl);
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(AaBridge.pageUrl(Constants.gameUrl)),
      ),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: PlazaBridge.guardedPublishScript(_appInfo(), origin),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          allowedOriginRules: {origin},
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        isInspectable: kDebugMode,
        // The camera preview autoplays, inline rather than full screen on iOS.
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        textZoom: 100,
        useShouldOverrideUrlLoading: true,
      ),
      shouldOverrideUrlLoading: (controller, action) async {
        if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
        return AaBridge.isAaPage(
              action.request.url?.uriValue,
              Constants.gameUrl,
            )
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: PlazaBridge.appInfo,
          callback: (_) async {
            if (!await _onAaPage(controller)) return null;
            return _appInfo();
          },
        );
        controller.addJavaScriptHandler(
          handlerName: AaBridge.handlerName,
          callback: (args) async {
            if (!await _onAaPage(controller)) {
              return AaBridge.refusal('forbidden');
            }
            return ref.read(aaRepositoryProvider).handle(args);
          },
        );
        // The page's own 「回 App」 / back.
        controller.addJavaScriptHandler(
          handlerName: PlazaBridge.exitPlaza,
          callback: (_) async {
            if (!await _onAaPage(controller) || !mounted) return false;
            Navigator.of(context).maybePop();
            return true;
          },
        );
      },
      // Camera only, only the games' site; the load guard above keeps the page
      // on /game/aa/.
      onPermissionRequest: (controller, request) =>
          answerGamePermission(request),
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        setState(() => _progress = progress / 100);
      },
    );
  }
}
