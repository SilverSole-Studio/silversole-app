import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/battery_level.dart';

void main() {
  test('255 is the invalid sentinel and renders as "-" with an empty bar', () {
    expect(BatteryPercentX.invalid, 255);
    expect(255.isValidBatteryPercent, isFalse);
    expect(255.validBatteryPercent, isNull);
    expect(255.batteryLabel, '-');
    expect(255.batteryFraction, 0.0);
  });

  test('valid readings render as a percentage', () {
    expect(0.batteryLabel, '0%');
    expect(85.batteryLabel, '85%');
    expect(100.batteryLabel, '100%');
    expect(0.validBatteryPercent, 0);
    expect(85.validBatteryPercent, 85);
    expect(85.batteryFraction, closeTo(0.85, 1e-9));
    expect(100.batteryFraction, 1.0);
  });
}
