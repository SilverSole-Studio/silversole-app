import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';

/// Settings a test can drive directly, skipping the shared_preferences load.
class _Settings extends SettingsNotifier {
  _Settings(this._initial);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  void swap(AppSettings next) => state = next;
}

BlePairedDevice _sole(String id, {FootSide? side, bool preferred = false}) =>
    BlePairedDevice(
      remoteId: 'addr-$id',
      name: 'SilverSole',
      deviceId: id,
      footSide: side,
      isPreferred: preferred,
    );

ImuNotifyDataModel _imu(List<int> pressure) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: pressure,
  batteryPercent: 90,
  isCharging: false,
);

void main() {
  // Everything the two-foot graph decides, asserted on one container in one
  // pass. Split across files or across tests, each of this branch's two
  // Criticals passed its own neighbours' tests and only showed up in the
  // combination: the card that named one sole and showed another's, and the
  // right foot drawn as bearing zero load with no sole on it.
  testWidgets('two calibrated soles: the whole graph agrees on which is which', (
    tester,
  ) async {
    final settings = _Settings(
      AppSettings(
        pairedDevicesList: [
          // Preferred *and* on the left foot: the case the old right-foot-first
          // ordering made unreachable.
          _sole('L', side: FootSide.left, preferred: true),
          _sole('R', side: FootSide.right),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(() => settings)],
    );
    addTearDown(container.dispose);

    container.read(connectedSolesProvider.notifier)
      ..set(
        'L',
        ConnectedSole(
          device: _sole('L', side: FootSide.left),
          dfuSupported: true,
        ),
      )
      ..set(
        'R',
        ConnectedSole(
          device: _sole('R', side: FootSide.right),
          dfuSupported: true,
        ),
      );

    // One clock for stamping and for reading, so "fresh" means the same thing
    // to the notifier and to `checkDeviceOnline`. Advanced by hand in step
    // with `tester.pump`, which drives the provider's own timers.
    var now = DateTime(2026, 10, 20, 9);
    await withClock(Clock(() => now), () async {
      // `clock.now()` and the fake-async timer wheel are separate clocks, and
      // `deviceOnlineProvider` reads one while arming a Timer on the other.
      // Let them drift and it reports nonsense, so only ever move both.
      Future<void> advance(Duration d) async {
        now = now.add(d);
        await tester.pump(d);
      }

      PressureReading? reading;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            home: Scaffold(
              body: PressureDemoScope(
                builder: (context, r, header) {
                  reading = r;
                  return header;
                },
              ),
            ),
          ),
        ),
      );

      // Nothing has streamed yet: offline, and the right foot reads as absent
      // rather than as a foot measuring nothing.
      expect(container.read(deviceOnlineProvider), isFalse);
      expect(reading!.hasData, isFalse);
      expect(reading!.left, isNull);

      container
          .read(liveTelemetryProvider('L').notifier)
          .updateImuNotifyData(_imu(const [11, 22, 33]));
      container
          .read(liveTelemetryProvider('R').notifier)
          .updateImuNotifyData(_imu(const [44, 55, 66]));
      await tester.pump();

      // 1. The wearer's pick decides which sole "the sole" means — not the
      //    right foot. Reversed, the left sole's firmware can never be
      //    checked or updated and "set as primary" does nothing.
      expect(container.read(primarySoleKeyProvider), 'L');
      expect(container.read(connectedSoleProvider)?.device.identityKey, 'L');

      // 2. Every pre-two-feet screen follows that same sole, so the IMU
      //    charts, the game page and recording all read the left sole here.
      expect(container.read(telemetryViewProvider).recentImu.last.pressure, [
        11,
        22,
        33,
      ]);

      // 3. "Any sole is online" — which is why a card that names one sole
      //    cannot use it.
      expect(container.read(deviceOnlineProvider), isTrue);
      final facade = container.read(telemetryFacadeProvider);
      final leftAt = container.read(liveTelemetryProvider('L')).updatedAt;
      final rightAt = container.read(liveTelemetryProvider('R')).updatedAt;
      expect(facade.checkDeviceOnline(leftAt), isTrue);
      expect(facade.checkDeviceOnline(rightAt), isTrue);

      // 4. The heat map is keyed off the feet, not off the primary sole: each
      //    foot draws the sole worn on it even though the primary is the left.
      expect(reading!.right, [44, 55, 66]);
      expect(reading!.left, [11, 22, 33]);
      expect(reading!.hasData, isTrue);

      // Past the online window with neither sole reporting.
      await advance(const Duration(seconds: 40));
      expect(container.read(deviceOnlineProvider), isFalse);

      // Only the left sole comes back. "Any sole is online" flips to true and
      // stays there, which is exactly why a card that names *one* sole cannot
      // read it: the right foot has been silent for 40 s.
      container
          .read(liveTelemetryProvider('L').notifier)
          .updateImuNotifyData(_imu(const [12, 23, 34]));
      await tester.pump();

      expect(container.read(deviceOnlineProvider), isTrue);
      expect(
        facade.checkDeviceOnline(
          container.read(liveTelemetryProvider('L')).updatedAt,
        ),
        isTrue,
      );
      expect(
        facade.checkDeviceOnline(
          container.read(liveTelemetryProvider('R')).updatedAt,
        ),
        isFalse,
      );

      // Unpair the right sole. The left one is still streaming, so there is
      // data on screen — but nothing is feeding the *right* foot, and it must
      // read as absent. `hasData` covering "either foot" is what drew it as a
      // foot bearing no load, and "this foot takes no weight" is a clinical
      // statement the wearer cannot tell apart from "no sole on".
      settings.swap(
        AppSettings(
          pairedDevicesList: [_sole('L', side: FootSide.left, preferred: true)],
        ),
      );
      await tester.pump();

      expect(reading!.hasData, isFalse);
      expect(reading!.left, [12, 23, 34]);
      expect(container.read(primarySoleKeyProvider), 'L');
      expect(container.read(deviceOnlineProvider), isTrue);

      // Both feet silent: offline. Also drains `deviceOnlineProvider`'s
      // one-shot timer, which the widget-test binding checks for before the
      // container's tearDown gets to cancel it.
      await advance(const Duration(seconds: 40));
      expect(container.read(deviceOnlineProvider), isFalse);
    });
  });
}
