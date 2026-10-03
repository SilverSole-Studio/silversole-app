import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/sole_scanner.dart';

SoleCandidate _sole(String remoteId, int rssi) =>
    SoleCandidate(remoteId: remoteId, name: 'SilverSole', rssi: rssi);

void main() {
  test('no sole on the air means nothing to connect to', () {
    expect(pickSole(const [], preferredRemoteId: 'AA'), isNull);
  });

  test('the primary device wins whenever it is on the air', () {
    final pick = pickSole([
      _sole('AA', -80),
      _sole('BB', -40),
    ], preferredRemoteId: 'AA');
    expect(pick?.remoteId, 'AA');
  });

  test('without the primary device the strongest signal wins', () {
    final pick = pickSole([
      _sole('AA', -80),
      _sole('BB', -40),
      _sole('CC', -60),
    ], preferredRemoteId: 'ZZ');
    expect(pick?.remoteId, 'BB');
  });

  test('a stale primary remoteId does not block connecting', () {
    // The sole advertises a new MAC every boot, so the remembered primary is
    // usually absent. Whatever is actually advertising has to win, or the app
    // sits there retrying a MAC that will never come back.
    final pick = pickSole([_sole('NEW', -70)], preferredRemoteId: 'OLD');
    expect(pick?.remoteId, 'NEW');
  });

  test('a sole is recognised by its advertised name, any casing', () {
    expect(isSoleName('SilverSole-01'), isTrue);
    expect(isSoleName('silversole'), isTrue);
    expect(isSoleName('Galaxy Watch5'), isFalse);
    expect(isSoleName(''), isFalse);
  });
}
