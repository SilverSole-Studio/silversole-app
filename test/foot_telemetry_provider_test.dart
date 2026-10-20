import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/foot_telemetry_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

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

ImuNotifyDataModel _imu(int pressure) => ImuNotifyDataModel(
  ax: 0,
  ay: 0,
  az: 0,
  gx: 0,
  gy: 0,
  gz: 0,
  pressure: [pressure, pressure, pressure],
  batteryPercent: 90,
  isCharging: false,
);

ProviderContainer _boot(List<BlePairedDevice> paired) {
  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        () => _Settings(AppSettings(pairedDevicesList: paired)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

_Settings _settingsOf(ProviderContainer container) =>
    container.read(settingsProvider.notifier) as _Settings;

void main() {
  test('a foot with no sole assigned reads empty telemetry', () {
    final container = _boot([_sole('A')]);
    expect(
      container.read(footTelemetryProvider(FootSide.left)).recentImu,
      isEmpty,
    );
    expect(container.read(footSoleKeyProvider(FootSide.left)), isNull);
  });

  test('telemetry reaches only the foot its sole is assigned to', () {
    final container = _boot([
      _sole('L', side: FootSide.left),
      _sole('R', side: FootSide.right),
    ]);

    container
        .read(liveTelemetryProvider('L').notifier)
        .updateImuNotifyData(_imu(700));

    expect(
      container
          .read(footTelemetryProvider(FootSide.left))
          .recentImu
          .last
          .pressure,
      [700, 700, 700],
    );
    expect(
      container.read(footTelemetryProvider(FootSide.right)).recentImu,
      isEmpty,
    );
  });

  test('the primary sole is the right foot when one is assigned', () {
    final container = _boot([
      _sole('L', side: FootSide.left, preferred: true),
      _sole('R', side: FootSide.right),
    ]);
    expect(container.read(primarySoleKeyProvider), 'R');
  });

  test('with no side assigned the primary sole is the preferred device', () {
    final container = _boot([_sole('A'), _sole('B', preferred: true)]);
    expect(container.read(primarySoleKeyProvider), 'B');
  });

  test('with neither, the first paired sole is primary', () {
    final container = _boot([_sole('A'), _sole('B')]);
    expect(container.read(primarySoleKeyProvider), 'A');
  });

  test('nothing paired means no primary and empty telemetry', () {
    final container = _boot(const []);
    expect(container.read(primarySoleKeyProvider), isNull);
    expect(container.read(primaryTelemetryProvider).recentImu, isEmpty);
  });

  // Unpair (or re-assign) the left sole and the left foot has to go back to a
  // bare outline. Leaving the last reading on screen would show the wearer
  // pressure from a sole that is no longer theirs.
  test('losing the left sole empties the left foot again', () {
    final container = _boot([
      _sole('L', side: FootSide.left),
      _sole('R', side: FootSide.right),
    ]);
    container
        .read(liveTelemetryProvider('L').notifier)
        .updateImuNotifyData(_imu(700));
    expect(
      container.read(footTelemetryProvider(FootSide.left)).recentImu,
      isNotEmpty,
    );

    _settingsOf(
      container,
    ).swap(AppSettings(pairedDevicesList: [_sole('R', side: FootSide.right)]));

    expect(
      container.read(footTelemetryProvider(FootSide.left)).recentImu,
      isEmpty,
    );
  });

  // The real clock only moves forward, so a last-writer-wins implementation
  // would pass on it too. Stamping the second sole *earlier* is what tells
  // "newest across soles" apart from "whoever wrote last".
  test('the newest stamp across soles is what latestTelemetryAt reports', () {
    final container = _boot([
      _sole('L', side: FootSide.left),
      _sole('R', side: FootSide.right),
    ]);
    expect(container.read(latestTelemetryAtProvider), isNull);

    final later = DateTime(2026, 10, 20, 12, 0, 10);
    withClock(Clock.fixed(later), () {
      container
          .read(liveTelemetryProvider('R').notifier)
          .updateImuNotifyData(_imu(1));
    });
    expect(container.read(latestTelemetryAtProvider), later);

    withClock(Clock.fixed(later.subtract(const Duration(seconds: 5))), () {
      container
          .read(liveTelemetryProvider('L').notifier)
          .updateImuNotifyData(_imu(2));
    });
    expect(container.read(latestTelemetryAtProvider), later);
  });

  group('rightFootTelemetryProvider', () {
    test('uses the sole assigned to the right foot', () {
      final container = _boot([
        _sole('L', side: FootSide.left),
        _sole('R', side: FootSide.right),
      ]);
      container
          .read(liveTelemetryProvider('R').notifier)
          .updateImuNotifyData(_imu(500));
      expect(
        container.read(rightFootTelemetryProvider).recentImu.last.pressure,
        [500, 500, 500],
      );
    });

    // One uncalibrated sole has always drawn the right foot, and still must:
    // this is the single-sole case the whole app shipped with.
    test('an uncalibrated single sole still draws the right foot', () {
      final container = _boot([_sole('A')]);
      container
          .read(liveTelemetryProvider('A').notifier)
          .updateImuNotifyData(_imu(300));
      expect(
        container.read(rightFootTelemetryProvider).recentImu.last.pressure,
        [300, 300, 300],
      );
    });

    // The left sole's data must never be drawn on the right foot just because
    // it happens to be the only one paired.
    test('a lone left sole leaves the right foot empty', () {
      final container = _boot([_sole('L', side: FootSide.left)]);
      container
          .read(liveTelemetryProvider('L').notifier)
          .updateImuNotifyData(_imu(300));
      expect(container.read(rightFootTelemetryProvider).recentImu, isEmpty);
      expect(
        container.read(footTelemetryProvider(FootSide.left)).recentImu,
        isNotEmpty,
      );
    });
  });
}
