import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_history.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/fall_detect_event_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

import 'helpers/gait_signal.dart';

ImuNotifyDataModel _imu(List<int> pressure) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: pressure,
  batteryPercent: 100,
  isCharging: false,
);

/// Streams a twenty-contact walk onto the bus in fake time, one sample per
/// 20 ms, so the tracker's `clock.now()` stamps match the signal.
void _walk(FakeAsync async, SoleSampleBus bus, {String key = 'R'}) {
  final samples = footSignal(
    origin: clock.now(),
    length: const Duration(seconds: 25),
    contacts: walkContacts(count: 20),
  );
  for (final s in samples) {
    async.elapse(const Duration(milliseconds: 20));
    bus.emit(SoleSample(identityKey: key, data: _imu(s.pressure)));
  }
}

class _LeftSolePaired extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(
    pairedDevicesList: [
      BlePairedDevice(
        deviceId: 'AABBCCDDEEFF0011',
        remoteId: 'AA:BB:CC:DD:EE:FF',
        name: 'SilverSole',
        footSide: FootSide.left,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('samples on the bus reach the stored history within five minutes', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [realGaitEnabledProvider.overrideWithValue(true)],
      );
      container.read(gaitTrackingProvider);
      async.flushMicrotasks();

      _walk(async, container.read(soleSampleBusProvider));
      async.elapse(gaitFlushInterval);
      async.flushMicrotasks();

      final today = gaitDateKey(clock.now());
      expect(container.read(gaitHistoryProvider)[today]?.steps, 40);
      container.dispose();
    });
  });

  test('a sole assigned to the left foot is filed under left', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          realGaitEnabledProvider.overrideWithValue(true),
          settingsProvider.overrideWith(_LeftSolePaired.new),
        ],
      );
      container.read(gaitTrackingProvider);
      async.flushMicrotasks();

      _walk(
        async,
        container.read(soleSampleBusProvider),
        key: 'AABBCCDDEEFF0011',
      );
      async.elapse(gaitFlushInterval);
      async.flushMicrotasks();

      final today = container.read(
        gaitHistoryProvider,
      )[gaitDateKey(clock.now())];
      expect(today?.feet[GaitFoot.left]?.contacts, 20);
      expect(today?.feet.containsKey(GaitFoot.unknown), isFalse);
      container.dispose();
    });
  });

  test('switched off, nothing is tracked', () {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [realGaitEnabledProvider.overrideWithValue(false)],
      );
      container.read(gaitTrackingProvider);
      async.flushMicrotasks();

      _walk(async, container.read(soleSampleBusProvider));
      async.elapse(gaitFlushInterval);
      async.flushMicrotasks();

      expect(container.read(gaitHistoryProvider), isEmpty);
      container.dispose();
    });
  });

  test('history added before the stored one loads is not lost', () async {
    final stored = {
      '2026-11-01': const DailyGait(date: '2026-11-01', steps: 7),
    };
    SharedPreferences.setMockInitialValues({
      LocalSavableKey.gaitHistory.value: encodeGaitHistory(stored),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await withClock(Clock.fixed(DateTime(2026, 11, 2, 9)), () async {
      await container.read(gaitHistoryProvider.notifier).add([
        const DailyGait(date: '2026-11-02', steps: 3),
      ]);
    });

    final history = container.read(gaitHistoryProvider);
    expect(history['2026-11-01']?.steps, 7);
    expect(history['2026-11-02']?.steps, 3);
    final saved = decodeGaitHistory(
      await loadLocalValue(LocalSavableKey.gaitHistory),
    );
    expect(saved.keys, containsAll(['2026-11-01', '2026-11-02']));
  });

  test('falls are counted from the moment the provider starts', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(fallCountSinceOpenProvider), 0);

    container
        .read(fallEventBusProvider)
        .emit(
          FallDetectEvent(
            timestamp: DateTime(2026, 11, 2),
            deviceId: 'R',
            detect: true,
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(fallCountSinceOpenProvider), 1);
  });
}
