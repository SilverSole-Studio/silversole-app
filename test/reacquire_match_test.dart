import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ota/reacquire_match.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

SoleCandidate _seen(String remoteId, {String? id}) => SoleCandidate(
  remoteId: remoteId,
  name: 'SilverSole',
  rssi: -60,
  deviceId: id,
);

BlePairedDevice _paired(String remoteId, {String? id}) =>
    BlePairedDevice(remoteId: remoteId, name: 'SilverSole', deviceId: id);

void main() {
  test('a sole that had an ID is found by that ID on any address', () {
    final m = matchReacquireTarget(
      target: _paired('OLD', id: 'A'),
      seen: [
        _seen('X', id: 'B'),
        _seen('NEW', id: 'A'),
      ],
      paired: const [],
    );
    expect(m?.candidate.remoteId, 'NEW');
    expect(m?.confidence, ReacquireConfidence.certain);
  });

  test('with an ID there is no guessing', () {
    expect(
      matchReacquireTarget(
        target: _paired('OLD', id: 'A'),
        seen: [_seen('OLD', id: 'B')],
        paired: const [],
      ),
      isNull,
    );
  });

  test('a sole that had no ID is found by its old address', () {
    final m = matchReacquireTarget(
      target: _paired('M1'),
      seen: [
        _seen('M9', id: 'X'),
        _seen('M1', id: 'NEW'),
      ],
      paired: const [],
    );
    expect(m?.candidate.remoteId, 'M1');
    expect(m?.confidence, ReacquireConfidence.certain);
  });

  test('otherwise a lone sole nobody else owns is the probable match', () {
    final target = _paired('M1');
    final m = matchReacquireTarget(
      target: target,
      seen: [_seen('M2', id: 'NEW')],
      paired: [
        target,
        _paired('M5', id: 'OTHER'),
      ],
    );
    expect(m?.candidate.remoteId, 'M2');
    expect(m?.confidence, ReacquireConfidence.probable);
  });

  test('a lone sole that is another paired one is not it', () {
    final target = _paired('M1');
    expect(
      matchReacquireTarget(
        target: target,
        seen: [_seen('M3', id: 'OTHER')],
        paired: [
          target,
          _paired('M5', id: 'OTHER'),
        ],
      ),
      isNull,
    );
  });

  test('two soles on the air are too ambiguous to guess', () {
    expect(
      matchReacquireTarget(
        target: _paired('M1'),
        seen: [
          _seen('M2', id: 'X'),
          _seen('M3', id: 'Y'),
        ],
        paired: const [],
      ),
      isNull,
    );
  });

  test('nothing seen is nothing found', () {
    expect(
      matchReacquireTarget(
        target: _paired('M1'),
        seen: const [],
        paired: const [],
      ),
      isNull,
    );
  });
}
