import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';

SoleCandidate _sole(String remoteId, int rssi, {String? deviceId}) =>
    SoleCandidate(
      remoteId: remoteId,
      name: 'SilverSole',
      rssi: rssi,
      deviceId: deviceId,
    );

BlePairedDevice _paired(
  String remoteId, {
  String? deviceId,
  bool preferred = false,
  FootSide? side,
}) => BlePairedDevice(
  remoteId: remoteId,
  name: 'SilverSole',
  deviceId: deviceId,
  isPreferred: preferred,
  footSide: side,
);

void main() {
  group('soleDeviceIdFrom', () {
    test('reads the 8 ID bytes after the company code as uppercase hex', () {
      expect(
        soleDeviceIdFrom({
          soleManufacturerId: [0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F, 0x70, 0x81],
        }),
        '1A2B3C4D5E6F7081',
      );
    });

    test('keeps leading zero bytes', () {
      expect(
        soleDeviceIdFrom({
          soleManufacturerId: [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x0A],
        }),
        '000102030405060A',
      );
    });

    test('no ID without the sole company code', () {
      expect(soleDeviceIdFrom({}), isNull);
      expect(
        soleDeviceIdFrom({
          0x0059: [1, 2, 3, 4, 5, 6, 7, 8],
        }),
        isNull,
      );
    });

    test('no ID when the payload is not exactly 8 bytes', () {
      expect(
        soleDeviceIdFrom({
          soleManufacturerId: [1, 2, 3],
        }),
        isNull,
      );
      expect(
        soleDeviceIdFrom({
          soleManufacturerId: [1, 2, 3, 4, 5, 6, 7, 8, 9],
        }),
        isNull,
      );
    });
  });

  group('isSameSole', () {
    test('compares IDs when both sides have one, whatever the MAC', () {
      expect(
        isSameSole(
          _sole('NEW', -50, deviceId: 'A'),
          _paired('OLD', deviceId: 'A'),
        ),
        isTrue,
      );
      expect(
        isSameSole(
          _sole('SAME', -50, deviceId: 'A'),
          _paired('SAME', deviceId: 'B'),
        ),
        isFalse,
      );
    });

    test('falls back to the MAC when either side has no ID', () {
      expect(isSameSole(_sole('AA', -50), _paired('AA')), isTrue);
      expect(
        isSameSole(_sole('AA', -50, deviceId: 'A'), _paired('AA')),
        isTrue,
      );
      expect(isSameSole(_sole('AA', -50), _paired('BB')), isFalse);
    });
  });

  group('pickSole', () {
    test('no sole on the air means nothing to connect to', () {
      expect(
        pickSole(const [], paired: [_paired('AA', preferred: true)]),
        isNull,
      );
    });

    test('the primary device wins whenever it is on the air', () {
      final pick = pickSole(
        [_sole('AA', -80), _sole('BB', -40)],
        paired: [_paired('AA', preferred: true)],
      );
      expect(pick?.remoteId, 'AA');
    });

    test('the primary device is found by ID after its MAC changed', () {
      final pick = pickSole(
        [_sole('NEW', -80, deviceId: 'P'), _sole('XX', -40, deviceId: 'Q')],
        paired: [
          _paired('OLD', deviceId: 'P', preferred: true),
          _paired('YY', deviceId: 'Q'),
        ],
      );
      expect(pick?.remoteId, 'NEW');
    });

    test('a paired sole beats a stronger stranger', () {
      final pick = pickSole(
        [
          _sole('S', -30, deviceId: 'STRANGER'),
          _sole('M', -90, deviceId: 'MINE'),
        ],
        paired: [
          _paired('P', deviceId: 'PRIMARY', preferred: true),
          _paired('M', deviceId: 'MINE'),
        ],
      );
      expect(pick?.remoteId, 'M');
    });

    test('among paired soles the strongest signal wins', () {
      final pick = pickSole(
        [_sole('A', -80, deviceId: 'A'), _sole('B', -40, deviceId: 'B')],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('b', deviceId: 'B'),
        ],
      );
      expect(pick?.remoteId, 'B');
    });

    test('a stranger with an ID is never picked once every entry has one', () {
      final pick = pickSole(
        [_sole('S', -30, deviceId: 'STRANGER')],
        paired: [_paired('P', deviceId: 'PRIMARY', preferred: true)],
      );
      expect(pick, isNull);
    });

    test('a legacy entry lets any sole be the last resort', () {
      // A sole paired on old firmware has no ID on record. After it moves to
      // firmware that reports one it looks like a stranger, and only this
      // fallback lets auto-connect find it again.
      final pick = pickSole(
        [_sole('S1', -70, deviceId: 'X'), _sole('S2', -40, deviceId: 'Y')],
        paired: [_paired('OLD', preferred: true)],
      );
      expect(pick?.remoteId, 'S2');
    });

    test('a sole without an ID stays connectable, as before', () {
      // Old firmware gives nothing to identify it by, so the pre-ID behaviour
      // stands: whatever is advertising, strongest first.
      final pick = pickSole(
        [_sole('AA', -80), _sole('BB', -40), _sole('CC', -60)],
        paired: [_paired('P', deviceId: 'PRIMARY', preferred: true)],
      );
      expect(pick?.remoteId, 'BB');
    });

    test('a stale primary remoteId does not block connecting', () {
      final pick = pickSole(
        [_sole('NEW', -70)],
        paired: [_paired('OLD', preferred: true)],
      );
      expect(pick?.remoteId, 'NEW');
    });
  });

  group('pickSoles', () {
    test('returns the calibrated pair, left first', () {
      final picks = pickSoles(
        [_sole('r', -70, deviceId: 'R'), _sole('l', -80, deviceId: 'L')],
        paired: [
          _paired('r', deviceId: 'R', side: FootSide.right),
          _paired('l', deviceId: 'L', side: FootSide.left),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['L', 'R']);
    });

    // The wearer owns three soles; only two can be connected at once, and it
    // has to be the pair they calibrated — not whichever two shout loudest.
    test('with three paired soles the calibrated pair wins', () {
      final picks = pickSoles(
        [
          _sole('spare', -20, deviceId: 'SPARE'),
          _sole('r', -70, deviceId: 'R'),
          _sole('l', -80, deviceId: 'L'),
        ],
        paired: [
          _paired('spare', deviceId: 'SPARE'),
          _paired('r', deviceId: 'R', side: FootSide.right),
          _paired('l', deviceId: 'L', side: FootSide.left),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['L', 'R']);
    });

    test('max caps how many come back', () {
      final picks = pickSoles(
        [_sole('a', -40, deviceId: 'A'), _sole('b', -50, deviceId: 'B')],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('b', deviceId: 'B'),
        ],
        max: 1,
      );
      expect(picks.map((c) => c.deviceId), ['A']);
    });

    test('a sole never takes two places', () {
      // The same sole is both the left foot and the primary device.
      final picks = pickSoles(
        [_sole('l', -60, deviceId: 'L')],
        paired: [
          _paired('l', deviceId: 'L', side: FootSide.left, preferred: true),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['L']);
    });

    test('an unassigned paired sole fills the second slot', () {
      final picks = pickSoles(
        [_sole('r', -70, deviceId: 'R'), _sole('x', -50, deviceId: 'X')],
        paired: [
          _paired('r', deviceId: 'R', side: FootSide.right),
          _paired('x', deviceId: 'X'),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['R', 'X']);
    });

    test('nothing paired on the air means nothing to connect to', () {
      expect(
        pickSoles(
          [_sole('s', -30, deviceId: 'STRANGER')],
          paired: [_paired('m', deviceId: 'MINE')],
        ),
        isEmpty,
      );
    });

    test('two identified soles let only one unidentifiable stranger in', () {
      // Both of the wearer's soles report IDs, so nothing is awaiting
      // recovery; the last resort is a single slot and must not fill both.
      final picks = pickSoles(
        [_sole('N1', -40), _sole('N2', -50)],
        paired: [
          _paired('A', deviceId: 'A_ID'),
          _paired('B', deviceId: 'B_ID'),
        ],
      );
      expect(picks.map((c) => c.remoteId), ['N1']);
    });

    test('one legacy entry lets only one unidentifiable sole in', () {
      // The legacy sole may now report an ID, so it matches nothing; the
      // second slot must not go to a stranger the user never paired.
      final picks = pickSoles(
        [_sole('S1', -40, deviceId: 'X'), _sole('S2', -50, deviceId: 'Y')],
        paired: [
          _paired('OLD'),
          _paired('MINE', deviceId: 'MINE_ID'),
        ],
      );
      expect(picks.map((c) => c.deviceId), ['X']);
    });

    test('two legacy entries let two unidentifiable soles in', () {
      final picks = pickSoles(
        [_sole('S1', -40, deviceId: 'X'), _sole('S2', -50, deviceId: 'Y')],
        paired: [_paired('OLD1'), _paired('OLD2')],
      );
      expect(picks.map((c) => c.deviceId), ['X', 'Y']);
    });

    test('a foot side outranks the primary device at max 1', () {
      // Spec §5.1: the wearer's calibration beats a stale primary flag.
      final picks = pickSoles(
        [_sole('P', -40, deviceId: 'PRI'), _sole('S', -80, deviceId: 'SIDED')],
        paired: [
          _paired('P', deviceId: 'PRI', preferred: true),
          _paired('S', deviceId: 'SIDED', side: FootSide.left),
        ],
        max: 1,
      );
      expect(picks.map((c) => c.deviceId), ['SIDED']);
    });
  });

  test('a sole is recognised by its advertised name, any casing', () {
    expect(isSoleName('SilverSole-01'), isTrue);
    expect(isSoleName('silversole'), isTrue);
    expect(isSoleName('Galaxy Watch5'), isFalse);
    expect(isSoleName(''), isFalse);
  });
}
