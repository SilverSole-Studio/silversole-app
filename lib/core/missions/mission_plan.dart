import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:silversole/core/missions/mission_catalog.dart';

/// Where a day's plan came from.
enum MissionPlanSource { rule, ai }

/// One mission of the day. [reason] is the line shown under the title; plans
/// made by rules have none.
class MissionPlanItem {
  const MissionPlanItem(this.id, {this.reason});

  final String id;
  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is MissionPlanItem && other.id == id && other.reason == reason;

  @override
  int get hashCode => Object.hash(id, reason);
}

/// The missions picked for one day. Made once, the first time the sheet opens
/// that day, and kept so playing a game never swaps the list under the wearer.
class MissionPlan {
  const MissionPlan({
    required this.day,
    required this.source,
    this.greeting,
    required this.items,
  });

  /// The local date as `yyyy-MM-dd` (a `gaitDateKey`).
  final String day;
  final MissionPlanSource source;
  final String? greeting;
  final List<MissionPlanItem> items;

  String encode() => jsonEncode({
    'day': day,
    'source': source.name,
    if (greeting != null) 'greeting': greeting,
    'items': [
      for (final i in items)
        {'id': i.id, if (i.reason != null) 'reason': i.reason},
    ],
  });

  /// Null for anything this app did not write. Ids the catalog does not know
  /// are dropped, so a mission taken out of the app cannot break the sheet;
  /// a plan left with nothing is null.
  static MissionPlan? tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final day = json['day'];
      final source = MissionPlanSource.values.asNameMap()[json['source']];
      final greeting = json['greeting'];
      final items = json['items'];
      if (day is! String || source == null || items is! List) return null;
      if (greeting != null && greeting is! String) return null;
      final kept = <MissionPlanItem>[];
      for (final item in items) {
        if (item is! Map) return null;
        final id = item['id'], reason = item['reason'];
        if (id is! String || (reason != null && reason is! String)) {
          return null;
        }
        if (MissionCatalog.isKnown(id) && !kept.any((k) => k.id == id)) {
          kept.add(MissionPlanItem(id, reason: reason as String?));
        }
      }
      if (kept.isEmpty) return null;
      return MissionPlan(
        day: day,
        source: source,
        greeting: greeting as String?,
        items: kept,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MissionPlan &&
      other.day == day &&
      other.source == source &&
      other.greeting == greeting &&
      const ListEquality<MissionPlanItem>().equals(other.items, items);

  @override
  int get hashCode => Object.hash(day, source, greeting, Object.hashAll(items));
}
