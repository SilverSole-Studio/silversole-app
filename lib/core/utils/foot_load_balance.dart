import 'package:silversole/core/utils/foot_check_rating.dart';

/// Which way the load leans front to back.
enum ForeAftBias {
  balanced('foot_check_fore_aft_balanced'),
  forefoot('foot_check_fore_aft_forefoot'),
  rearfoot('foot_check_fore_aft_rearfoot');

  const ForeAftBias(this.summaryKey);

  /// Key in `strings.csv`.
  final String summaryKey;

  bool get isBalanced => this == balanced;
}

/// Which way the forefoot load leans across the foot.
enum MedialLateralBias {
  balanced('foot_check_side_balanced'),
  medial('foot_check_side_medial'),
  lateral('foot_check_side_lateral');

  const MedialLateralBias(this.summaryKey);

  /// Key in `strings.csv`.
  final String summaryKey;

  bool get isBalanced => this == balanced;
}

/// How the load was spread over one foot during a check.
///
/// Both ratios come from the three FSRs the sole actually reports, so unlike
/// the rating that preceded this, the numbers describe the wearer's foot.
///
/// **The thresholds are demo-grade heuristics, not clinical limits.** Standing
/// plantar pressure is usually described as roughly 40% forefoot to 60%
/// rearfoot, which is where [foreTarget] comes from; the tolerances are set
/// wide enough that a normal foot does not get flagged. Anything diagnostic
/// needs a validated protocol and a scale calibrated in newtons — the sole
/// reports raw counts.
class FootLoadBalance {
  const FootLoadBalance({required this.foreRatio, required this.medialRatio});

  /// Forefoot share of the whole load, 0 → 1.
  final double foreRatio;

  /// Big-toe-ball share of the forefoot load, 0 → 1.
  final double medialRatio;

  static const foreTarget = 0.40;
  static const foreTolerance = 0.10;
  static const medialTarget = 0.50;
  static const medialTolerance = 0.12;

  double get rearRatio => 1 - foreRatio;
  double get lateralRatio => 1 - medialRatio;

  /// Floating point puts an exact-boundary ratio a hair outside its tolerance
  /// (0.40 - 0.30 comes out as 0.100000000000000003), so the comparison carries
  /// a slack far smaller than any reading could resolve.
  static const _epsilon = 1e-9;

  static bool _within(double value, double target, double tolerance) =>
      (value - target).abs() <= tolerance + _epsilon;

  ForeAftBias get foreAft {
    if (_within(foreRatio, foreTarget, foreTolerance)) {
      return ForeAftBias.balanced;
    }
    return foreRatio > foreTarget ? ForeAftBias.forefoot : ForeAftBias.rearfoot;
  }

  MedialLateralBias get side {
    if (_within(medialRatio, medialTarget, medialTolerance)) {
      return MedialLateralBias.balanced;
    }
    return medialRatio > medialTarget
        ? MedialLateralBias.medial
        : MedialLateralBias.lateral;
  }

  /// One band per axis still in balance: both → excellent, one → very good,
  /// neither → good. Deliberately explainable in a sentence; a weighted score
  /// would only look more precise than the data is.
  FootCheckRating get rating =>
      switch ((foreAft.isBalanced ? 1 : 0) + (side.isBalanced ? 1 : 0)) {
        2 => FootCheckRating.excellent,
        1 => FootCheckRating.veryGood,
        _ => FootCheckRating.good,
      };
}

/// Running tally of the plantar pressure shown during a check.
///
/// Sums rather than stores: a minute at 20–50 Hz is a few thousand samples and
/// only the means are ever read.
class FootPressureTally {
  /// Below this there is nothing worth reporting on — roughly half a second of
  /// samples.
  static const minSamples = 20;

  int _samples = 0;
  double _hallux = 0;
  double _littleToe = 0;
  double _heel = 0;

  int get samples => _samples;

  /// Adds one reading in the documented channel order (hallux, little toe,
  /// heel). Short readings are ignored: a broken payload should not shift the
  /// means.
  void add(List<int> pressure) {
    if (pressure.length < 3) return;
    _samples++;
    _hallux += pressure[0];
    _littleToe += pressure[1];
    _heel += pressure[2];
  }

  /// The balance to report, or null when too little was collected to say
  /// anything — no samples, or a sole that never carried any load at all.
  FootLoadBalance? get balance {
    final total = _hallux + _littleToe + _heel;
    if (_samples < minSamples || total <= 0) return null;
    final fore = _hallux + _littleToe;
    return FootLoadBalance(
      foreRatio: fore / total,
      // With no forefoot load at all there is no side to lean to; the fore/aft
      // axis is what carries that finding.
      medialRatio: fore <= 0 ? FootLoadBalance.medialTarget : _hallux / fore,
    );
  }
}

/// What one finished check has to report.
class FootCheckReport {
  const FootCheckReport({
    required this.balance,
    required this.samples,
    required this.collected,
  });

  /// Nothing was collected — a direct visit to the report, or a check with no
  /// sole feeding it.
  static const empty = FootCheckReport(
    balance: null,
    samples: 0,
    collected: Duration.zero,
  );

  /// Null when too little was collected to judge anything.
  final FootLoadBalance? balance;

  /// Distinct readings the session saw.
  final int samples;

  /// How long it actually collected for — less than a minute when the wearer
  /// ended it early.
  final Duration collected;
}
