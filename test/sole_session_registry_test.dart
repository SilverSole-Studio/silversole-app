import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';

/// Stands in for a real session so the registry is tested without BLE.
/// `BleConnectionService` keeps every bit of its state per instance, so
/// subclassing it is enough.
class _FakeService extends BleConnectionService {
  bool connected = false;
  var detaches = 0;

  @override
  bool get isConnected => connected;

  @override
  Future<void> detach() async => detaches++;
}

BlePairedDevice _sole(String id, {String name = 'SilverSole'}) =>
    BlePairedDevice(remoteId: 'addr-$id', name: name, deviceId: id);

void main() {
  test('a key gets one session, reused on every later link()', () {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final first = registry.link('A', _sole('A'));
    final again = registry.link('A', _sole('A', name: 'Renamed'));

    expect(again, same(first));
    expect(again.service, same(first.service));
    // The stored device is refreshed; the live connection is not disturbed.
    expect(again.device.name, 'Renamed');
    expect(registry.keys, {'A'});
  });

  test('two soles get two independent sessions', () {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final a = registry.link('A', _sole('A'));
    final b = registry.link('B', _sole('B'));

    expect(a.service, isNot(same(b.service)));
    expect(registry.keys, {'A', 'B'});
    expect(registry.links.length, 2);
  });

  test('connectedCount and anyConnected follow the services', () {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final a = registry.link('A', _sole('A'));
    registry.link('B', _sole('B'));

    expect(registry.anyConnected, isFalse);
    expect(registry.connectedCount, 0);

    (a.service as _FakeService).connected = true;
    expect(registry.anyConnected, isTrue);
    expect(registry.connectedCount, 1);
  });

  test('detach drops the session and tears the link down', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final a = registry.link('A', _sole('A'));
    final service = a.service as _FakeService;

    await registry.detach('A');
    expect(service.detaches, 1);
    expect(registry.lookup('A'), isNull);
    expect(registry.keys, isEmpty);
  });

  test('detaching an unknown key is harmless', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    await registry.detach('NOPE');
    expect(registry.keys, isEmpty);
  });

  test('detachAll clears everything', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    registry.link('A', _sole('A'));
    registry.link('B', _sole('B'));

    await registry.detachAll();
    expect(registry.keys, isEmpty);
    expect(registry.links, isEmpty);
  });

  test('re-keying moves the session and keeps the live service', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final link = registry.link('addr', _sole('addr'));
    final service = link.service;

    await registry.rekey('addr', 'ID');

    expect(registry.lookup('addr'), isNull);
    expect(registry.lookup('ID'), same(link));
    // The connection must survive: a re-key is bookkeeping, not a reconnect.
    expect(registry.lookup('ID')!.service, same(service));
    expect((service as _FakeService).detaches, 0);
    expect(registry.keys, {'ID'});
  });

  test('re-keying onto an occupied key retires the misfiled session', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final stale = registry.link('addr', _sole('addr'));
    final live = registry.link('ID', _sole('ID'));

    await registry.rekey('addr', 'ID');

    expect(registry.keys, {'ID'});
    expect(registry.lookup('ID'), same(live));
    expect((stale.service as _FakeService).detaches, 1);
    expect((live.service as _FakeService).detaches, 0);
  });

  test('re-keying an unknown or unchanged key is harmless', () async {
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final link = registry.link('A', _sole('A'));

    await registry.rekey('NOPE', 'X');
    await registry.rekey('A', 'A');

    expect(registry.keys, {'A'});
    expect(registry.lookup('A'), same(link));
    expect((link.service as _FakeService).detaches, 0);
  });
}
