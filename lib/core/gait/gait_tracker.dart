import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_config.dart';
import 'package:silversole/core/gait/step_detector.dart';
import 'package:silversole/shared/models/foot_side.dart';

/// The foot a sole is worn on, or null while it has none assigned.
typedef FootLookup = FootSide? Function(String soleKey);

/// Runs the gait pipeline for every sole and adds up what it finds per day.
///
/// Each sole gets its own [StepDetector] and [BoutFilter]. A walking contact
/// counts as two steps while it is the only sole walking — the other foot is
/// assumed — and as one while another sole is walking too. "Walking too" is
/// judged on the other sole's raw contacts rather than its released ones,
/// because a bout releases its first contacts in a burst once confirmed.
///
/// With both feet walking, each second of walking is seen once from either
/// foot, so it is counted at half weight; together the feet come to the real
/// figure. An overlap between two contacts, on the other hand, is counted once
/// by whichever of the two ends later, so it needs no halving.
class GaitTracker {
  GaitTracker({required FootLookup footOf, this.config = const GaitConfig()})
    : _footOf = footOf;

  final GaitConfig config;
  final FootLookup _footOf;

  final _soles = <String, _Sole>{};
  final _pending = <String, DailyGait>{};
  int _rawContacts = 0;

  /// Raw contacts kept per sole for the double-support overlap: enough to
  /// cover a bout's backlog when it is released.
  static const _rawKept = 8;

  /// Contacts found before the bout filter — for tuning (`tool/gait_replay.dart`).
  int get rawContactCount => _rawContacts;

  void add(String soleKey, DateTime t, List<int> pressure) {
    final sole = _soles.putIfAbsent(soleKey, () => _Sole(config));
    final contact = sole.detector.add(t, pressure);
    if (contact == null) return;

    _rawContacts++;
    sole.recentRaw.add(contact);
    if (sole.recentRaw.length > _rawKept) sole.recentRaw.removeAt(0);

    for (final walked in sole.bouts.add(contact)) {
      _record(soleKey, sole, walked, now: t);
    }
  }

  /// Everything recorded since the last call, one entry per local date, and
  /// forgets it.
  List<DailyGait> takePending() {
    final days = _pending.values.toList();
    _pending.clear();
    return days;
  }

  void _record(
    String soleKey,
    _Sole sole,
    BoutContact walked, {
    required DateTime now,
  }) {
    final contact = walked.contact;
    final other = _otherWalking(soleKey, now);
    final previous = sole.lastWalked;
    final walking = walked.startsBout || previous == null
        ? contact.duration
        : contact.end.difference(previous.end);

    var overlap = Duration.zero;
    if (other != null) {
      for (final o in other.recentRaw) {
        // Only the contact that ends later counts a pair's overlap, so each
        // pair is counted once even when a bout releases a backlog.
        if (o.end.isAfter(contact.end)) continue;
        overlap += _overlap(contact, o);
      }
    }

    final date = gaitDateKey(contact.start);
    _pending[date] = (_pending[date] ?? DailyGait(date: date)).withContact(
      foot: GaitFoot.of(_footOf(soleKey)),
      contact: walked,
      walking: walking,
      steps: other == null ? 2 : 1,
      doubleSupport: overlap,
      bothFeetWalking: other == null ? Duration.zero : walking ~/ 2,
    );
    sole.lastWalked = contact;
  }

  _Sole? _otherWalking(String soleKey, DateTime now) {
    for (final entry in _soles.entries) {
      if (entry.key == soleKey) continue;
      final raw = entry.value.recentRaw;
      if (raw.isEmpty) continue;
      if (now.difference(raw.last.end) <= config.otherFootActive) {
        return entry.value;
      }
    }
    return null;
  }

  static Duration _overlap(Contact a, Contact b) {
    final start = a.start.isAfter(b.start) ? a.start : b.start;
    final end = a.end.isBefore(b.end) ? a.end : b.end;
    return end.isAfter(start) ? end.difference(start) : Duration.zero;
  }
}

class _Sole {
  _Sole(GaitConfig config)
    : detector = StepDetector(config),
      bouts = BoutFilter(config);

  final StepDetector detector;
  final BoutFilter bouts;
  final recentRaw = <Contact>[];
  Contact? lastWalked;
}
