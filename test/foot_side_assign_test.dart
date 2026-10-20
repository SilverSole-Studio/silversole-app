import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';

BlePairedDevice _sole(String id, {FootSide? side}) => BlePairedDevice(
  remoteId: 'addr-$id',
  name: 'SilverSole',
  deviceId: id,
  footSide: side,
);

FootSide? _sideOf(List<BlePairedDevice> list, String id) =>
    list.firstWhere((d) => d.deviceId == id).footSide;

AppSettings _settingsWith(List<BlePairedDevice> soles) =>
    AppSettings(pairedDevicesList: soles);

void main() {
  group('assignFootSide', () {
    test('assigns the side to the target sole', () {
      final out = assignFootSide([_sole('A'), _sole('B')], 'A', FootSide.left);
      expect(_sideOf(out, 'A'), FootSide.left);
      expect(_sideOf(out, 'B'), isNull);
    });

    test('one foot cannot have two soles: the previous holder is cleared', () {
      final out = assignFootSide(
        [_sole('A', side: FootSide.left), _sole('B')],
        'B',
        FootSide.left,
      );
      expect(_sideOf(out, 'A'), isNull);
      expect(_sideOf(out, 'B'), FootSide.left);
    });

    test('assigning one side leaves the other side alone', () {
      final out = assignFootSide(
        [_sole('A', side: FootSide.right), _sole('B')],
        'B',
        FootSide.left,
      );
      expect(_sideOf(out, 'A'), FootSide.right);
      expect(_sideOf(out, 'B'), FootSide.left);
    });

    test('null clears only the target', () {
      final out = assignFootSide(
        [_sole('A', side: FootSide.left), _sole('B', side: FootSide.right)],
        'A',
        null,
      );
      expect(_sideOf(out, 'A'), isNull);
      expect(_sideOf(out, 'B'), FootSide.right);
    });

    test('an unknown key changes nothing', () {
      final before = [_sole('A', side: FootSide.left)];
      expect(assignFootSide(before, 'NOPE', FootSide.right), before);
    });
  });

  group('AppSettings', () {
    test('soleFor finds the sole worn on a side, and nothing otherwise', () {
      final settings = _settingsWith([_sole('A', side: FootSide.right)]);
      expect(settings.soleFor(FootSide.right)?.deviceId, 'A');
      expect(settings.soleFor(FootSide.left), isNull);
    });

    test('unassignedSoles lists only the soles with no side yet', () {
      final settings = _settingsWith([
        _sole('A', side: FootSide.right),
        _sole('B'),
        _sole('C'),
      ]);
      expect(settings.unassignedSoles.map((d) => d.deviceId), ['B', 'C']);
    });
  });
}
