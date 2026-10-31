import 'dart:convert';

import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/gait_tracker.dart';
import 'package:silversole/shared/models/foot_side.dart';

/// Format tag on files [GaitRecording.encode] writes; [replayGaitRecording]
/// refuses anything without it.
const gaitRecordingFormat = 'silversole-gait-raw';

/// Raw live samples kept for tuning the step detection: unaveraged pressure
/// with the phone time it arrived, plus the IMU axes for later work on
/// walking speed.
class GaitRecording {
  GaitRecording(this.startedAt);

  final DateTime startedAt;
  final _rows = <List<Object?>>[];

  int get length => _rows.length;

  void add({
    required DateTime at,
    required String soleKey,
    required FootSide? foot,
    required List<int> pressure,
    required List<int> imu,
  }) {
    _rows.add([
      at.millisecondsSinceEpoch,
      soleKey,
      foot?.name,
      ...pressure.take(3),
      ...imu,
    ]);
  }

  String encode() => jsonEncode({
    'format': gaitRecordingFormat,
    'version': 1,
    'started_at': startedAt.toIso8601String(),
    'columns': [
      't_ms',
      'sole',
      'foot',
      'p_hallux',
      'p_little_toe',
      'p_heel',
      'ax',
      'ay',
      'az',
      'gx',
      'gy',
      'gz',
    ],
    'samples': _rows,
  });
}

/// What one recording comes to when run through the gait pipeline.
class GaitReplayResult {
  const GaitReplayResult({
    required this.samples,
    required this.rawContacts,
    required this.day,
  });

  final int samples;
  final int rawContacts;

  /// Every day in the recording folded into one.
  final DailyGait day;
}

/// Runs [json] — a file [GaitRecording.encode] wrote — through a fresh
/// [GaitTracker]. Null if it is not such a file.
GaitReplayResult? replayGaitRecording(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return null;
  }
  if (decoded is! Map || decoded['format'] != gaitRecordingFormat) return null;
  final samples = decoded['samples'];
  if (samples is! List) return null;

  final feet = <String, FootSide?>{};
  final rows = <({DateTime t, String sole, List<int> pressure})>[];
  for (final row in samples) {
    if (row is! List || row.length < 6) continue;
    final t = row[0];
    final sole = row[1];
    final foot = row[2];
    final pressure = row.sublist(3, 6);
    if (t is! int || sole is! String || pressure.any((p) => p is! int)) {
      continue;
    }
    feet[sole] = foot is String ? FootSide.values.asNameMap()[foot] : null;
    rows.add((
      t: DateTime.fromMillisecondsSinceEpoch(t),
      sole: sole,
      pressure: pressure.cast<int>(),
    ));
  }
  rows.sort((a, b) => a.t.compareTo(b.t));

  final tracker = GaitTracker(footOf: (key) => feet[key]);
  for (final r in rows) {
    tracker.add(r.sole, r.t, r.pressure);
  }
  var day = const DailyGait(date: '');
  for (final d in tracker.takePending()) {
    day = day.merge(d);
  }
  return GaitReplayResult(
    samples: rows.length,
    rawContacts: tracker.rawContactCount,
    day: day,
  );
}
