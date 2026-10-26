import 'dart:convert';

import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';

/// The JavaScript that hands one raw [sample] to a game page.
///
/// A page with the two-feet `window.onSoleSample` gets every sole's samples,
/// tagged with the [foot] it is worn on (null until assigned) and whether it
/// is the [primary] sole. A page from before that only has
/// `window.onImuData`, and gets the primary sole alone — exactly what it got
/// when the app forwarded a single sole — so the games can ship either side
/// of an app release. See
/// `docs/superpowers/specs/2026-10-22-two-feet-game-input-design.md` §3.
String soleSampleScript(
  ImuNotifyDataModel sample, {
  required FootSide? foot,
  required bool primary,
}) {
  final json = jsonEncode({
    ...sample.toJson(),
    'foot': foot?.name,
    'primary': primary,
  });
  return 'window.onSoleSample ? onSoleSample($json) : '
      '($primary && window.onImuData && onImuData($json))';
}

/// [script] wrapped so it only runs on a page whose `location.origin` is
/// [origin] — the games' own site.
///
/// The check runs inside the page at evaluation time, so a web view that has
/// navigated elsewhere since the app last looked at its URL (the plaza links
/// out in the same web view) never receives a sample. `allowedOriginRules`
/// would not do: it applies to UserScripts only, and only on Android.
String gameOriginGuard(String script, String origin) =>
    'if(location.origin===${jsonEncode(origin)}){$script}';
