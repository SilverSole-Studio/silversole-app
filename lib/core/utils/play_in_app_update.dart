import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum InAppUpdateFlow { none, immediate, flexible }

/// Google Play in-app updates, backed by `InAppUpdateController.kt`.
///
/// Every call degrades to "not from Play" / [InAppUpdateFlow.none] off Android
/// or when the channel errors, so callers never need their own guard.
class PlayInAppUpdate {
  static const _channel = MethodChannel(
    'com.dongyutech.silversole/in_app_update',
  );

  /// Whether Google Play installed this copy. A Play install must update
  /// through Play only; a sideloaded APK (GitHub Releases, `flutter run`)
  /// cannot use Play updates at all.
  static Future<bool> isInstalledFromPlay() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isInstalledFromPlay') ?? false;
    } on PlatformException catch (e) {
      debugPrint('[InAppUpdate] installer check failed: ${e.code}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Starts Play's own update UI when the release's priority asks for it.
  static Future<InAppUpdateFlow> checkForUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return InAppUpdateFlow.none;
    }
    try {
      final result = await _channel.invokeMethod<String>('checkForUpdate');
      return switch (result) {
        'immediate' => InAppUpdateFlow.immediate,
        'flexible' => InAppUpdateFlow.flexible,
        _ => InAppUpdateFlow.none,
      };
    } on PlatformException catch (e) {
      debugPrint('[InAppUpdate] skipped: ${e.code} ${e.message}');
      return InAppUpdateFlow.none;
    } on MissingPluginException {
      return InAppUpdateFlow.none;
    }
  }
}

/// How this install should look for a newer version.
enum UpdateRoute { play, github, none }

/// Play installs update through Play only (Play policy). Sideloaded Android
/// copies use the GitHub release. Everything else, iOS included (TestFlight /
/// App Store), updates through its own store and is never offered an APK.
UpdateRoute updateRoute(
  TargetPlatform platform, {
  required bool installedFromPlay,
}) {
  if (platform != TargetPlatform.android) return UpdateRoute.none;
  return installedFromPlay ? UpdateRoute.play : UpdateRoute.github;
}
