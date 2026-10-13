import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/data/firmware_release_service.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

/// Developer mode off, with no shared_preferences load — `build()` never
/// calls `_load()`, so no plugin needs to be mocked in this unit test file.
class _TestSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

/// Counts `fetchManifest` calls, to prove a reconnect that does not change
/// identity, version or DFU support does not refetch.
class _CountingRelease extends FirmwareReleaseService {
  var fetchCount = 0;

  @override
  Future<Result<FirmwareManifest>> fetchManifest(
    FirmwareChannel channel,
  ) async {
    fetchCount++;
    return _server('0.4.0');
  }
}

ConnectedSole _sole({String? version = '0.4.0', bool dfu = true}) =>
    ConnectedSole(
      device: const BlePairedDevice(
        remoteId: 'M',
        name: 'SilverSole',
        deviceId: 'ID',
      ),
      firmwareVersion: version,
      dfuSupported: dfu,
    );

Result<FirmwareManifest> _server(String version, {int schema = 1}) => Result.ok(
  FirmwareManifest(
    schema: schema,
    channel: 'stable',
    version: version,
    size: 1,
    sha256: '00',
    binPath: 'b',
    sigPath: 's',
  ),
);

FirmwareCheckStatus _status(
  String server, {
  String device = '0.4.0',
  bool devMode = false,
}) => evaluateManifest(
  _sole(version: device),
  _server(server),
  devMode: devMode,
).status;

void main() {
  group('firmwarePrecheck', () {
    test('nothing to check without a connected sole', () {
      expect(firmwarePrecheck(null)?.status, FirmwareCheckStatus.notConnected);
    });

    test('firmware without the DFU service needs a wired update', () {
      expect(
        firmwarePrecheck(_sole(dfu: false))?.status,
        FirmwareCheckStatus.needsWiredUpdate,
      );
    });

    test('a version that is not semver is never offered an update', () {
      expect(
        firmwarePrecheck(_sole(version: 'abc'))?.status,
        FirmwareCheckStatus.versionUnreadable,
      );
      expect(
        firmwarePrecheck(_sole(version: null))?.status,
        FirmwareCheckStatus.versionUnreadable,
      );
    });

    test('a readable version goes on to the server', () {
      expect(firmwarePrecheck(_sole()), isNull);
    });
  });

  group('evaluateManifest', () {
    test('a newer release is offered, with its manifest', () {
      final check = evaluateManifest(_sole(), _server('0.5.0'), devMode: false);
      expect(check.status, FirmwareCheckStatus.updateAvailable);
      expect(check.manifest?.version, '0.5.0');
    });

    test('a release outranks its own release candidate', () {
      expect(
        _status('0.4.0', device: '0.4.0-rc.1'),
        FirmwareCheckStatus.updateAvailable,
      );
    });

    test('the same version is up to date', () {
      expect(_status('0.4.0'), FirmwareCheckStatus.upToDate);
    });

    test('an older release is never offered outside developer mode', () {
      expect(_status('0.3.0'), FirmwareCheckStatus.upToDate);
      expect(
        _status('0.3.0', devMode: true),
        FirmwareCheckStatus.downgradeAvailable,
      );
    });

    test('a manifest schema this app does not know is not trusted', () {
      final check = evaluateManifest(
        _sole(),
        _server('0.5.0', schema: 2),
        devMode: false,
      );
      expect(check.status, FirmwareCheckStatus.manifestUnsupported);
    });

    test('a server version that is not semver is not trusted', () {
      expect(_status('latest'), FirmwareCheckStatus.manifestUnsupported);
    });

    test('a failed fetch can be retried', () {
      final check = evaluateManifest(
        _sole(),
        const Result.error(DfuException(DfuFailure.manifestUnavailable)),
        devMode: false,
      );
      expect(check.status, FirmwareCheckStatus.checkFailed);
    });
  });

  group('firmwareCheckProvider', () {
    test(
      'a reconnect that only updates lastConnectedAt does not refetch',
      () async {
        final release = _CountingRelease();
        final container = ProviderContainer(
          overrides: [
            firmwareReleaseServiceProvider.overrideWithValue(release),
            settingsProvider.overrideWith(_TestSettings.new),
          ],
        );
        addTearDown(container.dispose);

        final sole = _sole();
        container.read(connectedSoleProvider.notifier).set(sole);
        await container.read(firmwareCheckProvider.future);
        expect(release.fetchCount, 1);

        final reconnected = sole.copyWith(
          device: sole.device.copyWith(lastConnectedAt: DateTime.now()),
        );
        container.read(connectedSoleProvider.notifier).set(reconnected);
        await container.read(firmwareCheckProvider.future);
        expect(release.fetchCount, 1);
      },
    );
  });
}
