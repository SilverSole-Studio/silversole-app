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

/// A link that still holds its foot's slot: connected, or dropped with its
/// watchdog still to fire.
LinkState _live(String key, {bool connected = true}) =>
    LinkState(key: key, isConnected: connected, awaitingWatchdog: !connected);

/// A link whose watchdog fired without the sole coming back — the sole has
/// most likely rebooted onto another address, so this link holds nothing.
LinkState _dead(String key) =>
    LinkState(key: key, isConnected: false, awaitingWatchdog: false);

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

    test('the stored entry wins over the candidate\'s own ID', () {
      // A candidate-first lookup would return 'A' here; expecting 'addr'
      // pins that the stored entry's key wins.
      expect(
        identityKeyFor(_sole('addr', deviceId: 'A'), [_paired('addr')]),
        'addr',
      );
    });

    test('an unknown sole is keyed by its own ID, else its address', () {
      expect(identityKeyFor(_sole('addr', deviceId: 'Z'), const []), 'Z');
      expect(identityKeyFor(_sole('addr'), const []), 'addr');
    });

    // Documents a consequence, not desired behaviour: once the paired entry
    // gains a chip ID its identityKey is 'A', so the session still held under
    // 'addr' reads as unpaired. The session registry must re-key it (see
    // identityKeyFor); this test pins what happens if it does not.
    test(
      'without a re-key, a link whose paired entry gained an ID is detached',
      () {
        final plan = reconcileSoleLinks(
          picks: const [],
          paired: [_paired('addr', deviceId: 'A')],
          links: [_live('addr')],
        );
        expect(plan.detach, {'addr'});
      },
    );
  });

  group('reconcileSoleLinks', () {
    test('attaches the picks nothing is linked to yet', () {
      final plan = reconcileSoleLinks(
        picks: [
          _sole('a', deviceId: 'A'),
          _sole('b', deviceId: 'B'),
        ],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('b', deviceId: 'B'),
        ],
        links: const [],
      );
      expect(plan.attach.map((c) => c.deviceId), ['A', 'B']);
      expect(plan.detach, isEmpty);
      expect(plan.reschedule, isFalse);
    });

    test('a sole that already has a link is left alone', () {
      final plan = reconcileSoleLinks(
        picks: [
          _sole('a', deviceId: 'A'),
          _sole('b', deviceId: 'B'),
        ],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('b', deviceId: 'B'),
        ],
        links: [_live('A')],
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
        links: [_live('A')],
      );
      expect(plan.attach, isEmpty);
      expect(plan.detach, isEmpty);
      expect(plan.reschedule, isFalse);
    });

    test('a link whose sole is no longer paired is detached', () {
      final plan = reconcileSoleLinks(
        picks: const [],
        paired: [_paired('a', deviceId: 'A')],
        links: [_live('A'), _live('GONE')],
      );
      expect(plan.detach, {'GONE'});
    });

    test('the links already held count towards max', () {
      final plan = reconcileSoleLinks(
        picks: [
          _sole('b', deviceId: 'B'),
          _sole('c', deviceId: 'C'),
        ],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('b', deviceId: 'B'),
          _paired('c', deviceId: 'C'),
        ],
        links: [_live('A')],
      );
      expect(plan.attach.map((c) => c.deviceId), ['B']);
    });

    test('a freed slot is reused in the same pass', () {
      // 'GONE' is unpaired, so its slot opens up for C right away.
      final plan = reconcileSoleLinks(
        picks: [_sole('c', deviceId: 'C')],
        paired: [
          _paired('a', deviceId: 'A'),
          _paired('c', deviceId: 'C'),
        ],
        links: [_live('A'), _live('GONE')],
      );
      expect(plan.detach, {'GONE'});
      expect(plan.attach.map((c) => c.deviceId), ['C']);
    });

    test('the same sole is never attached twice in one plan', () {
      final plan = reconcileSoleLinks(
        picks: [
          _sole('a', deviceId: 'A'),
          _sole('a2', deviceId: 'A'),
        ],
        paired: [_paired('a', deviceId: 'A')],
        links: const [],
      );
      expect(plan.attach.length, 1);
    });

    // The reconnect path this whole seam exists for: the sole dropped, its own
    // backoff could not bring the same address back, its watchdog fired, and
    // it is now advertising on a fresh MAC. If the dead link kept the foot's
    // slot the pick would be discarded and that foot would never come back.
    test('a dead link does not block its own re-attach', () {
      final plan = reconcileSoleLinks(
        picks: [_sole('new-addr', deviceId: 'A')],
        paired: [_paired('old-addr', deviceId: 'A')],
        links: [_dead('A')],
      );
      expect(plan.attach.map((c) => c.remoteId), ['new-addr']);
      expect(plan.detach, isEmpty);
      // The sole was found, so this pass is not short of a foot any more.
      expect(plan.reschedule, isFalse);
    });

    test('a live link keeps its slot, so its pick is not re-attached', () {
      for (final link in [_live('A'), _live('A', connected: false)]) {
        final plan = reconcileSoleLinks(
          picks: [_sole('a', deviceId: 'A')],
          paired: [_paired('a', deviceId: 'A')],
          links: [link],
        );
        expect(plan.attach, isEmpty);
        expect(plan.reschedule, isFalse);
      }
    });

    test('a dead link whose sole is not advertising asks to search again', () {
      final plan = reconcileSoleLinks(
        picks: const [],
        paired: [_paired('a', deviceId: 'A')],
        links: [_dead('A')],
      );
      expect(plan.attach, isEmpty);
      // Still paired, so the session stays armed for a same-address return.
      expect(plan.detach, isEmpty);
      expect(plan.reschedule, isTrue);
    });

    test('an unpaired link is detached even while every foot is connected', () {
      final plan = reconcileSoleLinks(
        picks: const [],
        paired: [_paired('a', deviceId: 'A')],
        links: [_live('A'), _live('GONE')],
        max: 2,
      );
      expect(plan.detach, {'GONE'});
      expect(plan.attach, isEmpty);
      expect(plan.reschedule, isFalse);
    });
  });

  group('needsSearch', () {
    test('every foot connected and paired: nothing to look for', () {
      expect(
        needsSearch(
          paired: [
            _paired('a', deviceId: 'A'),
            _paired('b', deviceId: 'B'),
          ],
          links: [_live('A'), _live('B')],
          force: false,
        ),
        isFalse,
      );
    });

    test('a dropped link still inside its watchdog window is left alone', () {
      // Its own backoff may bring the same address back; a scan now would only
      // compete with it.
      expect(
        needsSearch(
          paired: [_paired('a', deviceId: 'A')],
          links: [_live('A', connected: false)],
          force: false,
        ),
        isFalse,
      );
    });

    test('a dead link means searching', () {
      expect(
        needsSearch(
          paired: [_paired('a', deviceId: 'A')],
          links: [_dead('A')],
          force: false,
        ),
        isTrue,
      );
    });

    // Unpairing the sole that is not the primary one changes neither the
    // preferred key nor the preferred address, so this is the only signal that
    // a session has to be torn down. Answering "no" here leaves the deleted
    // sole streaming, and its next handshake puts it back in the paired list.
    test('a link whose sole is no longer paired means searching', () {
      expect(
        needsSearch(
          paired: [_paired('a', deviceId: 'A')],
          links: [_live('A'), _live('GONE')],
          force: false,
        ),
        isTrue,
      );
    });

    test('a missing foot means searching', () {
      expect(
        needsSearch(
          paired: [
            _paired('a', deviceId: 'A'),
            _paired('b', deviceId: 'B'),
          ],
          links: [_live('A')],
          force: false,
        ),
        isTrue,
      );
    });

    test('a forced manual pick always searches', () {
      expect(
        needsSearch(
          paired: [_paired('a', deviceId: 'A')],
          links: [_live('A')],
          force: true,
        ),
        isTrue,
      );
    });

    // The caller's teardown branch lives behind this guard, so it has to be
    // reachable with nothing paired.
    test('nothing paired always searches, so teardown stays reachable', () {
      expect(
        needsSearch(paired: const [], links: const [], force: false),
        isTrue,
      );
      expect(
        needsSearch(paired: const [], links: [_live('GONE')], force: false),
        isTrue,
      );
    });
  });
}
