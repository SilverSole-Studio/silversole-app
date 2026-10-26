import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';

/// The result of the last one-minute foot check the wearer finished on real
/// sole data, kept on the phone so the home screen can show it.
///
/// There is no number to keep: a check ends on a band ([FootCheckRating]), see
/// its doc for why.
class FootCheckRecord {
  const FootCheckRecord({required this.rating, required this.takenAt});

  final FootCheckRating rating;
  final DateTime takenAt;

  /// The record [report] leaves behind when it ends at [at], or null when it
  /// has nothing of the wearer's to keep: too little data to judge, or a
  /// result computed from a sample clip.
  static FootCheckRecord? fromReport(FootCheckReport report, DateTime at) {
    final balance = report.balance;
    if (balance == null || report.fromSample) return null;
    return FootCheckRecord(rating: balance.rating, takenAt: at);
  }

  /// Whether the check was taken on [day]'s local calendar date.
  bool isOnDay(DateTime day) =>
      takenAt.year == day.year &&
      takenAt.month == day.month &&
      takenAt.day == day.day;

  String encode() => jsonEncode({
    'rating': rating.name,
    'taken_at': takenAt.millisecondsSinceEpoch,
  });

  /// Null for anything that is not a record this app wrote — better no result
  /// on the home screen than a wrong one.
  static FootCheckRecord? tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final rating = FootCheckRating.values.asNameMap()[json['rating']];
      final takenAt = json['taken_at'];
      if (rating == null || takenAt is! int) return null;
      return FootCheckRecord(
        rating: rating,
        takenAt: DateTime.fromMillisecondsSinceEpoch(takenAt),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FootCheckRecord &&
      other.rating == rating &&
      other.takenAt == takenAt;

  @override
  int get hashCode => Object.hash(rating, takenAt);
}

/// The last finished foot check, or null when there has never been one.
class LastFootCheckNotifier extends Notifier<FootCheckRecord?> {
  /// Set once [record] has run, so the initial load — which may finish later —
  /// cannot put an older result back.
  bool _recorded = false;

  @override
  FootCheckRecord? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final saved = FootCheckRecord.tryDecode(
      await loadLocalValue(LocalSavableKey.lastFootCheck),
    );
    if (!_recorded && saved != null) state = saved;
  }

  Future<void> record(FootCheckRecord result) async {
    _recorded = true;
    state = result;
    await saveLocalValue(LocalSavableKey.lastFootCheck, result.encode());
  }
}

final lastFootCheckProvider =
    NotifierProvider<LastFootCheckNotifier, FootCheckRecord?>(
      LastFootCheckNotifier.new,
    );
