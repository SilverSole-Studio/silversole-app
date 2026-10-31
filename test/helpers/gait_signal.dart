import 'dart:math' as math;

/// One raw sample as the sample bus carries it: phone time and
/// `[hallux, little toe, heel]`.
typedef RawSample = ({DateTime t, List<int> pressure});

/// A foot-down span a synthetic signal is built around, from the signal's
/// origin.
typedef PlannedContact = ({Duration start, Duration end});

/// Evenly spaced contacts: one every [stride], each [stance] long.
List<PlannedContact> walkContacts({
  required int count,
  Duration first = const Duration(seconds: 1),
  Duration stride = const Duration(milliseconds: 1100),
  Duration stance = const Duration(milliseconds: 650),
}) => [
  for (var i = 0; i < count; i++)
    (start: first + stride * i, end: first + stride * i + stance),
];

/// Raw samples for one foot: [baseline] in the air, ramping over [ramp] to
/// [peak] while a planned contact holds it down, plus ±[noise] and up to
/// ±half a sample period of timing [jitter] (0 → 1).
List<RawSample> footSignal({
  required DateTime origin,
  required Duration length,
  List<PlannedContact> contacts = const [],
  int hz = 50,
  int baseline = 40,
  int peak = 3000,
  Duration ramp = const Duration(milliseconds: 40),
  int noise = 30,
  double jitter = 0,
  int seed = 1,
}) {
  final random = math.Random(seed);
  final periodUs = 1000000 ~/ hz;
  return [
    for (var us = 0; us <= length.inMicroseconds; us += periodUs)
      _sample(
        origin,
        Duration(
          microseconds: math.max(
            0,
            us + (jitter * periodUs * (random.nextDouble() - 0.5)).round(),
          ),
        ),
        _load(Duration(microseconds: us), contacts, baseline, peak, ramp) +
            random.nextInt(2 * noise + 1) -
            noise,
      ),
  ];
}

/// Raw samples swinging between [low] and [high] once per [period] — a wearer
/// standing and shifting weight from foot to foot.
List<RawSample> sineSignal({
  required DateTime origin,
  required Duration length,
  required Duration period,
  required int low,
  required int high,
  int hz = 50,
}) {
  final periodUs = 1000000 ~/ hz;
  return [
    for (var us = 0; us <= length.inMicroseconds; us += periodUs)
      _sample(
        origin,
        Duration(microseconds: us),
        low +
            ((high - low) *
                    (0.5 +
                        0.5 *
                            math.sin(
                              2 * math.pi * us / period.inMicroseconds,
                            )))
                .round(),
      ),
  ];
}

/// Merges per-foot signals into one stream ordered by time, as the bus would
/// deliver them.
List<({String sole, RawSample sample})> interleave(
  Map<String, List<RawSample>> feet,
) {
  final all = [
    for (final entry in feet.entries)
      for (final s in entry.value) (sole: entry.key, sample: s),
  ];
  all.sort((a, b) => a.sample.t.compareTo(b.sample.t));
  return all;
}

RawSample _sample(DateTime origin, Duration at, int load) {
  final total = math.max(0, load);
  final hallux = total * 3 ~/ 10;
  final little = total * 2 ~/ 10;
  return (t: origin.add(at), pressure: [hallux, little, total - hallux - little]);
}

int _load(
  Duration at,
  List<PlannedContact> contacts,
  int baseline,
  int peak,
  Duration ramp,
) {
  for (final c in contacts) {
    if (at < c.start || at > c.end) continue;
    final rise = (at - c.start).inMicroseconds / ramp.inMicroseconds;
    final fall = (c.end - at).inMicroseconds / ramp.inMicroseconds;
    final f = math.min(1.0, math.min(rise, fall));
    return baseline + ((peak - baseline) * f).round();
  }
  return baseline;
}
