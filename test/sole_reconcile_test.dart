import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/sole_reconcile.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

SoleCandidate _sole(String remoteId, {String? deviceId, int rssi = -60}) =>
    SoleCandidate(
      remoteId: remoteId,
      name: 'SilverSole',
      rssi: rssi,
      deviceId: deviceId,
    );

BlePairedDevice _paired(String remoteId, {String? deviceId}) =>
    BlePairedDevice(remoteId: remoteId, name: 'SilverSole', deviceId: deviceId);

void main() {
  group('identityKeyFor', () {
    test('a known sole is keyed by its paired entry', () {
      expect(
        identityKeyFor(_sole('new-addr', deviceId: 'A'), [
          _paired('old-addr', deviceId: 'A'),
        ]),
        'A',
      );
    });

    test('an unknown sole is keyed by its own ID, else its address', () {
      expect(identityKeyFor(_sole('addr', deviceId: 'Z'), const []), 'Z');
      expect(identityKeyFor(_sole('addr'), const []), 'addr');
    });
  });

  group('reconcileSoleLinks', () {
    test('attaches the picks nothing is linked to yet', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('a', deviceId: 'A'), _sole('b', deviceId: 'B')],
        paired: [_paired('a', deviceId: 'A'), _paired('b', deviceId: 'B')],
        linkedKeys: const {},
      );
      expect(plan.attach.map((c) => c.deviceId), ['A', 'B']);
      expect(plan.detach, isEmpty);
    });

    test('a sole that already has a link is left alone', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('a', deviceId: 'A'), _sole('b', deviceId: 'B')],
        paired: [_paired('a', deviceId: 'A'), _paired('b', deviceId: 'B')],
        linkedKeys: const {'A'},
      );
      expect(plan.attach.map((c) => c.deviceId), ['B']);
      expect(plan.detach, isEmpty);
    });

    // A connected sole usually stops advertising, so a scan that cannot see it
    // says nothing about whether it is still there. Dropping it here would
    // tear down a working connection on every single search.
    test('a linked sole missing from the scan is NOT detached', () {
      final plan = reconcileSoleLinks(
        picks: const [],
        paired: [_paired('a', deviceId: 'A')],
        linkedKeys: const {'A'},
      );
      expect(plan.attach, isEmpty);
      expect(plan.detach, isEmpty);
    });

    test('a link whose sole is no longer paired is detached', () {
      final plan = reconcileSoleLinks(
        picks: const [],
        paired: [_paired('a', deviceId: 'A')],
        linkedKeys: const {'A', 'GONE'},
      );
      expect(plan.detach, {'GONE'});
    });

    test('the links already held count towards max', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('b', deviceId: 'B'), _sole('c', deviceId: 'C')],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('b', deviceId: 'B'),
          _paired('c', deviceId: 'C'),
        ],
        linkedKeys: const {'A'},
      );
      expect(plan.attach.map((c) => c.deviceId), ['B']);
    });

    test('a freed slot is reused in the same pass', () {
      // 'GONE' is unpaired, so its slot opens up for C right away.
      final plan = reconcileSoleLinks(
        picks: [_sole('c', deviceId: 'C')],
        paired: [_paired('a', deviceId: 'A'), _paired('c', deviceId: 'C')],
        linkedKeys: const {'A', 'GONE'},
      );
      expect(plan.detach, {'GONE'});
      expect(plan.attach.map((c) => c.deviceId), ['C']);
    });

    test('the same sole is never attached twice in one plan', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('a', deviceId: 'A'), _sole('a2', deviceId: 'A')],
        paired: [_paired('a', deviceId: 'A')],
        linkedKeys: const {},
      );
      expect(plan.attach.length, 1);
    });
  });
}
