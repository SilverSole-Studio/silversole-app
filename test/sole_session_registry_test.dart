import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/ble_connection_service.dart';
import 'package:silversole/core/ble/sole_reconcile.dart';
import 'package:silversole/core/ble/sole_session_registry.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/connected_sole.dart';
import 'package:silversole/shared/providers/ble_foreground_controller.dart';
import 'package:silversole/shared/providers/connected_sole_provider.dart';

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

  test('a re-key nobody awaits has already moved the session', () {
    // The orchestrator's onReady calls rekey fire-and-forget and reads the new
    // key in the same synchronous block, so the map move must land before the
    // method's first await. An await added ahead of it would break that
    // silently — the sole's telemetry would just stop.
    final registry = SoleSessionRegistry(createService: _FakeService.new);
    final link = registry.link('addr', _sole('addr'));

    registry.rekey('addr', 'ID'); // deliberately not awaited

    expect(registry.lookup('ID'), same(link));
    expect(registry.lookup('addr'), isNull);
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

  group('linkStatesOf', () {
    // `watchdog?.isActive ?? false` is the one line under this branch's only
    // Critical, and it is subtle: a *fired* Timer reports `isActive == false`,
    // which is the whole point — a link whose watchdog has had its chance no
    // longer holds its foot's slot.
    test('maps connection and watchdog into what the search decision sees', () {
      final registry = SoleSessionRegistry(createService: _FakeService.new);
      final connected = registry.link('C', _sole('C'));
      (connected.service as _FakeService).connected = true;
      final waiting = registry.link('W', _sole('W'));
      waiting.watchdog = Timer(const Duration(hours: 1), () {});
      addTearDown(waiting.cancelWatchdog);
      registry.link('D', _sole('D'));

      final states = {for (final s in linkStatesOf(registry)) s.key: s};
      expect(states.keys, {'C', 'W', 'D'});

      expect(states['C']!.isConnected, isTrue);
      expect(states['C']!.awaitingWatchdog, isFalse);
      expect(states['C']!.isLive, isTrue);

      // Not connected, but still inside its grace period.
      expect(states['W']!.isConnected, isFalse);
      expect(states['W']!.awaitingWatchdog, isTrue);
      expect(states['W']!.isLive, isTrue);

      // Neither: this link is dead and must release its foot's slot.
      expect(states['D']!.isConnected, isFalse);
      expect(states['D']!.awaitingWatchdog, isFalse);
      expect(states['D']!.isLive, isFalse);
    });

    // The distinction a `watchdog != null` test would miss entirely.
    test('a watchdog that has already fired is not awaited', () async {
      final registry = SoleSessionRegistry(createService: _FakeService.new);
      final link = registry.link('A', _sole('A'));
      link.watchdog = Timer(Duration.zero, () {});
      expect(linkStatesOf(registry).single.awaitingWatchdog, isTrue);

      await Future<void>.delayed(Duration.zero);

      // Still a non-null Timer, so `watchdog != null` would read this link as
      // alive and the sole could never be re-attached on a new address.
      expect(link.watchdog, isNotNull);
      expect(linkStatesOf(registry).single.awaitingWatchdog, isFalse);
      expect(linkStatesOf(registry).single.isLive, isFalse);
    });
  });

  group('dropOtherSoles', () {
    test('drops every other sole and never the one being kept', () async {
      final registry = SoleSessionRegistry(createService: _FakeService.new);
      final keep = registry.link('KEEP', _sole('KEEP'));
      final otherA = registry.link('A', _sole('A'));
      final otherB = registry.link('B', _sole('B'));
      // A dropped sole must lose its watchdog too, or it keeps re-arming a
      // search for a foot the OTA deliberately put down.
      otherA.watchdog = Timer(const Duration(hours: 1), () {});

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final connectedSoles = container.read(connectedSolesProvider.notifier);
      for (final key in ['KEEP', 'A', 'B']) {
        connectedSoles.set(
          key,
          ConnectedSole(device: _sole(key), dfuSupported: false),
        );
      }

      dropOtherSoles(registry, connectedSoles, keep: 'KEEP');
      // detach() is fire-and-forget inside the loop; let it land.
      await Future<void>.delayed(Duration.zero);

      // The one that matters: the sole the OTA is for is untouched.
      expect(registry.lookup('KEEP'), same(keep));
      expect((keep.service as _FakeService).detaches, 0);
      expect(container.read(connectedSolesProvider).keys, {'KEEP'});

      expect(registry.keys, {'KEEP'});
      expect((otherA.service as _FakeService).detaches, 1);
      expect((otherB.service as _FakeService).detaches, 1);
      expect(otherA.watchdog, isNull);
    });

    test(
      'keeping a sole that is not in the registry still drops the rest',
      () async {
        final registry = SoleSessionRegistry(createService: _FakeService.new);
        final only = registry.link('A', _sole('A'));

        final container = ProviderContainer();
        addTearDown(container.dispose);
        dropOtherSoles(
          registry,
          container.read(connectedSolesProvider.notifier),
          keep: 'GONE',
        );
        await Future<void>.delayed(Duration.zero);

        expect(registry.keys, isEmpty);
        expect((only.service as _FakeService).detaches, 1);
      },
    );
  });
}
