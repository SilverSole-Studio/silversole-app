import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/data/save_service.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

BlePairedDevice _device(
  String remoteId, {
  String? deviceId,
  String name = 'SilverSole',
  bool preferred = false,
}) => BlePairedDevice(
  remoteId: remoteId,
  name: name,
  deviceId: deviceId,
  isPreferred: preferred,
);

void main() {
  group('identityKey', () {
    test('is the chip ID when the sole reported one', () {
      expect(
        _device('AA:BB', deviceId: '1A2B3C4D5E6F7081').identityKey,
        '1A2B3C4D5E6F7081',
      );
    });

    test('falls back to the MAC for old firmware', () {
      expect(_device('AA:BB').identityKey, 'AA:BB');
    });
  });

  group('shortId', () {
    test('is the last 4 characters of the chip ID', () {
      expect(_device('AA', deviceId: '1A2B3C4D5E6F7081').shortId, '7081');
    });

    test('is null without an ID', () {
      expect(_device('AA').shortId, isNull);
    });
  });

  group('upsertPairedDevice', () {
    test('a new sole is appended', () {
      final list = upsertPairedDevice([
        _device('A', deviceId: 'ID_A'),
      ], _device('B', deviceId: 'ID_B'));
      expect(list.map((d) => d.identityKey), ['ID_A', 'ID_B']);
    });

    test(
      'the same ID under a new MAC updates the entry instead of adding one',
      () {
        final list = upsertPairedDevice([
          _device('OLD_MAC', deviceId: 'ID', name: '左腳', preferred: true),
        ], _device('NEW_MAC', deviceId: 'ID', name: '左腳'));
        expect(list, hasLength(1));
        expect(list.single.remoteId, 'NEW_MAC');
        expect(list.single.isPreferred, isTrue);
      },
    );

    test('a legacy entry picks up the ID its sole now reports', () {
      final list = upsertPairedDevice([
        _device('MAC', preferred: true),
      ], _device('MAC', deviceId: 'ID'));
      expect(list, hasLength(1));
      expect(list.single.deviceId, 'ID');
      expect(list.single.isPreferred, isTrue);
    });

    test('an update without an ID keeps the one on record', () {
      final list = upsertPairedDevice([
        _device('MAC', deviceId: 'ID'),
      ], _device('MAC', name: 'renamed'));
      expect(list.single.deviceId, 'ID');
      expect(list.single.name, 'renamed');
    });

    test('a legacy entry and an ID entry for the same sole merge into one', () {
      final list = upsertPairedDevice([
        _device('OTHER', deviceId: 'X'),
        _device('MAC', preferred: true),
        _device('NEW_MAC', deviceId: 'ID'),
      ], _device('MAC', deviceId: 'ID'));
      expect(list.map((d) => d.identityKey), ['X', 'ID']);
      expect(list.last.remoteId, 'MAC');
      expect(list.last.isPreferred, isTrue);
    });

    test('a shared MAC with a different ID is a different sole', () {
      final list = upsertPairedDevice([
        _device('MAC', deviceId: 'A'),
      ], _device('MAC', deviceId: 'B'));
      expect(list.map((d) => d.identityKey), ['A', 'B']);
    });
  });
}
