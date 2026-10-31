import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/pressure_shares.dart';

void main() {
  final t0 = DateTime(2026, 10, 31, 12);

  /// Reads [window] as of [after] past the start, since `shares` is measured
  /// against `clock.now()`.
  PressureShares? sharesAt(
    PressureShareWindow window, [
    Duration after = const Duration(seconds: 1),
  ]) => withClock(Clock.fixed(t0.add(after)), () => window.shares);

  PressureShareWindow filled(List<int> pressure, {int count = 10}) {
    final window = PressureShareWindow();
    for (var i = 0; i < count; i++) {
      window.add(t0.add(Duration(milliseconds: i * 100)), pressure);
    }
    return window;
  }

  test('steady standing gives the fore-aft and inner-outer split', () {
    final shares = sharesAt(filled(const [900, 600, 1500]))!;
    expect(shares.foreRatio, closeTo(0.5, 1e-9));
    expect(shares.medialRatio, closeTo(0.6, 1e-9));
  });

  test('heel-only load has no inner-outer split', () {
    final shares = sharesAt(filled(const [0, 10, 2000]))!;
    expect(shares.foreRatio, closeTo(10 / 2010, 1e-9));
    expect(shares.medialRatio, isNull);
  });

  test('a foot that is not on the insole has no shares', () {
    expect(sharesAt(filled(const [20, 10, 30])), isNull);
    expect(PressureShares.from(const [20, 10, 30]), isNull);
  });

  test('fewer than five samples is not enough', () {
    expect(sharesAt(filled(const [900, 600, 1500], count: 4)), isNull);
    expect(sharesAt(filled(const [900, 600, 1500], count: 5)), isNotNull);
  });

  test('samples older than two seconds are dropped', () {
    final window = PressureShareWindow();
    for (var i = 0; i < 10; i++) {
      window.add(t0.add(Duration(milliseconds: i * 10)), const [3000, 0, 0]);
    }
    final later = t0.add(const Duration(seconds: 3));
    for (var i = 0; i < 10; i++) {
      window.add(later.add(Duration(milliseconds: i * 10)), const [0, 0, 3000]);
    }
    expect(sharesAt(window, const Duration(seconds: 4))!.foreRatio, 0);
  });

  test('readings shorter than three values are ignored', () {
    final window = PressureShareWindow();
    for (var i = 0; i < 10; i++) {
      window.add(t0.add(Duration(milliseconds: i * 100)), const [900, 600]);
    }
    expect(sharesAt(window), isNull);
  });

  test('clear forgets everything', () {
    final window = filled(const [900, 600, 1500]);
    window.clear();
    expect(sharesAt(window), isNull);
  });

  test('a foot that went silent reads null once its samples are too old', () {
    final window = filled(const [900, 600, 1500]);
    expect(sharesAt(window, const Duration(seconds: 1)), isNotNull);
    expect(
      withClock(
        Clock.fixed(t0.add(const Duration(seconds: 1))),
        () => window.hasFresh,
      ),
      isTrue,
    );
    // Last sample is at +0.9 s; at +3.5 s it is 2.6 s old.
    final late = const Duration(milliseconds: 3500);
    expect(sharesAt(window, late), isNull);
    expect(
      withClock(Clock.fixed(t0.add(late)), () => window.hasFresh),
      isFalse,
    );
  });

  group('PressureShareTracker', () {
    List<int> reading() => [900, 600, 1500];

    bool feed(PressureShareTracker tracker, int i, {required bool sample}) =>
        tracker.update(
          at: t0.add(Duration(milliseconds: i * 100)),
          rightReading: reading(),
          rightSource: Object(),
          hasRight: true,
          leftReading: reading(),
          leftSource: Object(),
          isSample: sample,
        );

    PressureShares? rightAt(PressureShareTracker tracker, int i) => withClock(
      Clock.fixed(t0.add(Duration(milliseconds: i * 100))),
      () => tracker.right.shares,
    );

    PressureShares? leftAt(PressureShareTracker tracker, int i) => withClock(
      Clock.fixed(t0.add(Duration(milliseconds: i * 100))),
      () => tracker.left.shares,
    );

    test('counts one reading once and keeps no history for an absent foot', () {
      final tracker = PressureShareTracker();
      final same = Object();
      var accepted = 0;
      for (var i = 0; i < 10; i++) {
        final took = tracker.update(
          at: t0.add(Duration(milliseconds: i * 100)),
          rightReading: [900, 600, 1500],
          rightSource: same,
          hasRight: true,
          leftReading: null,
          leftSource: null,
          isSample: false,
        );
        if (took) accepted++;
      }
      // The same source handed in ten times is a single sample, even when the
      // list it carries is rebuilt each time.
      expect(accepted, 1);
      expect(rightAt(tracker, 9), isNull);
      expect(leftAt(tracker, 9), isNull);
    });

    test('switching from live to a sample starts both feet over', () {
      final tracker = PressureShareTracker();
      for (var i = 0; i < 6; i++) {
        feed(tracker, i, sample: false);
      }
      expect(rightAt(tracker, 6), isNotNull);
      expect(leftAt(tracker, 6), isNotNull);
      feed(tracker, 6, sample: true);
      expect(rightAt(tracker, 6), isNull);
      expect(leftAt(tracker, 6), isNull);
    });

    test('switching from a sample back to live starts both feet over', () {
      final tracker = PressureShareTracker();
      for (var i = 0; i < 6; i++) {
        feed(tracker, i, sample: true);
      }
      expect(rightAt(tracker, 6), isNotNull);
      expect(leftAt(tracker, 6), isNotNull);
      feed(tracker, 6, sample: false);
      expect(rightAt(tracker, 6), isNull);
      expect(leftAt(tracker, 6), isNull);
    });
  });
}
