import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_view_data.dart';

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

  group('BatteryDisplay', () {
    test('never connected: nothing to show, not live', () {
      final d = BatteryDisplay.resolve();
      expect(d.percent, isNull);
      expect(d.isLive, isFalse);
      expect(d.label, '-');
      expect(d.fraction, 0.0);
    });

    test('offline: the remembered level, grayed out', () {
      final d = BatteryDisplay.resolve(lastKnown: 62);
      expect(d.label, '62%');
      expect(d.isLive, isFalse);
    });

    test(
      'connected without a valid reading yet keeps the remembered level',
      () {
        final d = BatteryDisplay.resolve(live: 255, lastKnown: 62);
        expect(d.label, '62%');
        expect(d.isLive, isFalse);
      },
    );

    test('a valid live reading wins and is live', () {
      final d = BatteryDisplay.resolve(live: 70, lastKnown: 62);
      expect(d.label, '70%');
      expect(d.fraction, closeTo(0.7, 1e-9));
      expect(d.isLive, isTrue);
    });
  });

  group('buildDeviceRows battery', () {
    const primary = BlePairedDevice(
      remoteId: 'A',
      name: 'a',
      lastBatteryPercent: 40,
    );
    const other = BlePairedDevice(
      remoteId: 'B',
      name: 'b',
      lastBatteryPercent: 90,
    );

    test('a stale live sample is not shown as live while offline', () {
      final rows = buildDeviceRows(
        devices: [primary, other],
        preferred: primary,
        online: false,
        liveBatteryPercent: 75,
      );
      expect(rows[0].battery.label, '40%');
      expect(rows[0].battery.isLive, isFalse);
      expect(rows[1].battery.label, '90%');
      expect(rows[1].battery.isLive, isFalse);
    });

    test('the streaming device shows its live level', () {
      final rows = buildDeviceRows(
        devices: [primary, other],
        preferred: primary,
        online: true,
        liveBatteryPercent: 75,
      );
      expect(rows[0].battery.label, '75%');
      expect(rows[0].battery.isLive, isTrue);
      expect(rows[1].battery.isLive, isFalse);
    });
  });
}
