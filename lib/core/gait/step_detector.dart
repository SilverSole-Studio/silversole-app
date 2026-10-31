import 'dart:collection';
import 'dart:math' as math;

import 'package:silversole/core/gait/gait_config.dart';

/// One foot on the ground: from the load rising through the upper threshold
/// to it falling through the lower one.
class Contact {
  const Contact({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is Contact && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Contact($start → $end)';
}

/// Turns one sole's raw pressure into [Contact]s.
///
/// Works on the total load of the three FSRs and needs no calibration: the
/// thresholds sit between the lowest and highest load of the last
/// [GaitConfig.window], so they follow the wearer's weight and the sole's raw
/// counts on their own — the same idea as the two-feet game input's adaptive
/// pressure reference.
///
/// Must be fed **unaveraged** samples: the live moving average would smear
/// the moment the heel lands.
class StepDetector {
  StepDetector([this.config = const GaitConfig()]);

  final GaitConfig config;

  final _window = Queue<({DateTime t, int load})>();
  DateTime? _last;
  DateTime? _contactStart;

  /// Feeds one sample; returns the contact it closes, if any.
  Contact? add(DateTime t, List<int> pressure) {
    final last = _last;
    if (last != null &&
        (t.isBefore(last) || t.difference(last) > config.maxSampleGap)) {
      reset();
    }
    _last = t;

    final load = pressure.fold<int>(0, (sum, p) => sum + p);
    _window.add((t: t, load: load));
    while (t.difference(_window.first.t) > config.window) {
      _window.removeFirst();
    }

    var lo = load;
    var hi = load;
    for (final s in _window) {
      lo = math.min(lo, s.load);
      hi = math.max(hi, s.load);
    }
    final range = hi - lo;
    if (range < config.minLoadRange) {
      _contactStart = null;
      return null;
    }

    final start = _contactStart;
    if (start == null) {
      if (load >= lo + range * config.onFraction) _contactStart = t;
      return null;
    }
    if (load > lo + range * config.offFraction) return null;

    _contactStart = null;
    final contact = Contact(start: start, end: t);
    final length = contact.duration;
    if (length < config.minContact || length > config.maxContact) return null;
    return contact;
  }

  /// Forgets everything: the next sample starts a fresh window.
  void reset() {
    _window.clear();
    _last = null;
    _contactStart = null;
  }
}
