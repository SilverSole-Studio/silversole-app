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
