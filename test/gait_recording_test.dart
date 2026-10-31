import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/gait_recording.dart';
import 'package:silversole/shared/models/foot_side.dart';

import 'helpers/gait_signal.dart';

void main() {
  final origin = DateTime(2026, 11, 2, 9);

  test('a recording replays to the same walk', () {
    final recording = GaitRecording(origin);
    final feed = interleave({
      'R': footSignal(
        origin: origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(count: 20),
      ),
      'L': footSignal(
        origin: origin,
        length: const Duration(seconds: 26),
        contacts: walkContacts(
          count: 20,
          first: const Duration(milliseconds: 1550),
        ),
        seed: 2,
      ),
    });
    for (final f in feed) {
      recording.add(
        at: f.sample.t,
        soleKey: f.sole,
        foot: f.sole == 'L' ? FootSide.left : FootSide.right,
        pressure: f.sample.pressure,
        imu: const [0, 0, 0, 0, 0, 0],
      );
    }

    final result = replayGaitRecording(recording.encode());

    expect(result, isNotNull);
    expect(result!.samples, feed.length);
    expect(result.rawContacts, 40);
    expect(result.day.steps, 40);
    expect(result.day.symmetry, isNotNull);
  });

  test('anything else is refused', () {
    expect(replayGaitRecording('not json'), isNull);
    expect(replayGaitRecording('{"format":"something-else"}'), isNull);
  });
}
