// test/foot_side_calibration_overlay_test.dart
import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/pages/foot_side_calibration_modal.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

const _left = BlePairedDevice(
  remoteId: 'l',
  name: 'SilverSole',
  deviceId: '00000000000000AA',
);
const _right = BlePairedDevice(
  remoteId: 'r',
  name: 'SilverSole',
  deviceId: '00000000000000BB',
);

/// Settings that assign in memory, so the test never touches
/// shared_preferences. [assignFootSide] is the same pure function the real
/// notifier persists through.
class _Settings extends SettingsNotifier {
  /// Throws once from [setFootSide], like a failed write to disk.
  bool failNext = false;

  @override
  AppSettings build() => const AppSettings(pairedDevicesList: [_left, _right]);

  @override
  Future<void> setFootSide(String identityKey, FootSide? side) async {
    if (failNext) {
      failNext = false;
      throw StateError('disk full');
    }
    state = state.copyWith(
      pairedDevicesList: assignFootSide(
        state.pairedDevicesList,
        identityKey,
        side,
      ),
    );
  }
}

ImuNotifyDataModel _imu(int load) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 1000,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: [load, load, load],
  batteryPercent: 80,
  isCharging: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One EasyLocalization mount per file: it keeps global state, so a second
  // mount never leaves its loading state.
  testWidgets('stepping on a sole makes it the left foot', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    final container = ProviderContainer(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
    );
    addTearDown(container.dispose);

    // Both feet connected, neither with a side yet.
    container.read(connectedSolesProvider.notifier)
      ..set(
        _left.identityKey,
        const ConnectedSole(device: _left, dfuSupported: false),
      )
      ..set(
        _right.identityKey,
        const ConnectedSole(device: _right, dfuSupported: false),
      );

    await tester.runAsync(
      () => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
            path: 'assets/translations/strings.csv',
            assetLoader: CsvAssetLoader(),
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: Builder(
              builder: (context) => MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appTheme(Brightness.light),
                home: const FootSideCalibrationOverlay(
                  child: Scaffold(body: SizedBox()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // It asks, unprompted, as soon as the second foot is on.
    expect(find.text('Step on your left foot'), findsOneWidget);

    // 50 Hz frames with a fake clock, because the calibrator arbitrates on
    // sample timestamps rather than on arrival order.
    var now = DateTime(2026, 10, 20, 9);
    void frame({required int left, required int right}) {
      now = now.add(const Duration(milliseconds: 20));
      withClock(Clock(() => now), () {
        container
            .read(liveTelemetryProvider(_left.identityKey).notifier)
            .updateImuNotifyData(_imu(left));
        container
            .read(liveTelemetryProvider(_right.identityKey).notifier)
            .updateImuNotifyData(_imu(right));
      });
    }

    // A write that fails must not leave a panel that looks alive but ignores
    // everything. The step comes first, before any save has succeeded.
    final settings = container.read(settingsProvider.notifier) as _Settings
      ..failNext = true;
    for (var i = 0; i < 60; i++) {
      frame(left: 0, right: 0);
    }
    for (var i = 0; i < 40; i++) {
      frame(left: 0, right: 2000);
    }
    await tester.pumpAndSettle();
    expect(find.text('Step on your left foot'), findsOneWidget);
    expect(settings.failNext, isFalse, reason: 'the failing write ran');
    expect(
      container
          .read(settingsProvider)
          .pairedDevicesList
          .every((d) => d.footSide == null),
      isTrue,
    );

    // The by-hand button, not Retry: Retry resets the saving flag itself, so
    // it would pass even without the `finally` this pins.
    await tester.pump(const Duration(seconds: 15));
    await tester.tap(find.text('This is my left').last);
    await tester.pumpAndSettle();
    expect(
      container
          .read(settingsProvider)
          .pairedDevicesList
          .firstWhere((d) => d.identityKey == _right.identityKey)
          .footSide,
      FootSide.left,
    );
    expect(find.text('Step on your left foot'), findsNothing);

    // Undo it, so the question comes back and the step itself is covered too.
    await settings.setFootSide(_left.identityKey, null);
    await settings.setFootSide(_right.identityKey, null);
    await tester.pumpAndSettle();
    expect(find.text('Step on your left foot'), findsOneWidget);

    // A second of standing still fills both baselines.
    for (var i = 0; i < 60; i++) {
      frame(left: 0, right: 0);
    }
    // Then a step on the second-listed sole, so "first sole" cannot pass by
    // luck, well past the arbitration window.
    for (var i = 0; i < 40; i++) {
      frame(left: 0, right: 2000);
    }
    await tester.pumpAndSettle();

    final paired = container.read(settingsProvider).pairedDevicesList;
    expect(
      paired.firstWhere((d) => d.identityKey == _right.identityKey).footSide,
      FootSide.left,
    );
    expect(
      paired.firstWhere((d) => d.identityKey == _left.identityKey).footSide,
      FootSide.right,
    );

    // Answered, so the overlay gets out of the way.
    expect(find.text('Step on your left foot'), findsNothing);
  });
}
