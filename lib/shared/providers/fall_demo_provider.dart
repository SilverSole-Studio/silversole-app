import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/utils/fall_tilt_detector.dart';

import 'telemetry_process_providers/live_telemetry_notifier.dart';

/// How far along the demo fall judgement is.
///
/// Temporary — see [FallTiltDetector]. Nothing is notified, counted or stored;
/// the only consumer is the red `FallDemoOverlay`.
///
/// Listens on `updatedAt` rather than on the sample itself: that timestamp is
/// rewritten on every notify, so two identical samples in a row cannot stall
/// the hold. No timer is needed either — samples arrive at 20–50 Hz, so both
/// the three-second mark and the progress bar keep up on sample ticks alone.
class FallDemoNotifier extends Notifier<FallTilt> {
  final _detector = FallTiltDetector();

  @override
  FallTilt build() {
    ref.listen(liveTelemetryProvider.select((s) => s.updatedAt), (_, _) {
      final sample = ref.read(liveTelemetryProvider).recentImu.lastOrNull;
      if (sample == null) return;
      state = _detector.update(
        pitch: sample.pitch,
        roll: sample.roll,
        pressure: sample.pressure,
        now: clock.now(),
      );
    });
    return FallTilt.idle;
  }
}

final fallDemoProvider = NotifierProvider<FallDemoNotifier, FallTilt>(
  FallDemoNotifier.new,
);
