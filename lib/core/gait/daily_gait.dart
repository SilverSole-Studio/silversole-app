import 'dart:math' as math;

import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/shared/models/foot_side.dart';

/// Which foot a contact came from, including a sole whose side has not been
/// assigned yet — it still counts steps, but never towards left-right balance.
enum GaitFoot {
  left,
  right,
  unknown;

  static GaitFoot of(FootSide? side) => switch (side) {
    FootSide.left => left,
    FootSide.right => right,
    null => unknown,
  };
}

/// The calendar date of [t] as `yyyy-MM-dd` — the key days are stored under,
/// which also sorts in date order. Callers must pass local time: it reads the
/// fields as they are and does not convert.
String gaitDateKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// One foot's running sums for one day.
///
/// Sums rather than lists, so days merge by addition and a quarter of
/// history stays small. Squared stride times are kept so the variation can
/// be worked out without keeping every stride.
class FootGaitStats {
  const FootGaitStats({
    this.contacts = 0,
    this.walkingMs = 0,
    this.stanceMs = 0,
    this.swingMs = 0,
    this.strides = 0,
    this.strideMs = 0,
    this.strideSqMs = 0,
  });

  final int contacts;

  /// Time covered by this foot's bouts.
  final int walkingMs;

  /// Summed over every contact.
  final int stanceMs;

  /// Summed over every contact that has a previous one in its bout — the
  /// same contacts [strides] counts.
  final int swingMs;
  final int strides;
  final int strideMs;
  final int strideSqMs;

  FootGaitStats add(BoutContact walked, Duration walking) {
    final stride = walked.stride?.inMilliseconds;
    return FootGaitStats(
      contacts: contacts + 1,
      walkingMs: walkingMs + walking.inMilliseconds,
      stanceMs: stanceMs + walked.contact.duration.inMilliseconds,
      swingMs: swingMs + (walked.swing?.inMilliseconds ?? 0),
      strides: strides + (stride == null ? 0 : 1),
      strideMs: strideMs + (stride ?? 0),
      strideSqMs: strideSqMs + (stride == null ? 0 : stride * stride),
    );
  }

  FootGaitStats operator +(FootGaitStats other) => FootGaitStats(
    contacts: contacts + other.contacts,
    walkingMs: walkingMs + other.walkingMs,
    stanceMs: stanceMs + other.stanceMs,
    swingMs: swingMs + other.swingMs,
    strides: strides + other.strides,
    strideMs: strideMs + other.strideMs,
    strideSqMs: strideSqMs + other.strideSqMs,
  );

  Map<String, Object> toJson() => {
    'contacts': contacts,
    'walking_ms': walkingMs,
    'stance_ms': stanceMs,
    'swing_ms': swingMs,
    'strides': strides,
    'stride_ms': strideMs,
    'stride_sq_ms': strideSqMs,
  };

  static FootGaitStats? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final values = [
      json['contacts'],
      json['walking_ms'],
      json['stance_ms'],
      json['swing_ms'],
      json['strides'],
      json['stride_ms'],
      json['stride_sq_ms'],
    ];
    if (values.any((v) => v is! int || v < 0)) return null;
    final v = values.cast<int>();
    return FootGaitStats(
      contacts: v[0],
      walkingMs: v[1],
      stanceMs: v[2],
      swingMs: v[3],
      strides: v[4],
      strideMs: v[5],
      strideSqMs: v[6],
    );
  }
}

/// Everything the gait tab needs from one day of walking bouts.
///
/// Every figure the tab shows is a getter over these sums, so the same
/// formulas serve one day, a week or a quarter: merge the days, then read.
class DailyGait {
  const DailyGait({
    required this.date,
    this.steps = 0,
    this.feet = const {},
    this.doubleSupportMs = 0,
    this.bothFeetWalkingMs = 0,
  });

  /// [gaitDateKey] of the day.
  final String date;

  /// Walking steps: two per contact while only one sole is walking, one per
  /// contact while both are (see `GaitTracker`).
  final int steps;
  final Map<GaitFoot, FootGaitStats> feet;

  /// Time with both feet down, and the walking time it is a share of — both
  /// only counted while two soles walk together.
  final int doubleSupportMs;
  final int bothFeetWalkingMs;

  /// Fewer strides than this and a variation says more about chance than
  /// about the wearer.
  static const minStridesForCv = 10;

  bool get hasData => steps > 0;

