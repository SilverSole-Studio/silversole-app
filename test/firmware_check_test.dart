import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/dfu_failure.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/models/firmware_manifest.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';

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
}
