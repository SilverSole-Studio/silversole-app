import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/gait_tracker.dart';
import 'package:silversole/shared/models/demo_motion_clip.dart';
import 'package:silversole/shared/models/foot_side.dart';

void main() {
  test('the bundled synthetic walk comes out as walking on both feet', () {
    final clip = DemoMotionClip.parse(
      File(
        'assets/foot-pressure-heatmpt-samples/synthetic_walk_pair_30s.json',
      ).readAsStringSync(),
      maxRateHz: 1000,
    );
    expect(clip, isNotNull);
    final left = clip!.left;
    expect(left, isNotNull);

    final tracker = GaitTracker(
      footOf: (key) => key == 'L' ? FootSide.left : FootSide.right,
    );
    final origin = DateTime(2026, 11, 2, 9);
    for (var i = 0; i < clip.right.length; i++) {
      final t = origin.add(clip.frameInterval * i);
      tracker.add('R', t, clip.right[i]);
      tracker.add('L', t, left![i]);
    }

    final days = tracker.takePending();
    expect(days, hasLength(1));
    final day = days.single;
    expect(day.steps, greaterThan(20));
    expect(day.cadence, isNotNull);
    expect(day.symmetry, isNotNull);
  });
}
