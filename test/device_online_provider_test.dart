import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/firmware_update_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';

ImuNotifyDataModel _sample() => const ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: [0, 0, 0],
  batteryPercent: 100,
  isCharging: false,
);

void main() {
  test(
    'offline with no telemetry, online on data, auto-offline after window',
    () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // build() runs and registers the telemetry listener.
        expect(container.read(deviceOnlineProvider), isFalse);

        final live = container.read(liveTelemetryProvider('A').notifier);

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
    },
  );

  // With two feet "online" means either one is reporting: a sole that goes
  // quiet must not drag the wearable offline while the other keeps feeding.
  test('two soles: online while either one keeps reporting', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(deviceOnlineProvider), isFalse);

      final left = container.read(liveTelemetryProvider('L').notifier);
      final right = container.read(liveTelemetryProvider('R').notifier);

      left.updateImuNotifyData(_sample());
      right.updateImuNotifyData(_sample());
      async.flushMicrotasks();
      expect(container.read(deviceOnlineProvider), isTrue);

      // Only the right sole keeps feeding; the left one is silent for longer
      // than the window by the time we check.
      async.elapse(TelemetryFacade.onlineWindow - const Duration(seconds: 1));
      right.updateImuNotifyData(_sample());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      expect(container.read(deviceOnlineProvider), isTrue);

      // Now both are silent past the window.
      async.elapse(TelemetryFacade.onlineWindow);
      expect(container.read(deviceOnlineProvider), isFalse);
    });
  });

  test('a sole being updated stays online while its stream is paused', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [firmwareUpdateProvider.overrideWith(_UpdatingNotifier.new)],
      );
      addTearDown(container.dispose);

      expect(container.read(deviceOnlineProvider), isTrue);
      async.elapse(TelemetryFacade.onlineWindow * 3);
      expect(container.read(deviceOnlineProvider), isTrue);
    });
  });
}

class _UpdatingNotifier extends FirmwareUpdateNotifier {
  @override
  OtaState build() => const OtaState(phase: OtaPhase.transferring);
}
