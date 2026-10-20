import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/ble/foot_side_calibration.dart';

const _left = 'L';
const _right = 'R';
final _t0 = DateTime(2026, 10, 20, 9);

/// Feeds frames [from]..[from]+[count] to both soles at 50 Hz and returns the
/// first decision that came out, or null.
FootSideDecision? _frames(
  FootSideCalibrator calibrator, {
  required int from,
  required int count,
  required int left,
  required int right,
}) {
  FootSideDecision? decision;
  for (var i = from; i < from + count; i++) {
    final at = _t0.add(Duration(milliseconds: 20 * i));
    decision ??= calibrator.add(_left, left, at);
    decision ??= calibrator.add(_right, right, at);
  }
  return decision;
}

void main() {
  test('both soles resting decides nothing', () {
    final calibrator = FootSideCalibrator();
    expect(
      _frames(calibrator, from: 0, count: 200, left: 40, right: 40),
      isNull,
    );
  });

  test('the sole that was stepped on is the left foot', () {
    final calibrator = FootSideCalibrator();
    // A second of standing still fills the baselines.
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30, // 600 ms — past the 200 ms arbitration window
      left: 2000,
      right: 40,
    );
    expect(decision?.ambiguous, isFalse);
    expect(decision?.leftKey, _left);
  });

  test('stepping on the other sole makes that one the left foot', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30,
      left: 40,
      right: 2000,
    );
    expect(decision?.leftKey, _right);
  });

  test('a step both soles felt equally is ambiguous', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30,
      left: 2000,
      right: 2000,
    );
    expect(decision?.ambiguous, isTrue);
    expect(decision?.leftKey, isNull);
  });

  test('a clearly harder step still wins when both soles move', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 50,
      count: 30,
      left: 2000,
      right: 440, // delta 400 — over the trigger, far under 80% of 1960
    );
    expect(decision?.leftKey, _left);
  });

  test('one noisy sample is not a step', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    _frames(calibrator, from: 50, count: 1, left: 2000, right: 40);
    expect(
      _frames(calibrator, from: 51, count: 30, left: 40, right: 40),
      isNull,
    );
  });

  // The other sole may be connected but silent — a dead FSR, or notifications
  // that have not started yet. Calling the only sole that reports pressure the
  // left foot would be a coin flip dressed up as a measurement.
  test('a sole that reports nothing at all blocks any decision', () {
    final calibrator = FootSideCalibrator();
    for (var i = 0; i < 50; i++) {
      calibrator.add(_left, 40, _t0.add(Duration(milliseconds: 20 * i)));
    }
    FootSideDecision? decision;
    for (var i = 50; i < 120; i++) {
      decision ??= calibrator.add(
        _left,
        2000,
        _t0.add(Duration(milliseconds: 20 * i)),
      );
    }
    expect(decision, isNull);
  });

  test('a step during baseline collection is absorbed, not trusted', () {
    final calibrator = FootSideCalibrator();
    // Pressed from the very first sample: the baseline ends up high, so the
    // same reading is no longer a step.
    final decision = _frames(
      calibrator,
      from: 0,
      count: 200,
      left: 2000,
      right: 40,
    );
    expect(decision, isNull);
  });

  // Both soles are registered, but the right one has only 1 of 50 baseline
  // samples. Its baseline is unfinished, so the left sole's step must not be
  // decided on — removing the per-sole baseline check would let it through.
  test('a registered sole still building its baseline blocks the verdict', () {
    final calibrator = FootSideCalibrator();
    calibrator.add(_right, 40, _t0);
    FootSideDecision? decision;
    for (var i = 0; i < 80; i++) {
      final at = _t0.add(Duration(milliseconds: 20 * i));
      decision ??= calibrator.add(_left, i < 50 ? 40 : 2000, at);
    }
    expect(decision, isNull);
  });

  // Feed order is load-bearing: the left sole is added before the right one
  // in every frame, and the left sole trips the trigger first (frame 52). The
  // right sole is still at rest then and only steps from frame 53, inside the
  // arbitration window. A decision taken at the first trigger would compare
  // 400 against nothing and answer left; the window lets the right sole's
  // peak arrive and decide it.
  test('the harder step wins when it arrives inside the window', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    FootSideDecision? decision;
    for (var i = 50; i < 80; i++) {
      final at = _t0.add(Duration(milliseconds: 20 * i));
      decision ??= calibrator.add(_left, 440, at); // delta 400, but weaker
      decision ??= calibrator.add(_right, i < 53 ? 40 : 2000, at);
    }
    expect(decision?.ambiguous, isFalse);
    expect(decision?.leftKey, _right);
  });

  // The left sole glitches to 2000 for a single frame and is back at rest, so
  // that is not a step. Its peak must not survive into the window: otherwise
  // the glitch's 1960 ties the right sole's real 1960 and the verdict is
  // ambiguous.
  test('a one-frame glitch on the other sole does not decide the step', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    FootSideDecision? decision;
    for (var i = 50; i < 80; i++) {
      final at = _t0.add(Duration(milliseconds: 20 * i));
      decision ??= calibrator.add(_left, i == 50 ? 2000 : 40, at);
      decision ??= calibrator.add(_right, i < 51 ? 40 : 2000, at);
    }
    expect(decision?.ambiguous, isFalse);
    expect(decision?.leftKey, _right);
  });

  // Spike, rest, spike, rest, ... never three samples in a row over the
  // trigger, so no spike is a step. Without the streak reset the spikes would
  // add up across the rests and trip it.
  test('spikes separated by rests never add up to a step', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    FootSideDecision? decision;
    for (var i = 50; i < 110; i++) {
      final at = _t0.add(Duration(milliseconds: 20 * i));
      decision ??= calibrator.add(_left, i.isEven ? 2000 : 40, at);
      decision ??= calibrator.add(_right, 40, at);
    }
    expect(decision, isNull);
  });

  // reset() must clear the arbitration window as well as the verdict. If it
  // kept the old window end, the new run's baselines would finish after that
  // time had already passed, and the verdict would come out ambiguous at once
  // (both peaks zero).
  test('a reset after an ambiguous verdict starts a clean run', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    expect(
      _frames(
        calibrator,
        from: 50,
        count: 30,
        left: 2000,
        right: 2000,
      )?.ambiguous,
      isTrue,
    );
    calibrator.reset();
    _frames(calibrator, from: 80, count: 50, left: 40, right: 40);
    final decision = _frames(
      calibrator,
      from: 130,
      count: 30,
      left: 2000,
      right: 40,
    );
    expect(decision?.ambiguous, isFalse);
    expect(decision?.leftKey, _left);
  });

  test('reset starts over', () {
    final calibrator = FootSideCalibrator();
    _frames(calibrator, from: 0, count: 50, left: 40, right: 40);
    expect(
      _frames(calibrator, from: 50, count: 30, left: 2000, right: 40)?.leftKey,
      _left,
    );
    calibrator.reset();
    expect(
      _frames(calibrator, from: 80, count: 10, left: 2000, right: 40),
      isNull,
    );
  });
}
