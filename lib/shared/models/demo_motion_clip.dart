import 'dart:convert';
import 'dart:math' as math;

/// A canned plantar-pressure motion, decoded from a bundled sample recording.
///
/// Two payload shapes are accepted:
///
/// * **schema 2** — the pair format: `feet.left` / `feet.right`, each with a
///   self-describing `columns` list, `t_ms` relative to that foot's
///   `base_ts_ms`, and its own sample rate. Both feet are resampled onto one
///   timeline, so they are frame-for-frame in step however they were recorded.
/// * **schema 1** — the flat, right-foot-only shape this app's own
///   `buildRecordJson` still exports, so a recording taken on the device can be
///   dropped straight back in as a sample.
///
/// Only the three pressure columns survive; the IMU columns and `slow_channels`
/// exist in the payload but the heat map does not read them.
class DemoMotionClip {
  const DemoMotionClip({
    required this.right,
    required this.left,
    required this.frameInterval,
  });

  /// One `[p0, p1, p2]` reading per frame, in `kSensorLabels` order.
  final List<List<int>> right;

  /// Same timeline as [right], or null when the payload carries no left foot.
  final List<List<int>>? left;

  /// Wall-clock gap between consecutive frames.
  final Duration frameInterval;

  /// Playback ceiling. Every frame makes the heat map recompute its field on
  /// the CPU, so faster recordings are resampled down rather than shown in full.
  static const int defaultMaxRateHz = 25;

  /// Decodes [jsonSource]; returns null if it is not a usable clip.
  static DemoMotionClip? parse(
    String jsonSource, {
    int maxRateHz = defaultMaxRateHz,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonSource);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final version = decoded['schema_version'];
    final tracks = version is num && version >= 2
        ? _pairTracks(decoded)
        : _flatTracks(decoded);
    if (tracks == null) return null;
    return _align(tracks.right, tracks.left, maxRateHz);
  }

  /// schema 2: `feet.right` is required, `feet.left` optional.
  static ({_Track right, _Track? left})? _pairTracks(
    Map<String, dynamic> json,
  ) {
    final feet = json['feet'];
    if (feet is! Map<String, dynamic>) return null;
    final right = _readFoot(feet['right'], _namedColumns);
    if (right == null) return null;
    return (right: right, left: _readFoot(feet['left'], _namedColumns));
  }

  /// schema 1: one flat `samples` list, right foot only.
  static ({_Track right, _Track? left})? _flatTracks(
    Map<String, dynamic> json,
  ) {
    final track = _readFoot(json, _flatColumns);
    return track == null ? null : (right: track, left: null);
  }

  /// Resamples both feet onto one timeline and packs them into a clip.
  static DemoMotionClip? _align(_Track right, _Track? left, int maxRateHz) {
    final tracks = [right, if (left != null) left];

    // Play no faster than the cap, and no faster than the slowest source.
    final rate = tracks
        .map((t) => t.rateHz)
        .fold(maxRateHz.toDouble(), math.min);
    final stepMs = math.max(1, (1000 / rate).round());

    // The window every foot actually covers.
    final start = tracks.map((t) => t.times.first).reduce(math.max);
    final end = tracks.map((t) => t.times.last).reduce(math.min);
    if (end < start) return null;
    final frames = (end - start) ~/ stepMs + 1;

    return DemoMotionClip(
      right: right.resample(frames, start, stepMs),
      left: left?.resample(frames, start, stepMs),
      frameInterval: Duration(milliseconds: stepMs),
    );
  }
}

/// Column layout of a schema-1 sample row:
/// `[ts_ms, ax, ay, az, gx, gy, gz, p0, p1, p2, wear_status, battery_percent]`.
const _flatColumns = (time: 0, pressure: [7, 8, 9]);

/// Sentinel telling [_readFoot] to take the layout from the node's own
/// `columns` list instead.
const _namedColumns = (time: -1, pressure: <int>[]);

/// One foot's pressure trace on a corrected, ascending millisecond timeline.
class _Track {
  const _Track(this.times, this.pressure, this.rateHz);

  final List<int> times;
  final List<List<int>> pressure;
  final double rateHz;

  /// Nearest-preceding sample at each step of the shared timeline.
  List<List<int>> resample(int frames, int startMs, int stepMs) {
    final out = <List<int>>[];
    var i = 0;
    for (var k = 0; k < frames; k++) {
      final target = startMs + k * stepMs;
      while (i + 1 < times.length && times[i + 1] <= target) {
        i++;
      }
      out.add(pressure[i]);
    }
    return List.unmodifiable(out);
  }
}

_Track? _readFoot(Object? node, ({int time, List<int> pressure}) layout) {
  if (node is! Map<String, dynamic>) return null;

  var timeIndex = layout.time;
  var pressureIndex = layout.pressure;
  if (timeIndex < 0) {
    final columns = node['columns'];
    if (columns is! List) return null;
    final names = columns.map((c) => '$c').toList();
    timeIndex = names.indexOf('t_ms');
    pressureIndex = ['p0', 'p1', 'p2'].map(names.indexOf).toList();
    if (timeIndex < 0 || pressureIndex.any((i) => i < 0)) return null;
  }
  final widest = [timeIndex, ...pressureIndex].reduce(math.max);

  final rate =
      (node['sample_rate_hz_measured'] as num?) ??
      (node['sample_rate_hz_declared'] as num?) ??
      (node['sample_rate_hz'] as num?);
  if (rate == null || rate <= 0) return null;

  // Whatever this device's clock was off by, relative to the payload's
  // alignment reference.
  final offset = (node['clock_offset_ms'] as num?)?.toDouble() ?? 0;

  final samples = node['samples'];
  if (samples is! List || samples.isEmpty) return null;

  final times = <int>[];
  final pressure = <List<int>>[];
  for (final row in samples) {
    if (row is! List || row.length <= widest) return null;
    final t = row[timeIndex];
    if (t is! num) return null;
    if (times.isNotEmpty && t + offset < times.last) return null;
    times.add((t + offset).round());
    final reading = <int>[];
    for (final i in pressureIndex) {
      final value = row[i];
      if (value is! num) return null;
      reading.add(value.round());
    }
    pressure.add(List.unmodifiable(reading));
  }
  return _Track(times, pressure, rate.toDouble());
}
