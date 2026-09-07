import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/demo_motion_clip.dart';

/// Builds a record-export payload: one row is
/// [ts_ms, ax, ay, az, gx, gy, gz, p0, p1, p2, wear_status, battery_percent].
String _clipJson({
  required int rateHz,
  required List<List<int>> pressures,
  int startTs = 1786506984298,
}) {
  final stepMs = (1000 / rateHz).round();
  return jsonEncode({
    'start_ts_ms': startTs,
    'sample_rate_hz': rateHz,
    'samples': [
      for (var i = 0; i < pressures.length; i++)
        [
          startTs + i * stepMs,
          -52, -196, 2017, 378, 486, -135, // imu columns, ignored
          ...pressures[i],
          false,
          0,
        ],
    ],
  });
}

void main() {
  group('DemoMotionClip.parse', () {
    test('reads the three pressure columns of each sample', () {
      final clip = DemoMotionClip.parse(
        _clipJson(
          rateHz: 25,
          pressures: [
            [600, 380, 2600],
            [680, 440, 2460],
          ],
        ),
        maxRateHz: 25,
      );

      expect(clip, isNotNull);
      expect(clip!.left, isNull);
      expect(clip.right, [
        [600, 380, 2600],
        [680, 440, 2460],
      ]);
    });

    test('keeps every frame when the clip rate is at the cap', () {
      final clip = DemoMotionClip.parse(
        _clipJson(rateHz: 20, pressures: List.filled(10, const [1, 2, 3])),
        maxRateHz: 25,
      );

      expect(clip!.right, hasLength(10));
      expect(clip.frameInterval, const Duration(milliseconds: 50));
    });

    test(
      'decimates a clip faster than the cap and slows the interval to match',
      () {
        final clip = DemoMotionClip.parse(
          _clipJson(
            rateHz: 50,
            pressures: [
              for (var i = 0; i < 6; i++) [i, i, i],
            ],
          ),
          maxRateHz: 25,
        );

        // Stride 2: every other sample survives, played back at 25 Hz.
        expect(clip!.right, [
          [0, 0, 0],
          [2, 2, 2],
          [4, 4, 4],
        ]);
        expect(clip.frameInterval, const Duration(milliseconds: 40));
      },
    );

    test('reads both feet of a schema-2 pair onto one timeline', () {
      String foot(List<List<int>> pressures, {int offsetMs = 0}) => jsonEncode({
        'clock_offset_ms': offsetMs,
        'sample_rate_hz_declared': 50,
        'sample_rate_hz_measured': 50.0,
        'columns': [
          't_ms',
          'ax',
          'ay',
          'az',
          'gx',
          'gy',
          'gz',
          'p0',
          'p1',
          'p2',
        ],
        'samples': [
          for (var i = 0; i < pressures.length; i++)
            [i * 20, 0, 0, 0, 0, 0, 0, ...pressures[i]],
        ],
      });
      final json = jsonEncode({
        'schema_version': 2,
        'feet': {
          'left': jsonDecode(
            foot([
              for (var i = 0; i < 6; i++) [i, i, i],
            ]),
          ),
          'right': jsonDecode(
            foot([
              for (var i = 0; i < 6; i++) [100 + i, 0, 0],
            ]),
          ),
        },
      });

      final clip = DemoMotionClip.parse(json, maxRateHz: 25);

      // 50 Hz resampled to 25 Hz: every other sample, both feet in step.
      expect(clip!.frameInterval, const Duration(milliseconds: 40));
      expect(clip.right, [
        [100, 0, 0],
        [102, 0, 0],
        [104, 0, 0],
      ]);
      expect(clip.left, [
        [0, 0, 0],
        [2, 2, 2],
        [4, 4, 4],
      ]);
    });

    test('returns null for a payload with no samples', () {
      final clip = DemoMotionClip.parse(_clipJson(rateHz: 50, pressures: []));

      expect(clip, isNull);
    });

    test('returns null when a sample row is missing pressure columns', () {
      final json = jsonEncode({
        'start_ts_ms': 0,
        'sample_rate_hz': 50,
        'samples': [
          [0, 1, 2, 3, 4, 5, 6],
        ],
      });

      expect(DemoMotionClip.parse(json), isNull);
    });

    test('returns null for malformed json', () {
      expect(DemoMotionClip.parse('not json at all'), isNull);
    });

    test('returns null when the sample rate is missing or non-positive', () {
      final json = jsonEncode({
        'sample_rate_hz': 0,
        'samples': [
          [0, 0, 0, 0, 0, 0, 0, 1, 2, 3, false, 0],
        ],
      });

      expect(DemoMotionClip.parse(json), isNull);
    });
  });
}
