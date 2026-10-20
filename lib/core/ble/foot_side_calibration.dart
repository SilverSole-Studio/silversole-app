import 'package:flutter/foundation.dart';

/// What a calibration run concluded.
@immutable
class FootSideDecision {
  /// The wearer stepped on the sole keyed [leftKey], so that is the left foot
  /// and the other sole is the right one.
  const FootSideDecision.left(String this.leftKey) : ambiguous = false;

  /// Both soles answered about equally hard, so which foot moved cannot be
  /// told from this step. The wearer is asked to try again.
  const FootSideDecision.ambiguous() : leftKey = null, ambiguous = true;

  /// Null exactly when [ambiguous].
  final String? leftKey;
  final bool ambiguous;
}

/// Decides which of two soles the wearer stepped on, from their live pressure.
///
/// The firmware reports no foot side, so this is how a sole learns it is the
/// left one: the wearer is asked to step on their left foot, and whichever
/// sole's FSRs answer is it.
///
/// Pure Dart, driven entirely by the samples handed to [add] — no BLE, no
/// timers, no clock of its own — so it is tested by feeding it frames. The
/// 15 s "nothing happened" timeout belongs to the UI, not here.
class FootSideCalibrator {
  FootSideCalibrator({
    this.requiredSoles = 2,
    this.baselineSamples = 50,
    this.triggerDelta = 300,
    this.holdSamples = 3,
    this.arbitration = const Duration(milliseconds: 200),
    this.ambiguityRatio = 0.2,
  });

  /// How many soles must be reporting before any decision is allowed. A sole
  /// that is connected but silent (a dead FSR, notifications not started yet)
  /// must not hand the verdict to the only sole that does report.
  final int requiredSoles;

  /// Resting samples collected per sole before it can trigger — at 50 Hz,
  /// about a second of standing still.
  final int baselineSamples;

  /// How far above its own baseline a sole's total pressure must rise to count
  /// as stepped on.
  final int triggerDelta;

  /// Consecutive samples over [triggerDelta] required, so one noisy sample is
  /// not a step.
  final int holdSamples;

  /// How long to keep watching after the first sole triggers. Without it the
  /// verdict would go to whichever sole's packet arrived first, which is radio
  /// timing, not the wearer's foot.
  final Duration arbitration;

  /// The runner-up counts as "just as hard" within this fraction of the
  /// winner's peak, which makes the step ambiguous.
  final double ambiguityRatio;

  final _soles = <String, _SoleTrack>{};
  DateTime? _arbitrationEnds;
  FootSideDecision? _decision;

  /// Feeds one sample, where [pressureSum] is that sole's sensors added up.
  ///
  /// Returns the decision as soon as there is one, and the same decision on
  /// every later call until [reset].
  FootSideDecision? add(String soleKey, int pressureSum, DateTime at) {
    final decided = _decision;
    if (decided != null) return decided;

    final track = _soles.putIfAbsent(soleKey, _SoleTrack.new);
    track.add(
      pressureSum,
      baselineSamples: baselineSamples,
      triggerDelta: triggerDelta,
      holdSamples: holdSamples,
    );

    final ready =
        _soles.length >= requiredSoles &&
        _soles.values.every((t) => t.hasBaseline);
    if (!ready) return null;

    if (track.stepped && _arbitrationEnds == null) {
      _arbitrationEnds = at.add(arbitration);
    }
    final ends = _arbitrationEnds;
    if (ends == null || at.isBefore(ends)) return null;
    return _decision = _decide();
  }

  /// Compares the peaks each sole reached. Peaks are tracked from the moment
  /// its baseline settled rather than only inside the arbitration window —
  /// during a resting baseline there is nothing to peak at, so the two agree,
  /// and tracking throughout means a slow press is not missed.
  FootSideDecision _decide() {
    final ranked = _soles.entries.toList()
      ..sort((a, b) => b.value.peak.compareTo(a.value.peak));
    final winner = ranked.first;
    final runnerUp = ranked.length > 1 ? ranked[1] : null;
    if (runnerUp != null &&
        runnerUp.value.peak >= winner.value.peak * (1 - ambiguityRatio)) {
      return const FootSideDecision.ambiguous();
    }
    return FootSideDecision.left(winner.key);
  }

  /// Forgets every baseline and verdict — the "try again" button.
  void reset() {
    _soles.clear();
    _arbitrationEnds = null;
    _decision = null;
  }
}

/// One sole's running baseline, peak and trigger streak.
class _SoleTrack {
  final _resting = <int>[];
  double? _baseline;
  int _over = 0;

  /// The highest reading above baseline seen so far.
  int peak = 0;
  bool stepped = false;

  bool get hasBaseline => _baseline != null;

  void add(
    int sum, {
    required int baselineSamples,
    required int triggerDelta,
    required int holdSamples,
  }) {
    final baseline = _baseline;
    if (baseline == null) {
      _resting.add(sum);
      if (_resting.length < baselineSamples) return;
      _baseline = _resting.reduce((a, b) => a + b) / _resting.length;
      return;
    }
    final delta = (sum - baseline).round();
    if (delta > peak) peak = delta;
    if (delta >= triggerDelta) {
      _over++;
      if (_over >= holdSamples) stepped = true;
    } else {
      _over = 0;
    }
  }
}
