import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

void main() {
  final facade = TelemetryFacade();
  final base = DateTime(2030, 1, 1, 12, 0, 0);

  test('null timestamp is offline', () {
    expect(facade.checkDeviceOnline(null), isFalse);
  });

  test('within the online window is online', () {
    withClock(Clock.fixed(base), () {
      final fresh = base.subtract(TelemetryFacade.onlineWindow ~/ 2);
      expect(facade.checkDeviceOnline(fresh), isTrue);
    });
  });

  test('past the online window is offline', () {
    withClock(Clock.fixed(base), () {
      final stale = base.subtract(
        TelemetryFacade.onlineWindow + const Duration(seconds: 1),
      );
      expect(facade.checkDeviceOnline(stale), isFalse);
    });
  });
}
