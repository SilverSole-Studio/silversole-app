import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/step_detector.dart';

import 'helpers/gait_signal.dart';

final _origin = DateTime(2026, 11, 2, 9);

List<Contact> _run(StepDetector detector, List<RawSample> samples) {
  final found = <Contact>[];
  for (final s in samples) {
    final contact = detector.add(s.t, s.pressure);
    if (contact != null) found.add(contact);
  }
  return found;
}

void main() {
  for (final hz in [50, 20]) {
    test('finds every contact of a steady walk at $hz Hz', () {
      final planned = walkContacts(count: 12);
      final found = _run(
        StepDetector(),
        footSignal(
          origin: _origin,
          length: const Duration(seconds: 15),
          contacts: planned,
          hz: hz,
          jitter: 0.5,
        ),
      );

      expect(found, hasLength(12));
      for (var i = 0; i < planned.length; i++) {
        final start = found[i].start.difference(_origin.add(planned[i].start));
        final end = found[i].end.difference(_origin.add(planned[i].end));
        expect(start.inMilliseconds.abs(), lessThanOrEqualTo(100));
        expect(end.inMilliseconds.abs(), lessThanOrEqualTo(100));
      }
    });
  }

  test('a steady load is not a step', () {
    final found = _run(
      StepDetector(),
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 20),
        baseline: 1500,
      ),
    );
    expect(found, isEmpty);
  });

  test('an empty sole is not a step', () {
    final found = _run(
      StepDetector(),
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 20),
        baseline: 0,
        noise: 0,
      ),
    );
    expect(found, isEmpty);
  });

  test('a contact cut by a gap in the data is dropped', () {
    final samples = footSignal(
      origin: _origin,
      length: const Duration(seconds: 15),
      contacts: walkContacts(count: 12),
    );
    // Contact 3 runs 3.2–3.85 s; nothing arrives from 3.3 to 4.1 s.
    final cut = [
      for (final s in samples)
        if (s.t.isBefore(_origin.add(const Duration(milliseconds: 3300))) ||
            s.t.isAfter(_origin.add(const Duration(milliseconds: 4100))))
          s,
    ];

    final found = _run(StepDetector(), cut);

    expect(found, hasLength(11));
    expect(
      found.where(
        (c) =>
            c.start.isAfter(_origin.add(const Duration(milliseconds: 3100))) &&
            c.start.isBefore(_origin.add(const Duration(milliseconds: 3400))),
      ),
      isEmpty,
    );
  });

  test('a contact shorter than the minimum is dropped', () {
    final found = _run(
      StepDetector(),
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 15),
        contacts: walkContacts(
          count: 12,
          stance: const Duration(milliseconds: 100),
        ),
      ),
    );
    expect(found, isEmpty);
  });

  test('a single spike does not blind the detector', () {
    final samples = footSignal(
      origin: _origin,
      length: const Duration(seconds: 15),
      contacts: walkContacts(count: 12),
    );
    // Contact 2 ends at 3.85 s and contact 3 starts at 4.3 s, so 4.0 s is
    // mid-swing: the foot is in the air and one glitch sample lands there.
    final glitched = [
      for (final s in samples)
        s.t.difference(_origin) == const Duration(seconds: 4)
            ? (t: s.t, pressure: [10000, 10000, 10000])
            : s,
    ];
    expect(glitched.where((s) => s.pressure[0] == 10000), hasLength(1));

    expect(_run(StepDetector(), glitched), hasLength(12));
  });

  test('a light wearer is still seen', () {
    final found = _run(
      StepDetector(),
      footSignal(
        origin: _origin,
        length: const Duration(seconds: 15),
        contacts: walkContacts(count: 12),
        peak: 600,
      ),
    );
    expect(found, hasLength(12));
  });

  test('a stance with a dip in the middle is one contact', () {
    final planned = walkContacts(count: 12);
    final samples = footSignal(
      origin: _origin,
      length: const Duration(seconds: 15),
      contacts: planned,
    );
    // Heel hump, trough at 55 % of peak, push-off hump.
    bool inDip(DateTime t) {
      final at = t.difference(_origin);
      return planned.any((c) {
        final third = (c.end - c.start) ~/ 3;
        return at >= c.start + third && at <= c.end - third;
      });
    }

    final dipped = [
      for (final s in samples)
        inDip(s.t)
            ? (
                t: s.t,
                pressure: [for (final p in s.pressure) (p * 0.55).round()],
              )
            : s,
    ];

    expect(_run(StepDetector(), dipped), hasLength(12));
  });

  test('a short gap does not reset', () {
    final samples = footSignal(
      origin: _origin,
      length: const Duration(seconds: 15),
      contacts: walkContacts(count: 12),
    );
    // Contact 3 ends at 4.95 s and contact 4 starts at 5.4 s: 300 ms of
    // silence in the middle of that swing.
    final cut = [
      for (final s in samples)
        if (s.t.isBefore(_origin.add(const Duration(milliseconds: 5000))) ||
            s.t.isAfter(_origin.add(const Duration(milliseconds: 5300))))
          s,
    ];

    expect(_run(StepDetector(), cut), hasLength(12));
  });
}
