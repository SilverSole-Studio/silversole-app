import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_tracker.dart';
import 'package:silversole/shared/models/foot_side.dart';

import 'helpers/gait_signal.dart';

final _origin = DateTime(2026, 11, 2, 9);

GaitTracker _tracker() => GaitTracker(
  footOf: (key) => switch (key) {
    'L' => FootSide.left,
    'R' => FootSide.right,
    _ => null,
  },
);

void _feed(GaitTracker tracker, String sole, List<RawSample> samples) {
  for (final s in samples) {
    tracker.add(sole, s.t, s.pressure);
  }
}

DailyGait _single(List<DailyGait> days) {
  expect(days, hasLength(1));
  return days.single;
}

void main() {
  test('one sole walking twenty contacts makes forty steps', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 25),
        contacts: walkContacts(count: 20),
      ),
    );

    final day = _single(tracker.takePending());
    expect(day.date, '2026-11-02');
    expect(day.steps, 40);
    expect(day.feet[GaitFoot.right]?.contacts, 20);
    expect(day.feet[GaitFoot.right]?.strides, 19);
    // 19 strides of 1.1 s plus the last 0.65 s stance.
    expect(day.walkingMs, closeTo(21550, 300));
    expect(day.cadence, inInclusiveRange(100, 115));
    expect(day.symmetry, isNull);
    expect(day.doubleSupportRatio, isNull);
  });

  test('four landings are not a walk, five are', () {
    final four = _tracker();
    _feed(
      four,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 8),
        contacts: walkContacts(count: 4),
      ),
    );
    expect(four.takePending(), isEmpty);
    expect(four.rawContactCount, 4);

    final five = _tracker();
    _feed(
      five,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 8),
        contacts: walkContacts(count: 5),
      ),
    );
    expect(_single(five.takePending()).steps, 10);
  });

  test('standing and shifting weight is not walking', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      sineSignal(
        origin: _origin,
        length: const Duration(seconds: 60),
        period: const Duration(seconds: 3),
        low: 1000,
        high: 2000,
      ),
    );
    expect(tracker.takePending(), isEmpty);
  });

  test('two soles walking count each contact once', () {
    final tracker = _tracker();
    final feed = interleave({
      // Short ramps: with the default 40 ms the thresholds cut ~25 ms off
      // each end of a contact and the overlaps shrink to half.
      'R': footSignal(
        origin: _origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(count: 20),
        ramp: const Duration(milliseconds: 10),
        seed: 1,
      ),
      'L': footSignal(
        origin: _origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(
          count: 20,
          first: const Duration(milliseconds: 1550),
        ),
        ramp: const Duration(milliseconds: 10),
        seed: 2,
      ),
    });
    for (final f in feed) {
      tracker.add(f.sole, f.sample.t, f.sample.pressure);
    }

    final day = _single(tracker.takePending());
    expect(day.steps, 40);
    expect(day.symmetry, closeTo(1, 0.05));
    // Each foot overlaps the other by 0.1 s at both ends of a 1.1 s stride.
    expect(day.doubleSupportRatio, closeTo(0.2 / 1.1, 0.05));
  });

  test('a walk across midnight is split between the two days', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      footSignal(
        origin: DateTime(2026, 11, 2, 23, 59, 50),
        length: const Duration(seconds: 25),
        contacts: walkContacts(count: 20),
      ),
    );

    final days = tracker.takePending()
      ..sort((a, b) => a.date.compareTo(b.date));
    expect(days.map((d) => d.date), ['2026-11-02', '2026-11-03']);
    expect(days.fold(0, (n, d) => n + d.steps), 40);
  });

  test('pending days are handed over once', () {
    final tracker = _tracker();
    _feed(
      tracker,
      'R',
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 25),
        contacts: walkContacts(count: 20),
      ),
    );
    expect(tracker.takePending(), hasLength(1));
    expect(tracker.takePending(), isEmpty);
  });
}
