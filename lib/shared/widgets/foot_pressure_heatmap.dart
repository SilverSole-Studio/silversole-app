import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette.dart';

/// Renders a pair of feet as interpolated plantar-pressure heat maps, in the
/// visual language of a clinical pressure plate.
///
/// The sole only ever reports a right foot, so [leftPressure] is null in
/// practice; a left foot without data is drawn as a bare mirrored outline. The
/// left foot is the right one flipped horizontally — same silhouette, same
/// sensor anchors, mirrored by the canvas.
///
/// We only have 3 sensors, so the smooth field is *inferred* by splatting a
/// Gaussian blob per sensor (additive) and mapping the resulting scalar field
/// through a classic "jet" colormap. The field is computed at low resolution
/// and bilinearly upscaled by the GPU — that upscale is what produces the soft,
/// continuous gradient.
///
/// Sensor order in [pressure] (right foot, sole facing viewer, toes up):
///   index 0 -> 大拇趾球 (hallux / big-toe ball)  — medial, top
///   index 1 -> 小拇趾   (little toe)             — lateral, top
///   index 2 -> 腳跟     (heel)                   — bottom
/// Which foot (or feet) a [FootPressureHeatmap] renders.
enum FootView {
  left('left_foot'),
  right('right_foot'),
  both('both_feet');

  const FootView(this.labelKey);

  /// Key in `strings.csv`.
  final String labelKey;

  bool get showsLeft => this != FootView.right;
  bool get showsRight => this != FootView.left;
}

class FootPressureHeatmap extends StatefulWidget {
  const FootPressureHeatmap({
    super.key,
    required this.pressure,
    this.leftPressure,
    this.feet = FootView.both,
    this.maxPressure = 4096,
  });

  /// Latest right-foot readings. Missing entries are treated as 0.
  final List<int> pressure;

  /// Latest left-foot readings, or null when there is no left-foot source at
  /// all — which is every real and sample recording today.
  final List<int>? leftPressure;

  /// Whether to draw one foot on its own or the pair.
  final FootView feet;

  /// Reading mapped to the top of the color scale (full red).
  final double maxPressure;

  @override
  State<FootPressureHeatmap> createState() => _FootPressureHeatmapState();
}

// ---------------------------------------------------------------------------
// Foot mask geometry.
//
// Copied from the insole silhouette drawn in analytics_page.dart
// (_FootPressurePainter._drawInsole) so both screens use the exact same foot
// shape. It is authored in that painter's native, origin-centered coordinate
// space (x→right, y→down, toes at the top / negative y) and carries the same
// slight tilt.
// ---------------------------------------------------------------------------

const double _insoleRotation = -math.pi / 28;

Path _rawInsolePath() => Path()
  ..moveTo(-8, -78)
  ..cubicTo(-38, -72, -44, -42, -34, -8)
  ..cubicTo(-25, 22, -29, 61, -2, 78)
  ..cubicTo(20, 92, 42, 70, 37, 38)
  ..cubicTo(33, 13, 18, -7, 29, -36)
  ..cubicTo(39, -64, 18, -83, -8, -78)
  ..close();

