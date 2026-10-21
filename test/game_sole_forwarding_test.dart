import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/sole_sample_bus.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/providers/game_sole_forwarding.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

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
  pitch: 1,
  roll: 2,
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

/// The `onSoleSample` payload of a forwarded script.
Map<String, dynamic> _payload(String script) {
  final match = RegExp(
    r'^window\.onSoleSample \? onSoleSample\((.*?)\) : ',
  ).firstMatch(script);
  expect(match, isNotNull, reason: 'unexpected script shape: $script');
  return jsonDecode(match!.group(1)!) as Map<String, dynamic>;
}

/// Collects every script the forwarding stream produces.
List<String> _collect(ProviderContainer container) {
  final scripts = <String>[];
  final sub = container.read(gameSoleScriptsProvider).listen(scripts.add);
  addTearDown(sub.cancel);
  return scripts;
}

void main() {
  test(
    'both soles are forwarded, each with its own foot and primary flag',
    () async {
      final container = _boot([
        _sole('L', side: FootSide.left),
        _sole('R', side: FootSide.right, preferred: true),
      ]);
      final scripts = _collect(container);
      final bus = container.read(soleSampleBusProvider);

      bus.emit(SoleSample(identityKey: 'L', data: _imu(100)));
      bus.emit(SoleSample(identityKey: 'R', data: _imu(200)));
      bus.emit(SoleSample(identityKey: 'L', data: _imu(300)));
      await pumpEventQueue();

      final payloads = scripts.map(_payload).toList();
      expect(payloads.map((p) => p['foot']), ['left', 'right', 'left']);
      expect(payloads.map((p) => p['primary']), [false, true, false]);
      expect(payloads.map((p) => p['pressure']), [
        [100, 100, 100],
        [200, 200, 200],
        [300, 300, 300],
      ]);
      // Only the primary sole may fall back to the legacy single-sole entry.
      expect(scripts[0], contains(': (false && window.onImuData'));
      expect(scripts[1], contains(': (true && window.onImuData'));
    },
  );

  test('an unassigned sole is sent with foot null', () async {
    final container = _boot([_sole('A'), _sole('B')]);
    final scripts = _collect(container);

    container
        .read(soleSampleBusProvider)
        .emit(SoleSample(identityKey: 'B', data: _imu(10)));
    await pumpEventQueue();

    final payload = _payload(scripts.single);
    expect(payload['foot'], isNull);
    // No primary device and no right foot: the first paired sole is primary.
    expect(payload['primary'], isFalse);
  });

  test('foot side and primary are looked up per sample, not cached', () async {
    final container = _boot([_sole('A'), _sole('B')]);
    final scripts = _collect(container);
    final bus = container.read(soleSampleBusProvider);

    bus.emit(SoleSample(identityKey: 'B', data: _imu(1)));
    await pumpEventQueue();

    (container.read(settingsProvider.notifier) as _Settings).swap(
      AppSettings(
        pairedDevicesList: [
          _sole('A', side: FootSide.left),
          _sole('B', side: FootSide.right, preferred: true),
        ],
      ),
    );
    bus.emit(SoleSample(identityKey: 'B', data: _imu(2)));
    await pumpEventQueue();

    expect(scripts.map(_payload).map((p) => p['foot']), [null, 'right']);
    expect(scripts.map(_payload).map((p) => p['primary']), [false, true]);
  });

  test('a sample from a sole that is not paired is still forwarded', () async {
    final container = _boot([_sole('A')]);
    final scripts = _collect(container);

    container
        .read(soleSampleBusProvider)
        .emit(SoleSample(identityKey: 'GONE', data: _imu(5)));
    await pumpEventQueue();

    final payload = _payload(scripts.single);
    expect(payload['foot'], isNull);
    expect(payload['primary'], isFalse);
  });

  test('the bus closes with its container', () async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => _Settings(const AppSettings())),
      ],
    );
    final done = Completer<void>();
    container
        .read(soleSampleBusProvider)
        .stream
        .listen(null, onDone: done.complete);
    container.dispose();
    await done.future.timeout(const Duration(seconds: 1));
  });
}
