import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/widgets/firmware_card_parts.dart';

const _device = BlePairedDevice(
  remoteId: 'M',
  name: 'SilverSole',
  deviceId: '1A2B3C4D5E6F7081',
);

void main() {
  test('the card names the sole by its ID suffix, then its version', () {
    const check = FirmwareCheck(
      FirmwareCheckStatus.upToDate,
      sole: ConnectedSole(
        device: _device,
        firmwareVersion: '0.4.0',
        dfuSupported: true,
      ),
    );
    expect(firmwareCardDetail(check), 'SilverSole ••••7081 · v0.4.0');
  });

  test('a sole without an ID is named alone', () {
    expect(soleLabel(const BlePairedDevice(remoteId: 'M', name: '左腳')), '左腳');
  });

  test('nothing to describe without a sole', () {
    expect(firmwareCardDetail(null), isNull);
    expect(
      firmwareCardDetail(const FirmwareCheck(FirmwareCheckStatus.notConnected)),
      isNull,
    );
  });

  test('each check maps to one card action', () {
    FirmwareCardAction of(FirmwareCheckStatus s) =>
        firmwareCardAction(FirmwareCheck(s));
    expect(of(FirmwareCheckStatus.notConnected), FirmwareCardAction.none);
    expect(of(FirmwareCheckStatus.upToDate), FirmwareCardAction.upToDate);
    expect(of(FirmwareCheckStatus.updateAvailable), FirmwareCardAction.update);
    expect(
      of(FirmwareCheckStatus.downgradeAvailable),
      FirmwareCardAction.downgrade,
    );
    expect(
      of(FirmwareCheckStatus.needsWiredUpdate),
      FirmwareCardAction.needsWiredUpdate,
    );
    expect(
      of(FirmwareCheckStatus.versionUnreadable),
      FirmwareCardAction.versionUnreadable,
    );
    expect(of(FirmwareCheckStatus.checkFailed), FirmwareCardAction.retry);
    expect(
      of(FirmwareCheckStatus.manifestUnsupported),
      FirmwareCardAction.appTooOld,
    );
  });
}
