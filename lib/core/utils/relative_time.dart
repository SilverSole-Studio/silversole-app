import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';

/// Formats how long ago [past] was as a coarse relative label.
///
/// Buckets, in order: seconds → minutes → hours → days → "over 7 days".
/// Reads the clock through `package:clock` so callers can pin it in tests.
String formatTimeAgo(DateTime past) {
  final diff = clock.now().difference(past);
  final seconds = diff.inSeconds < 0 ? 0 : diff.inSeconds;
  if (seconds < 60) return 'time_ago_seconds'.tr(args: ['$seconds']);
  if (diff.inMinutes < 60) {
    return 'time_ago_minutes'.tr(args: ['${diff.inMinutes}']);
  }
  if (diff.inHours < 24) return 'time_ago_hours'.tr(args: ['${diff.inHours}']);
  if (diff.inDays < 7) return 'time_ago_days'.tr(args: ['${diff.inDays}']);
  return 'time_ago_over_7_days'.tr();
}
