import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/core/utils/pressure_shares.dart';

/// The result of the last one-minute foot check the wearer finished on real
/// sole data, kept on the phone so the home screen can show it.
///
/// The home screen only needs the band ([FootCheckRating]), see its doc for
/// why there is no score. The two load shares the band came from are kept as
/// well so the shared activity record can show them.
class FootCheckRecord {
  const FootCheckRecord({
    required this.rating,
    required this.takenAt,
    this.foreRatio,
    this.medialRatio,
  });

  final FootCheckRating rating;
  final DateTime takenAt;

  /// Forefoot share of the load, 0 → 1, as the check measured it. Null for a
  /// record written before the shares were kept: it has only its band.
  final double? foreRatio;

  /// Inner share of the forefoot load, 0 → 1. Null like [foreRatio] for an old
  /// record, and also when the forefoot carried too little load for a split to
  /// mean anything (see [PressureShares.minForeFraction]).
  final double? medialRatio;

  /// The record [report] leaves behind when it ends at [at], or null when it
  /// has nothing of the wearer's to keep: too little data to judge, or a
  /// result computed from a sample clip.
  static FootCheckRecord? fromReport(FootCheckReport report, DateTime at) {
    final balance = report.balance;
    if (balance == null || report.fromSample) return null;
    return FootCheckRecord(
      rating: balance.rating,
      takenAt: at,
      foreRatio: balance.foreRatio,
      // The tally falls back to an even split when the forefoot carried
      // nothing; that is not a measurement, so it is not kept.
      medialRatio: balance.foreRatio < PressureShares.minForeFraction
          ? null
          : balance.medialRatio,
    );
  }

  /// Whether the check was taken on [day]'s local calendar date.
  bool isOnDay(DateTime day) =>
      takenAt.year == day.year &&
      takenAt.month == day.month &&
      takenAt.day == day.day;

  String encode() => jsonEncode({
    'rating': rating.name,
    'taken_at': takenAt.millisecondsSinceEpoch,
    if (foreRatio != null) 'fore_ratio': foreRatio,
    if (medialRatio != null) 'medial_ratio': medialRatio,
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
      // The shares are optional; one outside 0 → 1 is dropped and the band
      // still stands. An inner share without a forefoot share is meaningless.
      final fore = _ratio(json['fore_ratio']);
      return FootCheckRecord(
        rating: rating,
        takenAt: DateTime.fromMillisecondsSinceEpoch(takenAt),
        foreRatio: fore,
        medialRatio: fore == null ? null : _ratio(json['medial_ratio']),
      );
    } on FormatException {
      return null;
    }
  }

  static double? _ratio(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 1
      ? value.toDouble()
      : null;

  @override
  bool operator ==(Object other) =>
      other is FootCheckRecord &&
      other.rating == rating &&
      other.takenAt == takenAt &&
      other.foreRatio == foreRatio &&
      other.medialRatio == medialRatio;

  @override
  int get hashCode => Object.hash(rating, takenAt, foreRatio, medialRatio);
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
