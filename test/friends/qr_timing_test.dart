import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/friends/qr_timing.dart';

Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

void main() {
  group('ScanDebouncer', () {
    test('a new code is handled at once', () {
      final d = ScanDebouncer();
      expect(d.accept('SSF1:a', s(0)), isTrue);
    });

    test('a code left in view is not handled again', () {
      final d = ScanDebouncer();
      expect(d.accept('SSO1:52013140', s(0)), isTrue);
      d.settle(s(4)); // the sheet was open for 4 s, scanner paused
      // The poster is still in frame, seen every 250 ms for a minute.
      for (var t = 4.25; t < 64; t += 0.25) {
        expect(d.accept('SSO1:52013140', s(t)), isFalse, reason: 't=$t');
      }
    });

    test('the same code counts again after 2 s out of frame', () {
      final d = ScanDebouncer();
      d.accept('SSF1:a', s(0));
      d.settle(s(1));
      // Still in frame until 6 s…
      for (var t = 1.25; t <= 6; t += 0.25) {
        expect(d.accept('SSF1:a', s(t)), isFalse, reason: 't=$t');
      }
      // …then gone until 8.5 s, which is also past the 5 s cooldown.
      expect(d.accept('SSF1:a', s(8.5)), isTrue);
    });

    test('a quick glance back within the cooldown is still ignored', () {
      final d = ScanDebouncer();
      d.accept('SSF1:a', s(0));
      d.settle(s(1));
      // Out of frame for 3 s, but only 4 s after it was handled.
      expect(d.accept('SSF1:a', s(5)), isFalse);
    });

    test('a different code is handled straight away', () {
      final d = ScanDebouncer();
      d.accept('SSF1:a', s(0));
      d.settle(s(1));
      expect(d.accept('SSF1:b', s(1.25)), isTrue);
      d.settle(s(2));
      // …and the first one is new again after that.
      expect(d.accept('SSF1:a', s(2.25)), isTrue);
    });

    test('settling with nothing accepted does nothing', () {
      final d = ScanDebouncer()..settle(s(0));
      expect(d.accept('SSF1:a', s(0.1)), isTrue);
    });
  });

  group('QrTokenRenewal', () {
    test('asks for a token first, then at half the TTL', () {
      final r = QrTokenRenewal(ttl: kQrTokenTtl);
      expect(r.shouldRenew(s(0)), isTrue);
      expect(r.isExpired(s(0)), isTrue);
      r.issued(s(1));
      expect(r.isExpired(s(1)), isFalse);
      expect(r.shouldRenew(s(1) + kQrTokenTtl ~/ 2 - s(1)), isFalse);
      expect(r.shouldRenew(s(1) + kQrTokenTtl ~/ 2), isTrue);
    });

    test('a token is shown until just before it runs out', () {
      final r = QrTokenRenewal(ttl: kQrTokenTtl)..issued(s(0));
      expect(r.isExpired(kQrTokenTtl - s(11)), isFalse);
      expect(r.isExpired(kQrTokenTtl - s(10)), isTrue);
    });

    test('a failure is retried with growing gaps', () {
      final r = QrTokenRenewal(ttl: kQrTokenTtl);
      r.failed(s(0));
      expect(r.failures, 1);
      expect(r.shouldRenew(s(1.9)), isFalse);
      expect(r.shouldRenew(s(2)), isTrue);
      r.failed(s(2));
      expect(r.shouldRenew(s(5.9)), isFalse);
      expect(r.shouldRenew(s(6)), isTrue);
      for (var i = 0; i < 10; i++) {
        r.failed(s(100));
      }
      // The last delay repeats.
      expect(r.shouldRenew(s(129)), isFalse);
      expect(r.shouldRenew(s(130)), isTrue);
    });

    test('a failed renewal keeps the old token until it expires', () {
      final r = QrTokenRenewal(ttl: kQrTokenTtl)..issued(s(0));
      r.failed(kQrTokenTtl ~/ 2);
      expect(r.isExpired(kQrTokenTtl ~/ 2 + s(1)), isFalse);
      r.issued(kQrTokenTtl ~/ 2 + s(2));
      expect(r.failures, 0);
      expect(r.shouldRenew(kQrTokenTtl ~/ 2 + s(3)), isFalse);
    });
  });
}