  /// Time spent walking. Each foot's total covers the whole walk, so adding
  /// them counts the time both feet walk twice; [bothFeetWalkingMs] holds half
  /// of each foot's walking time over exactly those stretches, which is the
  /// time to take off again: alone gives T, both feet give 2T - T. Unlike a
  /// maximum over the feet this adds up across merged days.
  int get walkingMs {
    final sum = feet.values.fold(0, (n, f) => n + f.walkingMs);
    return math.max(0, sum - bothFeetWalkingMs);
  }

  /// Steps per minute of walking.
  double? get cadence => walkingMs == 0 ? null : steps / (walkingMs / 60000);

  /// Share of each step with the foot down.
  double? get stanceRatio {
    final t = _total;
    if (t.contacts == 0 || t.strides == 0) return null;
    final stance = t.stanceMs / t.contacts;
    final swing = t.swingMs / t.strides;
    return stance / (stance + swing);
  }

  /// Coefficient of variation of stride time, pooled over the feet.
  double? get strideCv {
    final t = _total;
    if (t.strides < minStridesForCv) return null;
    final mean = t.strideMs / t.strides;
    final variance = math.max(0.0, t.strideSqMs / t.strides - mean * mean);
    return math.sqrt(variance) / mean;
  }

  /// The shorter mean stance time over the longer: 1 is identical feet.
  double? get symmetry {
    final left = feet[GaitFoot.left];
    final right = feet[GaitFoot.right];
    if (left == null || right == null) return null;
    if (left.contacts == 0 || right.contacts == 0) return null;
    final l = left.stanceMs / left.contacts;
    final r = right.stanceMs / right.contacts;
    return math.min(l, r) / math.max(l, r);
  }

  double? get doubleSupportRatio =>
      bothFeetWalkingMs == 0 ? null : doubleSupportMs / bothFeetWalkingMs;

  FootGaitStats get _total =>
      feet.values.fold(const FootGaitStats(), (sum, f) => sum + f);

  DailyGait withContact({
    required GaitFoot foot,
    required BoutContact contact,
    required Duration walking,
    required int steps,
    required Duration doubleSupport,
    required Duration bothFeetWalking,
  }) => DailyGait(
    date: date,
    steps: this.steps + steps,
    feet: {
      ...feet,
      foot: (feet[foot] ?? const FootGaitStats()).add(contact, walking),
    },
    doubleSupportMs: doubleSupportMs + doubleSupport.inMilliseconds,
    bothFeetWalkingMs: bothFeetWalkingMs + bothFeetWalking.inMilliseconds,
  );

  /// This day plus [other], keeping this day's [date].
  DailyGait merge(DailyGait other) => DailyGait(
    date: date,
    steps: steps + other.steps,
    feet: {
      for (final foot in {...feet.keys, ...other.feet.keys})
        foot:
            (feet[foot] ?? const FootGaitStats()) +
            (other.feet[foot] ?? const FootGaitStats()),
    },
    doubleSupportMs: doubleSupportMs + other.doubleSupportMs,
    bothFeetWalkingMs: bothFeetWalkingMs + other.bothFeetWalkingMs,
  );

  Map<String, Object> toJson() => {
    'date': date,
    'steps': steps,
    'feet': {
      for (final entry in feet.entries) entry.key.name: entry.value.toJson(),
    },
    'double_support_ms': doubleSupportMs,
    'both_walking_ms': bothFeetWalkingMs,
  };

  static final _dateKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Null for anything this app did not write — better a missing day than a
  /// wrong one.
  static DailyGait? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final date = json['date'];
    final steps = json['steps'];
    final feet = json['feet'];
    final doubleSupport = json['double_support_ms'];
    final bothWalking = json['both_walking_ms'];
    if (date is! String ||
        !_dateKey.hasMatch(date) ||
        steps is! int ||
        steps < 0 ||
        feet is! Map ||
        doubleSupport is! int ||
        doubleSupport < 0 ||
        bothWalking is! int ||
        bothWalking < 0) {
      return null;
    }
    final parsed = <GaitFoot, FootGaitStats>{};
    for (final entry in feet.entries) {
      final foot = GaitFoot.values.asNameMap()[entry.key];
      final stats = FootGaitStats.tryFromJson(entry.value);
      if (foot == null || stats == null) return null;
      parsed[foot] = stats;
    }
    return DailyGait(
      date: date,
      steps: steps,
      feet: parsed,
      doubleSupportMs: doubleSupport,
      bothFeetWalkingMs: bothWalking,
    );
  }
}
