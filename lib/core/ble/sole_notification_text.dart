import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/core/utils/relative_time.dart';

/// One sole's part of the BLE foreground service's ongoing notification.
@immutable
class SoleNotice {
  const SoleNotice({
    required this.name,
    required this.label,
    required this.online,
    required this.lastSeen,
    required this.battery,
  });

  final String name;

  /// How to tell this sole apart when there are two: the foot it is worn on
  /// (see `FootSide.labelKey`), or its ID suffix before a side is assigned.
  /// Unused with a single sole, where the status reads in full.
  final String label;

  final bool online;
  final DateTime? lastSeen;
  final BatteryDisplay battery;
}

/// What the BLE foreground service's ongoing notification says, worded like
/// the home device card so the two never disagree.
///
/// With **one** sole (the only case before two feet existed, and still the
/// case whenever only one is connected):
///
/// - title: the sole's name
/// - text: `Online` or `Last connected: 5 min ago`, then the battery level
///   when one is known (live, else the last one the sole reported — see
///   [BatteryDisplay]); a sole that never reported one shows no battery.
///
/// With **two**, a notification line has no room for two "last connected"
/// phrases, so each foot is reduced to its label plus the one fact that
/// matters: its battery, or that it is offline.
({String title, String text}) soleNotificationText(List<SoleNotice> soles) {
  if (soles.isEmpty) return (title: 'Silver Sole', text: '');

  String status(SoleNotice sole) => sole.online
      ? 'online'.tr()
      : sole.lastSeen != null
      ? 'last_connected'.tr(args: [formatTimeAgo(sole.lastSeen!)])
      : 'offline'.tr();

  if (soles.length == 1) {
    final sole = soles.single;
    final text = sole.battery.percent == null
        ? status(sole)
        : '${status(sole)} · ${'battery'.tr()} ${sole.battery.label}';
    return (title: sole.name, text: text);
  }

  // Relative time is for the single-sole line only: with two feet there is no
  // room for it, and an offline foot must say so plainly, whatever lastSeen
  // holds (the controller passes one in practice).
  String footFact(SoleNotice sole) => !sole.online
      ? 'offline'.tr()
      : sole.battery.percent != null
      ? sole.battery.label
      : 'online'.tr();

  final names = soles.map((s) => s.name).toSet();
  final title = names.length == 1 ? names.single : names.join(' / ');
  final text = soles.map((s) => '${s.label} ${footFact(s)}').join(' · ');
  return (title: title, text: text);
}
