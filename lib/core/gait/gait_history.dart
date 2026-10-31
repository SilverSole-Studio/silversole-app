import 'dart:convert';

import 'package:silversole/core/gait/daily_gait.dart';

/// Days of history kept, counting today: the quarter view needs twelve weeks.
const gaitHistoryDays = 90;

/// [history] with [deltas] added day by day, and every day older than
/// [gaitHistoryDays] dropped.
///
/// The ninety days are counted back from [today], but never from further
/// than a week past the newest day already in [history]. A phone clock that
/// is wrong and ahead would otherwise delete real days for good; keeping a
/// few extra days after a long gap is harmless, since they age out once
/// newer days arrive.
Map<String, DailyGait> mergeGaitHistory(
  Map<String, DailyGait> history,
  Iterable<DailyGait> deltas,
  DateTime today,
) {
  final merged = {...history};
  for (final delta in deltas) {
    final stored = merged[delta.date];
    merged[delta.date] = stored == null ? delta : stored.merge(delta);
  }
  var anchor = DateTime(today.year, today.month, today.day);
  if (history.isNotEmpty) {
    final newest = history.keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final limit = DateTime.parse(newest).add(const Duration(days: 7));
    final limitDay = DateTime(limit.year, limit.month, limit.day);
    if (limitDay.isBefore(anchor)) anchor = limitDay;
  }
  final cutoff = gaitDateKey(
    DateTime(anchor.year, anchor.month, anchor.day - (gaitHistoryDays - 1)),
  );
  merged.removeWhere((date, _) => date.compareTo(cutoff) < 0);
  return merged;
}

String encodeGaitHistory(Map<String, DailyGait> history) =>
    jsonEncode([for (final day in history.values) day.toJson()]);

/// The stored history; empty for nothing or anything unreadable, and a day
/// that cannot be read is skipped rather than failing the rest.
Map<String, DailyGait> decodeGaitHistory(String? raw) {
  if (raw == null) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const {};
  }
  if (decoded is! List) return const {};
  return {
    for (final item in decoded)
      if (DailyGait.tryFromJson(item) case final day?) day.date: day,
  };
}
