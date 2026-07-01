import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

ImuNotifyDataModel _sample() => const ImuNotifyDataModel(
      ax: 0, ay: 0, az: 0, gx: 0, gy: 0, gz: 0,
      pressure: [0, 0, 0], batteryPercent: 100, isCharging: false,
    );

void main() {
  test('offline with no telemetry, online on data, auto-offline after window', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // build() runs and registers the telemetry listener.
      expect(container.read(deviceOnlineProvider), isFalse);

      final live = container.read(liveTelemetryProvider.notifier);

      live.updateImuNotifyData(_sample());
      async.flushMicrotasks();
      expect(container.read(deviceOnlineProvider), isTrue);

      async.elapse(TelemetryFacade.onlineWindow - const Duration(seconds: 1));
      expect(container.read(deviceOnlineProvider), isTrue);

      async.elapse(const Duration(seconds: 2)); // now past the window
      expect(container.read(deviceOnlineProvider), isFalse);

      // Fresh telemetry brings it back online immediately.
      live.updateImuNotifyData(_sample());
      async.flushMicrotasks();
      expect(container.read(deviceOnlineProvider), isTrue);
    });
  });
}
