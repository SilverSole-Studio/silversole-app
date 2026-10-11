import 'package:easy_localization/easy_localization.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/core/utils/relative_time.dart';

/// What the BLE foreground service's ongoing notification says, worded like the
/// home device card so the two never disagree:
///
/// - title: the sole's name
/// - text: `Online` or `Last connected: 5 min ago`, then the battery level when
///   one is known (live, else the last one the sole reported — see
///   [BatteryDisplay]); a sole that never reported one shows no battery.
({String title, String text}) soleNotificationText({
  required String soleName,
  required bool online,
  required DateTime? lastSeen,
  required BatteryDisplay battery,
}) {
  final status = online
      ? 'online'.tr()
      : lastSeen != null
      ? 'last_connected'.tr(args: [formatTimeAgo(lastSeen)])
      : 'offline'.tr();
  final text = battery.percent == null
      ? status
      : '$status · ${'battery'.tr()} ${battery.label}';
  return (title: soleName, text: text);
}
