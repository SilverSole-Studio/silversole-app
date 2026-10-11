import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/ble/ota/dfu_link.dart';
import 'package:silversole/core/ble/ota/dfu_protocol.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/models/imu_notify_data_model.dart';
import 'package:silversole/shared/models/ota_state.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/firmware_update_provider.dart';
import 'package:silversole/shared/providers/sole_connection_controller.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

import 'helpers/fake_dfu_sole.dart';

final _bin = Uint8List.fromList(List<int>.generate(6000, (i) => i * 13 & 0xFF));

FirmwareImage _image({String? version = '0.5.0'}) => FirmwareImage(
  bin: _bin,
  signature: Uint8List(64),
  sha256: Uint8List.fromList(sha256.convert(_bin).bytes),
  version: version,
);

const _manifest = FirmwareManifest(
  schema: 1,
  channel: 'stable',
  version: '0.5.0',
  size: 6000,
  sha256: '-',
  binPath: 'b',
  sigPath: 's',
);

const _sole = ConnectedSole(
  device: BlePairedDevice(remoteId: 'M', name: 'SilverSole', deviceId: 'ID'),
  firmwareVersion: '0.4.0',
  dfuSupported: true,
);

class _FakeConnection implements SoleConnectionController {
  _FakeConnection(this.sole);

  final FakeDfuSole sole;

  /// The session the sole comes back with; null when it never does.
  SoleSessionInfo? comesBackWith = const SoleSessionInfo(
    deviceId: 'ID',
    firmwareVersion: '0.5.0',
    dfuSupported: true,
  );
  var holds = 0;
  var releases = 0;

  @override
  void hold() => holds++;

  @override
  void release() => releases++;

  @override
  DfuLink? dfuLink() => sole;

  @override
  Future<ReacquiredSole?> reacquire(
    BlePairedDevice target, {
    required Duration timeout,
  }) async {
    final session = comesBackWith;
    return session == null
        ? null
        : ReacquiredSole(session, ReacquireConfidence.certain);
  }
}

class _FakeRelease extends FirmwareReleaseService {
  _FakeRelease(this.image);

  final FirmwareImage image;

  @override
  Future<Result<FirmwareImage>> download(FirmwareManifest manifest) async =>
      Result.ok(image);
}

/// A sole whose status characteristic throws the moment it is subscribed to —
/// a link that drops before `DfuTransfer`'s own try even starts.
class _BrokenSole extends FakeDfuSole {
  @override
  Future<Stream<List<int>>> subscribeStatus() async =>
      throw StateError('link lost');
}

/// Builds a container with [connection] and the sole connected, runs [body]
/// and lets fake time run out, then returns the final state. When [midway]
/// is given, fake time is advanced by [midwayAt] first and [midway] runs
/// before the remaining time elapses — e.g. to cancel mid-transfer.
OtaState _run(
  _FakeConnection connection,
  void Function(ProviderContainer c) body, {
  ConnectedSole? sole = _sole,
  void Function(ProviderContainer c)? midway,
  Duration midwayAt = const Duration(milliseconds: 50),
}) {
  late OtaState state;
  fakeAsync((async) {
    final container = ProviderContainer(
      overrides: [
        bleForegroundControlProvider.overrideWithValue(connection),
        keepScreenOnProvider.overrideWithValue((_) async {}),
        firmwareReleaseServiceProvider.overrideWithValue(
          _FakeRelease(_image()),
        ),
      ],
    );
    if (sole != null) container.read(connectedSoleProvider.notifier).set(sole);
    body(container);
    if (midway != null) {
      async.elapse(midwayAt);
      midway(container);
    }
    async.elapse(const Duration(minutes: 5));
    state = container.read(firmwareUpdateProvider);
    container.dispose();
  });
  return state;
}

void main() {
  test('an update that comes back on the new version succeeds', () {
    final connection = _FakeConnection(FakeDfuSole());
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.succeeded);
    expect(state.readVersion, '0.5.0');
    expect(connection.holds, 1);
    expect(connection.releases, 1);
  });

  test('coming back on the old version is not updated', () {
    final connection = _FakeConnection(FakeDfuSole())
      ..comesBackWith = const SoleSessionInfo(
        firmwareVersion: '0.4.0',
        dfuSupported: true,
      );
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.notUpdated);
  });

  test('a sole that never comes back is unconfirmed', () {
    final connection = _FakeConnection(FakeDfuSole())..comesBackWith = null;
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.unconfirmed);
    expect(connection.releases, 1);
  });

  test('a low battery is refused before anything reaches the sole', () {
    final sole = FakeDfuSole();
    final connection = _FakeConnection(sole);
    final state = _run(connection, (c) {
      c
          .read(liveTelemetryProvider.notifier)
          .updateImuNotifyData(
            const ImuNotifyDataModel(
              ax: 0,
              ay: 0,
              az: 0,
              gx: 0,
              gy: 0,
              gz: 0,
              pressure: [0, 0, 0],
              batteryPercent: 20,
              isCharging: false,
            ),
          );
      c.read(firmwareUpdateProvider.notifier).installRelease(_manifest);
    });
    expect(state.failure, DfuFailure.lowBattery);
    expect(sole.controlWrites, isEmpty);
    expect(connection.holds, 0);
  });

  test('BAD_SIGNATURE is final, and the link is released', () {
    final connection = _FakeConnection(
      FakeDfuSole()..applyAnswers.add(DfuResult.badSignature),
    );
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.failed);
    expect(state.failure, DfuFailure.badSignature);
    expect(state.failure!.retryable, isFalse);
    expect(connection.releases, 1);
  });

  test('a local image reports the version the sole booted with', () {
    final connection = _FakeConnection(FakeDfuSole())
      ..comesBackWith = const SoleSessionInfo(
        firmwareVersion: '0.6.0-dev.1',
        dfuSupported: true,
      );
    final state = _run(
      connection,
      (c) => c
          .read(firmwareUpdateProvider.notifier)
          .installLocal(_image(version: null)),
    );
    expect(state.phase, OtaPhase.localFinished);
    expect(state.fromVersion, '0.4.0');
    expect(state.readVersion, '0.6.0-dev.1');
  });

  test('without a connected sole nothing starts', () {
    final connection = _FakeConnection(FakeDfuSole());
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
      sole: null,
    );
    expect(state.failure, DfuFailure.notConnected);
    expect(connection.holds, 0);
  });

  test('a throw from the link itself does not leave the update stuck busy', () {
    final connection = _FakeConnection(_BrokenSole());
    final state = _run(
      connection,
      (c) => c.read(firmwareUpdateProvider.notifier).installRelease(_manifest),
    );
    expect(state.phase, OtaPhase.failed);
    expect(state.failure, DfuFailure.disconnected);
    expect(state.busy, isFalse);
    expect(connection.releases, 1);
  });

  test(
    'cancelling during a transfer ends in failed(cancelled) and aborts the sole',
    () {
      final sole = FakeDfuSole();
      final connection = _FakeConnection(sole);
      late FirmwareUpdateNotifier notifier;
      final state = _run(connection, (c) {
        notifier = c.read(firmwareUpdateProvider.notifier);
        notifier.installRelease(_manifest);
      }, midway: (c) => notifier.cancel());
      expect(state.phase, OtaPhase.failed);
      expect(state.failure, DfuFailure.cancelled);
      expect(connection.releases, 1);
      expect(sole.controlWrites, contains(equals(const [0x03])));
    },
  );
}
