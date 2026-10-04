import 'dart:math' as math;

/// How far along a fall judgement is, for the demo overlay to draw.
class FallTilt {
  const FallTilt({
    required this.tiltDegrees,
    required this.progress,
    required this.held,
  });

  /// Nothing steep is happening, or the sole is not on a foot.
  static const idle = FallTilt(
    tiltDegrees: 0,
    progress: 0,
    held: Duration.zero,
  );

  /// The steeper of |pitch| and |roll|, rounded to whole degrees so that sensor
  /// noise below one degree does not rebuild the overlay. Zero unless the sole
  /// is past the threshold.
  final double tiltDegrees;

  /// 0 → 1 toward the judgement; 1 means it stands.
  final double progress;

  /// How long the steep tilt has lasted. Keeps counting past the hold, so the
  /// readout can show "held 7 s".
  final Duration held;

  bool get fallen => progress >= 1;

  @override
  bool operator ==(Object other) =>
      other is FallTilt &&
      other.tiltDegrees == tiltDegrees &&
      other.progress == progress &&
      other.held == held;

  @override
  int get hashCode => Object.hash(tiltDegrees, progress, held);

  @override
  String toString() =>
      'FallTilt(${tiltDegrees.toStringAsFixed(0)}°, '
      '${(progress * 100).toStringAsFixed(0)}%, ${held.inMilliseconds}ms)';
}

/// Temporary demo fall judgement: the sole was being stood on, then tipped past
/// [thresholdDegrees] and stayed there for [holdDuration].
///
/// Deliberately crude, and **not** a fall detector. It reads the firmware's
/// fused pitch/roll plus the FSR pressures — no impact test, because the live
/// samples downstream are moving-averaged and would flatten the 20–50 ms peak
/// an impact actually produces. A foot is also a poor place to judge a fall
/// from: it reaches extreme angles all day (kneeling, crossed legs, stairs) and
/// can stay flat through a real sideways fall. This exists to drive the red
/// demo overlay until the firmware's own fall-detect notify can be trusted.
/// Delete it with `FallDemoOverlay` when that lands.
class FallTiltDetector {
  FallTiltDetector({
    this.thresholdDegrees = 70,
    this.releaseDegrees = 50,
    this.holdDuration = const Duration(seconds: 3),
    this.loadedPressure = 50,
    this.weightWindow = const Duration(seconds: 10),
  }) : assert(
         releaseDegrees <= thresholdDegrees,
         'release must not be above the entry threshold',
       );

  /// Past this, the sole counts as tipped over: 70°–90° is toe-down/heel-up,
  /// the shape of a sole on a leg that has gone down.
  final double thresholdDegrees;

  /// The hold only breaks below this, well under [thresholdDegrees]: without
  /// the gap, noise around the entry angle restarts the count over and over.
  final double releaseDegrees;

  /// How long the tilt has to last before the judgement stands, so a sole being
  /// picked up or kicked does not fire it.
  final Duration holdDuration;

  /// An FSR reading at or above this counts as weight on the sole.
  ///
  /// Deliberately low: a gate that is too tight would stop the demo firing at
  /// all, and the raw FSR scale is not verified against hardware yet — check
  /// the analytics page's pressure channel for real loaded/unloaded values.
  final int loadedPressure;

  /// How recently the sole must have been stood on for a judgement to count.
  ///
  /// This is the gate that matters in real use: a shoe on a rack sits toe-down
  /// at 90° for minutes and would otherwise fire every single time.
  final Duration weightWindow;

  DateTime? _steepSince;
  DateTime? _lastLoadedAt;
  bool _steep = false;

  /// Feeds one live sample and returns how far along the judgement is.
  ///
  /// Both angles are checked in both directions, so the judgement does not
  /// depend on which axis the firmware maps toe-down to, nor on its sign
  /// convention — neither is verified against the hardware. A missing angle
  /// counts as no tilt.
  FallTilt update({
    required double? pitch,
    required double? roll,
    required List<int> pressure,
    required DateTime now,
  }) {
    if (pressure.any((p) => p >= loadedPressure)) _lastLoadedAt = now;

    final tilt = math.max((pitch ?? 0).abs(), (roll ?? 0).abs());
    if (tilt < (_steep ? releaseDegrees : thresholdDegrees)) {
      _steep = false;
      _steepSince = null;
      return FallTilt.idle;
    }
    _steep = true;

    final loadedAt = _lastLoadedAt;
    final worn = loadedAt != null && now.difference(loadedAt) <= weightWindow;
    if (!worn) {
      // Tipped over but nobody is standing on it: a shoe off the foot, not a
      // fall. Hold nothing, so it cannot creep toward a judgement.
      _steepSince = null;
      return FallTilt.idle;
    }

    final held = now.difference(_steepSince ??= now);
    return FallTilt(
      tiltDegrees: tilt.roundToDouble(),
      progress: (held.inMilliseconds / holdDuration.inMilliseconds).clamp(
        0.0,
        1.0,
      ),
      held: held,
    );
  }
}
