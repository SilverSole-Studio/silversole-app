import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/core/ble/sole_sample_script.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// Every raw sample from every sole, as the script a game page runs.
///
/// The foot side and the primary flag are read per sample rather than watched:
/// watching would rebuild this provider — and hand subscribers a new stream —
/// whenever the pairings change, while a lookup in a list of two is free.
final gameSoleScriptsProvider = Provider<Stream<String>>((ref) {
  return ref.watch(soleSampleBusProvider).stream.map((sample) {
    final key = sample.identityKey;
    final foot = ref
        .read(settingsProvider)
        .pairedDevicesList
        .firstWhereOrNull((d) => d.identityKey == key)
        ?.footSide;
    final primary = ref.read(primarySoleKeyProvider) == key;
    return soleSampleScript(sample.data, foot: foot, primary: primary);
  });
});

/// Streams the soles to the game in a web view — shared by every page that
/// hosts the H5 games.
///
/// Flutter → JS: each raw sample of each sole goes to `window.onSoleSample`,
/// or — on a page from before two feet — the primary sole's to
/// `window.onImuData` (see [soleSampleScript]). Nothing is sent until the
/// page has loaded ([soleForwardReady]), and nothing here calls setState:
/// samples arrive at 50 Hz per sole and must never rebuild the page.
mixin GameSoleForwarding<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  StreamSubscription<String>? _soleScripts;

  /// Set once the page has loaded and has had a chance to install its
  /// handlers; until then samples are dropped.
  bool soleForwardReady = false;

  /// The web view the samples go to; null until it has been created.
  InAppWebViewController? get soleForwardTarget;

  @override
  void initState() {
    super.initState();
    _soleScripts = ref.read(gameSoleScriptsProvider).listen((script) {
      if (!soleForwardReady) return;
      soleForwardTarget?.evaluateJavascript(source: script);
    });
  }

  @override
  void dispose() {
    _soleScripts?.cancel();
    super.dispose();
  }
}
