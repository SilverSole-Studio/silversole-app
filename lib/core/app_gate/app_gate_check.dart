import 'dart:async';

import 'package:silversole/core/app_gate/version_compare.dart';

/// Calls the `app_min_version` RPC. Returns its JSON map (may be empty).
typedef MinVersionFetcher = Future<Map<String, dynamic>?> Function(
  String platform,
);

/// Version of local/dev builds; CI sets the real one from the git tag.
const String kDevAppVersion = '0.0.0';

const Duration kAppGateTimeout = Duration(seconds: 5);

class AppGateDecision {
  const AppGateDecision.allowed()
      : blocked = false,
        storeUrl = null;
  const AppGateDecision.blocked(String this.storeUrl) : blocked = true;

  final bool blocked;
  final String? storeUrl;
}

/// Decides whether this app version may run.
///
/// Fails open: any error, timeout, empty or malformed answer allows the app.
/// [platform] is 'ios' or 'android'; anything else is allowed.
Future<AppGateDecision> checkAppGate({
  required MinVersionFetcher fetch,
  required String currentVersion,
  required String platform,
  Duration timeout = kAppGateTimeout,
}) async {
  const allowed = AppGateDecision.allowed();
  if (currentVersion == kDevAppVersion) return allowed;
  if (platform != 'ios' && platform != 'android') return allowed;
  try {
    final result = await fetch(platform).timeout(timeout);
    if (result == null) return allowed;
    final min = result['min_version'];
    final url = result['store_url'];
    if (min is! String || min.isEmpty || url is! String || url.isEmpty) {
      return allowed;
    }
    if (compareVersions(currentVersion, min) < 0) {
      return AppGateDecision.blocked(url);
    }
    return allowed;
  } catch (_) {
    return allowed;
  }
}
