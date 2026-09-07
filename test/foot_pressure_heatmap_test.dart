import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';

const _box = Size(300, 420);

/// Left and right edges of the silhouette on the row [t] of the way down [_box].
({double left, double right}) _borders(ui.Path path, double t) {
  final y = _box.height * t;
  double? left;
  double? right;
  for (var x = 0.0; x <= _box.width; x += 0.25) {
    if (path.contains(Offset(x, y))) {
      left ??= x;
      right = x;
    }
  }
  return (left: left!, right: right!);
}

/// How far a border bows *inward* at the midfoot, relative to the straight line
/// joining its forefoot and heel points.
///
/// Sampling the midfoot exactly halfway between the other two rows makes this
/// immune to the silhouette's tilt: a shear shifts every row's x by an amount
/// linear in y, which the fore/heel average cancels exactly.
({double medial, double lateral}) _archBow(ui.Path path) {
  final fore = _borders(path, 0.25);
  final mid = _borders(path, 0.50);
  final heel = _borders(path, 0.75);
  return (
    medial: mid.left - (fore.left + heel.left) / 2,
    lateral: (fore.right + heel.right) / 2 - mid.right,
  );
}

void main() {
  test('the big-toe sensor sits medial (image-left) on this right foot', () {
    expect(kSensorPositions[0].dx, lessThan(kSensorPositions[1].dx));
  });

  test('the arch bows in on the same side as the big-toe sensor', () {
    final bow = _archBow(footPath(_box));

    // The medial border carries the arch; the lateral border does not bow in.
    expect(
      bow.medial,
      greaterThan(bow.lateral),
      reason:
          'arch is on the lateral side — the silhouette is the wrong foot '
          '(medial bow ${bow.medial}, lateral bow ${bow.lateral})',
    );
    expect(bow.medial, greaterThan(0));
  });

  test('the heel sensor sits inside the heel of the silhouette', () {
    final path = footPath(_box);
    final heel = kSensorPositions[2];
    expect(
      path.contains(Offset(heel.dx * _box.width, heel.dy * _box.height)),
      isTrue,
    );
  });

  test('every sensor marker sits inside the silhouette', () {
    final path = footPath(_box);
    for (final p in kSensorPositions) {
      expect(
        path.contains(Offset(p.dx * _box.width, p.dy * _box.height)),
        isTrue,
      );
    }
  });
}
