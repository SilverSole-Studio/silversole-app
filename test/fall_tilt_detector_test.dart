import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/utils/fall_tilt_detector.dart';

/// FSR values well clear of the "being stood on" floor.
const _loaded = [900, 700, 800];
const _unloaded = [0, 0, 0];

void main() {
  final start = DateTime(2026, 1, 1, 12);
  DateTime at(num seconds) =>
      start.add(Duration(milliseconds: (seconds * 1000).round()));

  /// Most tests only care about the angle, so the sole counts as stood on
  /// unless a test says otherwise.
  FallTilt feed(
    FallTiltDetector detector, {
    double? pitch,
    double? roll,
    List<int> pressure = _loaded,
    required num seconds,
  }) => detector.update(
    pitch: pitch,
    roll: roll,
    pressure: pressure,
    now: at(seconds),
  );

  test('a gentle tilt never triggers and reports no progress', () {
    final detector = FallTiltDetector();
    expect(feed(detector, pitch: 40, roll: 10, seconds: 0), FallTilt.idle);
    final still = feed(detector, pitch: 69, seconds: 10);
    expect(still.fallen, isFalse);
    expect(still.progress, 0);
  });

  test('a steep tilt has to hold for the full three seconds', () {
    final detector = FallTiltDetector();
    expect(feed(detector, pitch: 80, seconds: 0).fallen, isFalse);
    expect(feed(detector, pitch: 80, seconds: 2.9).fallen, isFalse);
    expect(feed(detector, pitch: 80, seconds: 3).fallen, isTrue);
  });

  test('progress tracks the hold so the overlay can pace its buzzing', () {
    final detector = FallTiltDetector();
    feed(detector, pitch: 80, seconds: 0);
    expect(feed(detector, pitch: 80, seconds: 1.5).progress, 0.5);
    final full = feed(detector, pitch: 80, seconds: 6);
    expect(full.progress, 1.0, reason: 'progress is clamped');
    expect(full.held, const Duration(seconds: 6));
  });

  test('the readout carries the steeper angle in whole degrees', () {
    final detector = FallTiltDetector();
    expect(
      feed(detector, pitch: -71.4, roll: 82.6, seconds: 0).tiltDegrees,
      83,
    );
  });

  test('either axis can be the steep one, in either direction', () {
    // The firmware's axis mapping and sign convention are unverified, so the
    // judgement must not depend on them.
    for (final (pitch, roll) in [(-80.0, 0.0), (0.0, 80.0), (0.0, -90.0)]) {
      final detector = FallTiltDetector();
      feed(detector, pitch: pitch, roll: roll, seconds: 0);
      expect(
        feed(detector, pitch: pitch, roll: roll, seconds: 3).fallen,
        isTrue,
        reason: 'pitch $pitch roll $roll should count as tipped over',
      );
    }
  });

  test('a missing angle counts as no tilt', () {
    final detector = FallTiltDetector();
    feed(detector, pitch: 85, seconds: 0);
    expect(feed(detector, seconds: 3), FallTilt.idle);
  });

  test('staying down keeps the judgement standing', () {
    final detector = FallTiltDetector();
    feed(detector, pitch: 85, seconds: 0);
    expect(feed(detector, pitch: 85, seconds: 3).fallen, isTrue);
    expect(feed(detector, pitch: 85, seconds: 9).fallen, isTrue);
  });

  group('hysteresis', () {
    test('a dip that stays above the release angle keeps counting', () {
      final detector = FallTiltDetector();
      feed(detector, pitch: 75, seconds: 0);
      // 60° is under the 70° entry angle but over the 50° release angle: the
      // hold must survive it, or noise at the edge restarts the count forever.
      expect(feed(detector, pitch: 60, seconds: 1.5).progress, 0.5);
      expect(feed(detector, pitch: 75, seconds: 3).fallen, isTrue);
    });

    test('dropping under the release angle restarts the hold', () {
      final detector = FallTiltDetector();
      feed(detector, pitch: 85, seconds: 0);
      expect(feed(detector, pitch: 45, seconds: 2), FallTilt.idle);
      expect(feed(detector, pitch: 85, seconds: 2.5).fallen, isFalse);
      expect(feed(detector, pitch: 85, seconds: 5.4).fallen, isFalse);
      expect(feed(detector, pitch: 85, seconds: 5.5).fallen, isTrue);
    });
  });

  group('weight gate', () {
    test('a sole nobody stands on never fires, however long it lies there', () {
      // A shoe on a rack: toe-down at 90° for minutes on end. This is the
      // false positive the gate exists for.
      final detector = FallTiltDetector();
      for (final seconds in [0, 3, 10, 60, 600]) {
        expect(
          feed(detector, pitch: 90, pressure: _unloaded, seconds: seconds),
          FallTilt.idle,
          reason: 'still unworn after ${seconds}s',
        );
      }
    });

    test('a fall takes the weight off, which must not break the judgement', () {
      // The foot leaves the ground as the wearer goes down, so pressure is
      // gone for the whole hold — the recent step is what counts.
      final detector = FallTiltDetector();
      feed(detector, pitch: 5, seconds: 0); // walking: sole loaded, foot flat
      feed(detector, pitch: 85, pressure: _unloaded, seconds: 1); // going down
      expect(
        feed(detector, pitch: 85, pressure: _unloaded, seconds: 4).fallen,
        isTrue,
      );
    });

    test('a step too long ago no longer counts as worn', () {
      final detector = FallTiltDetector();
      feed(detector, pitch: 5, seconds: 0); // last step
      // Tilt starts 11 s later, outside the 10 s window.
      feed(detector, pitch: 85, pressure: _unloaded, seconds: 11);
      expect(
        feed(detector, pitch: 85, pressure: _unloaded, seconds: 14).fallen,
        isFalse,
      );
    });

    test('being stood on again re-opens the gate', () {
      final detector = FallTiltDetector();
      feed(detector, pitch: 90, pressure: _unloaded, seconds: 0);
      // Picked up and put on: a step registers while still tilted.
      feed(detector, pitch: 90, seconds: 20);
      expect(feed(detector, pitch: 90, seconds: 23).fallen, isTrue);
    });
  });
}
