import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/pressure_shares.dart';

void main() {
  final t0 = DateTime(2026, 10, 31, 12);

  PressureShareWindow filled(List<int> pressure, {int count = 10}) {
    final window = PressureShareWindow();
    for (var i = 0; i < count; i++) {
      window.add(t0.add(Duration(milliseconds: i * 100)), pressure);
    }
    return window;
  }

  test('steady standing gives the fore-aft and inner-outer split', () {
    final shares = filled(const [900, 600, 1500]).shares!;
    expect(shares.foreRatio, closeTo(0.5, 1e-9));
    expect(shares.medialRatio, closeTo(0.6, 1e-9));
  });

  test('heel-only load has no inner-outer split', () {
    final shares = filled(const [0, 10, 2000]).shares!;
    expect(shares.foreRatio, closeTo(10 / 2010, 1e-9));
    expect(shares.medialRatio, isNull);
  });

  test('a foot that is not on the insole has no shares', () {
    expect(filled(const [20, 10, 30]).shares, isNull);
    expect(PressureShares.from(const [20, 10, 30]), isNull);
  });

  test('fewer than five samples is not enough', () {
    expect(filled(const [900, 600, 1500], count: 4).shares, isNull);
    expect(filled(const [900, 600, 1500], count: 5).shares, isNotNull);
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
    expect(window.shares!.foreRatio, 0);
  });

  test('readings shorter than three values are ignored', () {
    final window = PressureShareWindow();
    for (var i = 0; i < 10; i++) {
      window.add(t0.add(Duration(milliseconds: i * 100)), const [900, 600]);
    }
    expect(window.shares, isNull);
  });

  test('clear forgets everything', () {
    final window = filled(const [900, 600, 1500]);
    window.clear();
    expect(window.shares, isNull);
  });

  group('PressureShareTracker', () {
    test('counts one reading once and keeps no history for an absent foot', () {
      final tracker = PressureShareTracker();
      final reading = [900, 600, 1500];
      for (var i = 0; i < 10; i++) {
        tracker.update(
          at: t0.add(Duration(milliseconds: i * 100)),
          rightReading: reading,
          hasRight: true,
          leftReading: null,
          isSample: false,
        );
      }
      // The same list handed in ten times is a single sample.
      expect(tracker.right.shares, isNull);
      expect(tracker.left.shares, isNull);
    });

    test('switching to a sample starts both feet over', () {
      final tracker = PressureShareTracker();
      void feed(bool sample, int i) => tracker.update(
        at: t0.add(Duration(milliseconds: i * 100)),
        rightReading: [900, 600, 1500],
        hasRight: true,
        leftReading: [900, 600, 1500],
        isSample: sample,
      );
      for (var i = 0; i < 6; i++) {
        feed(false, i);
      }
      expect(tracker.right.shares, isNotNull);
      expect(tracker.left.shares, isNotNull);
      feed(true, 6);
      expect(tracker.right.shares, isNull);
      expect(tracker.left.shares, isNull);
    });
  });
}
