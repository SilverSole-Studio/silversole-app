import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/gait/bout_filter.dart';
import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/core/gait/step_detector.dart';

final _origin = DateTime(2026, 11, 2, 9);

BoutContact _walked(int startMs, int stanceMs, {int? strideMs, int? swingMs}) =>
    BoutContact(
      contact: Contact(
        start: _origin.add(Duration(milliseconds: startMs)),
        end: _origin.add(Duration(milliseconds: startMs + stanceMs)),
      ),
      stride: strideMs == null ? null : Duration(milliseconds: strideMs),
      swing: swingMs == null ? null : Duration(milliseconds: swingMs),
    );

DailyGait _add(
  DailyGait day,
  GaitFoot foot,
  BoutContact contact, {
  int walkingMs = 1000,
  int steps = 2,
  int doubleSupportMs = 0,
  int bothFeetWalkingMs = 0,
}) => day.withContact(
  foot: foot,
  contact: contact,
  walking: Duration(milliseconds: walkingMs),
  steps: steps,
  doubleSupport: Duration(milliseconds: doubleSupportMs),
  bothFeetWalking: Duration(milliseconds: bothFeetWalkingMs),
);

void main() {
  test('dates are local and zero-padded', () {
    expect(gaitDateKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('stride variation matches the direct calculation', () {
    final strides = [1000, 1100, 1050, 980, 1120, 1010, 1060, 990, 1080, 1030];
    var day = const DailyGait(date: '2026-11-02');
    for (final s in strides) {
      day = _add(
        day,
        GaitFoot.right,
        _walked(0, 600, strideMs: s, swingMs: s - 600),
      );
    }

    final mean = strides.reduce((a, b) => a + b) / strides.length;
    final variance =
        strides.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b) /
        strides.length;
    expect(day.strideCv, closeTo(math.sqrt(variance) / mean, 1e-9));
  });

  test('stride variation needs ten strides', () {
    var day = const DailyGait(date: '2026-11-02');
    for (var i = 0; i < 9; i++) {
      day = _add(
        day,
        GaitFoot.right,
        _walked(0, 600, strideMs: 1000, swingMs: 400),
      );
    }
    expect(day.strideCv, isNull);
  });

  test('cadence, stance share and walking time', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(day, GaitFoot.right, _walked(0, 600), walkingMs: 600);
    for (var i = 1; i < 10; i++) {
      day = _add(
        day,
        GaitFoot.right,
        _walked(i * 1000, 600, strideMs: 1000, swingMs: 400),
      );
    }

    expect(day.steps, 20);
    expect(day.walkingMs, 600 + 9 * 1000);
    expect(day.cadence, closeTo(20 / (9600 / 60000), 1e-9));
    expect(day.stanceRatio, closeTo(600 / (600 + 400), 1e-9));
  });

  test('left-right balance needs both feet', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(day, GaitFoot.right, _walked(0, 600));
    expect(day.symmetry, isNull);

    day = _add(day, GaitFoot.left, _walked(500, 660));
    expect(day.symmetry, closeTo(600 / 660, 1e-9));
  });

  test('a sole with no side assigned never counts towards balance', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(day, GaitFoot.right, _walked(0, 600));
    day = _add(day, GaitFoot.unknown, _walked(500, 600));
    expect(day.symmetry, isNull);
  });

  test('double support is a share of the time both feet walked', () {
    var day = const DailyGait(date: '2026-11-02');
    expect(day.doubleSupportRatio, isNull);
    day = _add(
      day,
      GaitFoot.right,
      _walked(0, 600),
      steps: 1,
      doubleSupportMs: 100,
      bothFeetWalkingMs: 550,
    );
    expect(day.doubleSupportRatio, closeTo(100 / 550, 1e-9));
  });

  test('merging two halves equals recording the whole day', () {
    var whole = const DailyGait(date: '2026-11-02');
    var first = const DailyGait(date: '2026-11-02');
    var second = const DailyGait(date: '2026-11-02');
    for (var i = 0; i < 12; i++) {
      final c = _walked(i * 1000, 600 + i, strideMs: 1000 + i, swingMs: 400);
      final foot = i.isEven ? GaitFoot.left : GaitFoot.right;
      whole = _add(
        whole,
        foot,
        c,
        steps: 1,
        doubleSupportMs: 50,
        bothFeetWalkingMs: 500,
      );
      if (i < 6) {
        first = _add(
          first,
          foot,
          c,
          steps: 1,
          doubleSupportMs: 50,
          bothFeetWalkingMs: 500,
        );
      } else {
        second = _add(
          second,
          foot,
          c,
          steps: 1,
          doubleSupportMs: 50,
          bothFeetWalkingMs: 500,
        );
      }
    }

    expect(first.merge(second).toJson(), whole.toJson());
  });

  test('round-trips through JSON and rejects anything else', () {
    var day = const DailyGait(date: '2026-11-02');
    day = _add(
      day,
      GaitFoot.left,
      _walked(0, 600, strideMs: 1000, swingMs: 400),
    );
    day = _add(
      day,
      GaitFoot.right,
      _walked(500, 640),
      doubleSupportMs: 80,
      bothFeetWalkingMs: 500,
    );

    expect(DailyGait.tryFromJson(day.toJson())?.toJson(), day.toJson());
    expect(DailyGait.tryFromJson('nope'), isNull);
    expect(DailyGait.tryFromJson({'date': '2026-11-02'}), isNull);
  });
}
