/// Battery level as the sole reports it: a u8 percentage, where the firmware
/// sends 0xFF (255) when it has no valid reading.
extension BatteryPercentX on int {
  /// The firmware's "undefined / invalid" battery sentinel.
  static const int invalid = 255;

  bool get isValidBatteryPercent => this != invalid;

  /// This reading, or null when it is the invalid sentinel — charts plot null
  /// as a gap rather than a spike off the top of the 0–100 axis.
  int? get validBatteryPercent => isValidBatteryPercent ? this : null;

  /// `85%`, or `-` when the reading is the invalid sentinel.
  String get batteryLabel => isValidBatteryPercent ? '$this%' : '-';

  /// Fill fraction for a battery bar; an invalid reading draws an empty bar.
  double get batteryFraction =>
      isValidBatteryPercent ? (this / 100).clamp(0.0, 1.0) : 0.0;
}

/// What a battery widget shows: the sole's live reading while it is reporting
/// a valid one, otherwise the last level it reported before going quiet.
///
/// A widget draws [isLive] in the accent color and anything else in gray, so a
/// remembered level reads as "previous", not current. That covers both an
/// offline sole and a reconnected one that has not sent a valid reading yet
/// (the firmware's 255 sentinel); neither falls back to a dash while there is
/// a remembered level to show.
class BatteryDisplay {
  const BatteryDisplay._(this.percent, {required this.isLive});

  /// [live] is the connected sole's latest reading — pass null while the sole
  /// is offline, since a stale sample is not live. [lastKnown] is the level
  /// remembered for this sole from an earlier session.
  factory BatteryDisplay.resolve({int? live, int? lastKnown}) {
    final valid = live?.validBatteryPercent;
    if (valid != null) return BatteryDisplay._(valid, isLive: true);
    return BatteryDisplay._(lastKnown?.validBatteryPercent, isLive: false);
  }

  /// The level to show, or null when this sole has never reported one.
  final int? percent;

  /// True when [percent] is the connected sole's current reading.
  final bool isLive;

  /// `85%`, or `-` when there is nothing to show.
  String get label => percent?.batteryLabel ?? '-';

  /// Fill fraction for a battery bar; empty when there is nothing to show.
  double get fraction => percent?.batteryFraction ?? 0.0;
}