/// Column-major 4x4 storage for [Path.transform] rotating by [a] about origin.
Float64List _rotationStorage(double a) {
  final c = math.cos(a);
  final s = math.sin(a);
  return Float64List.fromList([
    c,
    s,
    0,
    0,
    -s,
    c,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);
}

/// Column-major 4x4 storage mapping (x, y) → (sx·x + tx, sy·y + ty).
Float64List _scaleTranslateStorage(double sx, double sy, double tx, double ty) {
  return Float64List.fromList([
    sx,
    0,
    0,
    0,
    0,
    sy,
    0,
    0,
    0,
    0,
    1,
    0,
    tx,
    ty,
    0,
    1,
  ]);
}

/// Mirrors x about the origin — the raw silhouette is drawn as a *left* foot
/// (its arch bows in on the +x side), so everything gets flipped to make the
/// right foot this widget documents.
final Float64List _mirrorX = _scaleTranslateStorage(-1, 1, 0, 0);

/// The insole, pre-rotated to match the analytics tilt and mirrored to a right
/// foot, so the arch falls on the medial (image-left) side.
final Path _insolePath = _rawInsolePath()
    .transform(_rotationStorage(_insoleRotation))
    .transform(_mirrorX);

/// Bounding box of the rotated insole, in native coordinates.
final Rect _insoleBounds = _insolePath.getBounds();

/// Fraction of the widget the foot fills (leaves a small margin).
const double _fitPad = 0.94;

Offset _rotateOrigin(Offset p, double a) {
  final c = math.cos(a);
  final s = math.sin(a);
  return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
}

/// Maps a point given in *raw* (un-rotated) insole space to a [0,1] position
/// inside the widget box, using the exact same fit as [footPath].
Offset _normFromNative(Offset rawPoint) {
  final rotated = _rotateOrigin(rawPoint, _insoleRotation);
  final p = Offset(-rotated.dx, rotated.dy);
  return Offset(
    0.5 + _fitPad * (p.dx - _insoleBounds.center.dx) / _insoleBounds.width,
    0.5 + _fitPad * (p.dy - _insoleBounds.center.dy) / _insoleBounds.height,
  );
}

/// Sensor anchor points, in raw insole coordinates — i.e. before the mirror in
/// [_normFromNative], so +x here ends up on the image *left*. Tweak these if
/// the markers don't sit where the physical FSRs are.
///   index 0 -> 大拇趾球 (big-toe ball) — forefoot, medial (image-left)
///   index 1 -> 小拇趾   (little toe)    — forefoot, lateral (image-right)
///   index 2 -> 腳跟     (heel)          — rear, centred
const List<Offset> _sensorNative = [
  Offset(18, -56),
  Offset(-18, -56),
  Offset(8, 60),
];

/// Sensor positions normalized to the widget box (x→right, y→down), derived
/// from [_sensorNative] so they stay aligned with the mask.
final List<Offset> kSensorPositions = _sensorNative
    .map(_normFromNative)
    .toList(growable: false);

const List<String> kSensorLabels = ['大拇趾球', '小拇趾', '腳跟'];

/// Gap between the two feet, as a fraction of one foot's width.
const double _footGap = 0.12;

// Coarse heat-field resolution. Width tracks the insole aspect ratio so the
// Gaussian blobs stay circular once the field is stretched to fill the box.
const int _gridH = 150;
final int _gridW = (_gridH * (_insoleBounds.width / _insoleBounds.height))
    .round();

class _FootPressureHeatmapState extends State<FootPressureHeatmap> {
  ui.Image? _right;
  ui.Image? _left;

  /// Bumped per rebuild so a slow decode cannot overwrite a newer frame —
  /// sample playback swaps readings 25 times a second.
  int _rightToken = 0;
  int _leftToken = 0;

  @override
  void initState() {
    super.initState();
    _rebuildRight();
    _rebuildLeft();
  }

  @override
  void didUpdateWidget(FootPressureHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scaleChanged = oldWidget.maxPressure != widget.maxPressure;
    if (scaleChanged || !_listEquals(oldWidget.pressure, widget.pressure)) {
      _rebuildRight();
    }
    if (scaleChanged ||
        !_listEquals(oldWidget.leftPressure, widget.leftPressure)) {
      _rebuildLeft();
    }
  }

  @override
  void dispose() {
    _right?.dispose();
    _left?.dispose();
    super.dispose();
  }

  Future<void> _rebuildRight() async {
    final token = ++_rightToken;
    final image = await _fieldImage(widget.pressure, widget.maxPressure);
    if (!mounted || token != _rightToken) {
      image.dispose();
      return;
    }
    setState(() {
      _right?.dispose();
      _right = image;
    });
  }

  Future<void> _rebuildLeft() async {
    final token = ++_leftToken;
    final reading = widget.leftPressure;
    if (reading == null) {
      if (_left == null) return;
      setState(() {
        _left?.dispose();
        _left = null;
      });
      return;
    }
    final image = await _fieldImage(reading, widget.maxPressure);
    if (!mounted || token != _leftToken) {
      image.dispose();
      return;
    }
    setState(() {
      _left?.dispose();
      _left = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final feetWide = widget.feet == FootView.both ? 2 + _footGap : 1.0;
    return AspectRatio(
      aspectRatio: feetWide * _gridW / _gridH,
      child: CustomPaint(
        painter: _FeetPainter(
          feet: widget.feet,
          rightImage: _right,
          leftImage: _left,
          rightPressure: widget.pressure,
          leftPressure: widget.leftPressure,
          outlineColor: scheme.outline.withValues(alpha: 0.6),
          emptyFill: scheme.surfaceContainerHighest,
        ),
        size: Size.infinite,
      ),
    );
  }

  static bool _listEquals(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Splats one Gaussian blob per sensor (additive) and maps the resulting scalar
/// field through a "jet" colormap. The field is computed at low resolution and
/// bilinearly upscaled by the GPU — that upscale is what produces the soft,
/// continuous gradient.
Uint8List _fieldPixels(List<int> pressure, double maxPressure) {
  final bytes = Uint8List(_gridW * _gridH * 4);

  final pts = <Offset>[];
  final vals = <double>[];
  for (var i = 0; i < kSensorPositions.length; i++) {
    final raw = i < pressure.length ? pressure[i].toDouble() : 0.0;
    pts.add(
      Offset(kSensorPositions[i].dx * _gridW, kSensorPositions[i].dy * _gridH),
    );
    vals.add((raw / maxPressure).clamp(0.0, 1.0));
  }

  // Blob spread in grid pixels. Larger = softer / more overlap.
  final sigma = _gridW * 0.34;
  final twoSigmaSq = 2 * sigma * sigma;

  for (var y = 0; y < _gridH; y++) {
    for (var x = 0; x < _gridW; x++) {
      var acc = 0.0;
      for (var i = 0; i < pts.length; i++) {
        final dx = x - pts[i].dx;
        final dy = y - pts[i].dy;
        acc += vals[i] * math.exp(-(dx * dx + dy * dy) / twoSigmaSq);
      }
      final (r, g, b) = _jet(acc.clamp(0.0, 1.0));
      final o = (y * _gridW + x) * 4;
      bytes[o] = r;
      bytes[o + 1] = g;
      bytes[o + 2] = b;
      bytes[o + 3] = 255;
    }
  }
  return bytes;
}

Future<ui.Image> _fieldImage(List<int> pressure, double maxPressure) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    _fieldPixels(pressure, maxPressure),
    _gridW,
    _gridH,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// Classic MATLAB "jet" colormap: dark-blue → cyan → green → yellow → red.
(int, int, int) _jet(double t) {
  t = t.clamp(0.0, 1.0);
  double channel(double center) =>
      (1.5 - (4 * t - center).abs()).clamp(0.0, 1.0);
  final r = channel(3);
  final g = channel(2);
  final b = channel(1);
  return ((r * 255).round(), (g * 255).round(), (b * 255).round());
}

/// The shared insole silhouette (same shape as analytics_page.dart), fit with
/// a small margin into [size]. The bounding box maps to the widget box, which
/// is sized at the insole's aspect ratio so the shape is not distorted.
Path footPath(Size size) {
  final b = _insoleBounds;
  final sx = _fitPad * size.width / b.width;
  final sy = _fitPad * size.height / b.height;
  return _insolePath.transform(
    _scaleTranslateStorage(
      sx,
      sy,
      size.width / 2 - sx * b.center.dx,
      size.height / 2 - sy * b.center.dy,
    ),
  );
}

/// Paints the pair: the left foot is the same silhouette drawn through a
/// horizontal flip, the right foot as authored.
class _FeetPainter extends CustomPainter {
  _FeetPainter({
    required this.feet,
    required this.rightImage,
    required this.leftImage,
    required this.rightPressure,
    required this.leftPressure,
    required this.outlineColor,
    required this.emptyFill,
  });

  final FootView feet;
  final ui.Image? rightImage;
  final ui.Image? leftImage;
  final List<int> rightPressure;
  final List<int>? leftPressure;
  final Color outlineColor;

  /// Fill for a foot with no data source at all.
  final Color emptyFill;

  @override
  void paint(Canvas canvas, Size size) {
    final pair = feet == FootView.both;
    final footWidth = pair ? size.width / (2 + _footGap) : size.width;
    final footSize = Size(footWidth, size.height);

    if (feet.showsLeft) {
      canvas.save();
      // Map x -> footWidth - x, so the foot drawn in [0, footWidth] lands in
      // the same slot mirrored.
      canvas.translate(footWidth, 0);
      canvas.scale(-1, 1);
      _paintFoot(canvas, footSize, leftImage, leftPressure);
      canvas.restore();
    }

    if (feet.showsRight) {
      canvas.save();
      canvas.translate(pair ? footWidth * (1 + _footGap) : 0.0, 0);
      _paintFoot(canvas, footSize, rightImage, rightPressure);
      canvas.restore();
    }
  }

  void _paintFoot(
    Canvas canvas,
    Size size,
    ui.Image? image,
    List<int>? pressure,
  ) {
    final foot = footPath(size);

    canvas.save();
    canvas.clipPath(foot);
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      // No data at all reads as neutral; a foot still decoding its field gets
      // the low end of the scale so the shape is visible either way.
      canvas.drawColor(
        pressure == null ? emptyFill : AppPalette.pressureJet.first,
        BlendMode.srcOver,
      );
    }
    canvas.restore();

    canvas.drawPath(
      foot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = outlineColor,
    );

    // Sensor markers only where there are sensors reporting.
    if (pressure == null) return;
    for (final pos in kSensorPositions) {
      final p = Offset(pos.dx * size.width, pos.dy * size.height);
      canvas.drawCircle(
        p,
        4.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.black.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FeetPainter oldDelegate) =>
      oldDelegate.feet != feet ||
      !identical(oldDelegate.rightImage, rightImage) ||
      !identical(oldDelegate.leftImage, leftImage) ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.emptyFill != emptyFill ||
      !_FootPressureHeatmapState._listEquals(
        oldDelegate.rightPressure,
        rightPressure,
      ) ||
      !_FootPressureHeatmapState._listEquals(
        oldDelegate.leftPressure,
        leftPressure,
      );
}
