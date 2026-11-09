import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// Whether this is a debug build. A provider only so tests can pretend to be a
/// release build (`kDebugMode` is a compile-time constant).
final debugBuildProvider = Provider<bool>((ref) => kDebugMode);

/// Engineering-only controls (raw gait recording, the "pretend subscribed"
/// switch) show only in a debug build or with developer mode on (seven taps on
/// the firmware title). A normal release build never shows them.
final devToolsVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(debugBuildProvider) ||
      ref.watch(settingsProvider.select((s) => s.firmwareDevMode)),
);
