import 'dart:collection';

/// How the load on one foot splits, as plain ratios.
///
/// Raw sensor counts are not shown to wearers; these ratios are. Neither is a
/// judgement: there is no "leans forward" here, just where the weight is.
class PressureShares {
  const PressureShares({required this.foreRatio, required this.medialRatio});

  /// Forefoot (big-toe ball + little toe) share of the whole load, 0 → 1.
  final double foreRatio;

  /// Big-toe-ball share of the forefoot load, 0 → 1. Null when the forefoot
  /// carries too little load for the split to mean anything.
  final double? medialRatio;

  double get heelRatio => 1 - foreRatio;

  /// Forefoot load below this fraction of the total leaves [medialRatio] null.
  static const minForeFraction = 0.05;

  /// [meanPressure] is `[big-toe ball, little toe, heel]`, already averaged.
  /// Null when the foot is not on the insole ([PressureShareWindow.minLoad]).
  static PressureShares? from(List<num> meanPressure) {
    if (meanPressure.length < 3) return null;
    final medial = meanPressure[0];
    final lateral = meanPressure[1];
    final heel = meanPressure[2];
    final total = medial + lateral + heel;
    if (total < PressureShareWindow.minLoad) return null;
    final fore = medial + lateral;
    return PressureShares(
      foreRatio: fore / total,
      medialRatio: fore < total * minForeFraction ? null : medial / fore,
    );
  }
}

/// A rolling two-second average of one foot's pressure, so the bars move
/// calmly instead of flickering with every sample.
class PressureShareWindow {
  /// How far back samples still count.
  static const span = Duration(seconds: 2);

  /// Samples needed in the window before any ratio is shown.
  static const minSamples = 5;

  /// Raw-count total (three sensors added) below which the foot is taken to be
  /// off the insole. Same order of magnitude as the gait detector's
  /// `GaitConfig.minLoadRange`.
  ///
  /// Initial value: tune it against real standing data.
  static const minLoad = 300;

  final Queue<(DateTime, List<int>)> _samples = Queue();

  void add(DateTime at, List<int> pressure) {
    if (pressure.length < 3) return;
    _samples.addLast((at, pressure));
    final cutoff = at.subtract(span);
    while (_samples.isNotEmpty && _samples.first.$1.isBefore(cutoff)) {
      _samples.removeFirst();
    }
  }

  PressureShares? get shares {
    if (_samples.length < minSamples) return null;
    final sum = [0.0, 0.0, 0.0];
    for (final (_, p) in _samples) {
      for (var i = 0; i < 3; i++) {
        sum[i] += p[i];
      }
    }
    return PressureShares.from([for (final s in sum) s / _samples.length]);
  }

  void clear() => _samples.clear();
}

/// Feeds one [PressureShareWindow] per foot from a stream of readings that may
/// be rebuilt from more often than they change.
///
/// A reading counts once: the same list object handed in twice is skipped. A
/// foot with nothing feeding it keeps no history, and switching between live
/// data and a sample clip starts both windows over so the two never mix.
class PressureShareTracker {
  final right = PressureShareWindow();
  final left = PressureShareWindow();

  List<int>? _lastRight;
  List<int>? _lastLeft;
  bool _sample = false;

  /// [hasRight] false means nothing feeds the right foot ([right] is then only
  /// a placeholder); a null [left] means nothing feeds the left foot.
  void update({
    required DateTime at,
    required List<int> rightReading,
    required bool hasRight,
    required List<int>? leftReading,
    required bool isSample,
  }) {
    if (isSample != _sample) {
      _sample = isSample;
      clear();
    }
    if (!hasRight) {
      right.clear();
      _lastRight = null;
    } else if (!identical(rightReading, _lastRight)) {
      _lastRight = rightReading;
      right.add(at, rightReading);
    }
    if (leftReading == null) {
      left.clear();
      _lastLeft = null;
    } else if (!identical(leftReading, _lastLeft)) {
      _lastLeft = leftReading;
      left.add(at, leftReading);
    }
  }

  void clear() {
    right.clear();
    left.clear();
    _lastRight = null;
    _lastLeft = null;
  }
}
