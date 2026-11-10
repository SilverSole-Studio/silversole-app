import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Pieces of look A (粗哥手繪小鎮風) that more than one page draws: the sky
/// behind a greeting, a shop awning, a status dot, a big outlined button label.

/// The town's sky: a soft blue gradient, a smiling sun with rays, two outlined
/// puffy clouds and the near hills, 390x300 scaled to the page width. Drawn in
/// the town's hand-drawn style (brown outline, warm fills). The clouds stay out
/// of the greeting's way (the date pill and the name sit at the left, below
/// y 36). The hills end in the page's own grass color so the sky melts into
/// the canvas below it.
///
/// Sun, clouds and hills are separate layers with the box shapes of the
/// illustration files that will replace them (see [TownSkyArt]): flip the
/// flag there once the PNGs are in assets.
class TownSky extends StatelessWidget {
  const TownSky({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = context.mascot.line;
    return AspectRatio(
      aspectRatio: 390 / 300,
      child: LayoutBuilder(
        builder: (context, box) {
          final k = box.maxWidth / 390;
          Widget layer(
            String asset,
            CustomPainter painter,
            double l,
            double t,
            double w,
            double h,
          ) => Positioned(
            left: l * k,
            top: t * k,
            width: w * k,
            height: h * k,
            child: TownSkyArt.useFiles
                ? Image.asset(asset, fit: BoxFit.fill)
                : CustomPaint(painter: painter),
          );
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              const Positioned.fill(child: CustomPaint(painter: _SkyPainter())),
              // Hills: 1290x500, bottom edge on the sky's bottom edge.
              layer(
                TownSkyArt.hills,
                _HillsPainter(ink),
                0,
                300 - 390 * 500 / 1290,
                390,
                390 * 500 / 1290,
              ),
              // Clouds: 600x300 boxes.
              layer(TownSkyArt.cloudA, _CloudPainter(ink), 198, 12, 100, 50),
              layer(TownSkyArt.cloudB, _CloudPainter(ink), 40, -6, 62, 31),
              // Sun: 512x512 box.
              layer(TownSkyArt.sun, _SunPainter(ink), 288, 14, 104, 104),
            ],
          );
        },
      ),
    );
  }
}

/// Where the sky illustrations live once G 社 hands them over (all
/// transparent PNGs). While [useFiles] is false the sky is drawn in code.
abstract final class TownSkyArt {
  static const bool useFiles = false;
  static const sun = 'assets/mascot-assets/sky/app_home_sun.png'; // 512x512
  static const cloudA = 'assets/mascot-assets/sky/app_home_cloud_a.png'; // 600x300
  static const cloudB = 'assets/mascot-assets/sky/app_home_cloud_b.png'; // 600x300
  static const cloudC = 'assets/mascot-assets/sky/app_home_cloud_c.png'; // 600x300
  static const hills = 'assets/mascot-assets/sky/app_home_hills.png'; // 1290x500
}

Paint _fillP(Color c) => Paint()..color = c;
Paint _lineP(Color ink, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = ink;

class _SkyPainter extends CustomPainter {
  const _SkyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8FD3EF), Color(0xFFBDE8F6), Color(0xFFDDF4F5)],
          stops: [0, 0.6, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) => false;
}

/// Hills, with the town's outline on the far ridge. Drawn in the 390x300 sky
/// space, shifted up into its own box.
class _HillsPainter extends CustomPainter {
  _HillsPainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 390);
    canvas.translate(0, -(300 - 390 * 500 / 1290));
    const w = 390.0;
    const h = 300.0;
    final far = Path()
      ..moveTo(0, 232)
      ..quadraticBezierTo(70, 196, 150, 222)
      ..quadraticBezierTo(225, 246, 300, 210)
      ..quadraticBezierTo(350, 190, 390, 226)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, _fillP(AppPaletteT2.grassLight));
    final ridge = Path()
      ..moveTo(0, 232)
      ..quadraticBezierTo(70, 196, 150, 222)
      ..quadraticBezierTo(225, 246, 300, 210)
      ..quadraticBezierTo(350, 190, 390, 226);
    canvas.drawPath(ridge, _lineP(ink, 3));
    for (final b in const [Offset(56, 214), Offset(318, 203)]) {
      canvas.drawCircle(b, 12, _fillP(const Color(0xFF7DBA55)));
      canvas.drawCircle(b, 12, _lineP(ink, 2.5));
    }
    final near = Path()
      ..moveTo(0, 252)
      ..quadraticBezierTo(90, 222, 190, 246)
      ..quadraticBezierTo(300, 262, 390, 240)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, _fillP(AppPaletteT2.canvas));
  }

  @override
  bool shouldRepaint(_HillsPainter old) => old.ink != ink;
}

/// The sun, centered in a square box: rays, a face with rosy cheeks.
class _SunPainter extends CustomPainter {
  _SunPainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 23.0;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 104);
    const c = Offset.zero;
    final ray = _fillP(AppPaletteT2.goldBright);
    final rayLine = _lineP(ink, 2.5);
    for (var i = 0; i < 12; i++) {
      final len = i.isEven ? 17.0 : 11.0;
      canvas.save();
      canvas.rotate(i * math.pi / 6);
      final path = Path()
        ..moveTo(-5, -(r + 4))
        ..lineTo(0, -(r + 4 + len))
        ..lineTo(5, -(r + 4))
        ..close();
      canvas.drawPath(path, ray);
      canvas.drawPath(path, rayLine);
      canvas.restore();
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFE680), AppPaletteT2.goldBright],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r, _lineP(ink, 3));
    final cheek = _fillP(const Color(0xFFF59A6B).withValues(alpha: 0.7));
    for (final dx in const [-13.0, 13.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dx, 5), width: 8, height: 5),
        cheek,
      );
    }
    canvas.drawCircle(const Offset(-8, -3), 2.4, _fillP(ink));
    canvas.drawCircle(const Offset(8, -3), 2.4, _fillP(ink));
    final smile = Path()
      ..moveTo(-6, 4)
      ..quadraticBezierTo(0, 11, 6, 4);
    canvas.drawPath(smile, _lineP(ink, 2.4));
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.ink != ink;
}

/// A puffy cloud: three bumps on a flat base, outlined, soft shade under it,
/// fitted into a 2:1 box.
class _CloudPainter extends CustomPainter {
  _CloudPainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    canvas.translate(6, 8);
    final body = Path()
      ..moveTo(10, 38)
      ..cubicTo(-6, 38, -6, 16, 14, 16)
      ..cubicTo(14, -2, 40, -6, 46, 10)
      ..cubicTo(58, -2, 80, 6, 72, 24)
      ..cubicTo(88, 26, 88, 38, 74, 38)
      ..close();
    canvas.drawPath(body, _fillP(Colors.white));
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      const Rect.fromLTWH(-10, 29, 110, 14),
      _fillP(const Color(0xFFD9EEF7)),
    );
    canvas.restore();
    canvas.drawPath(body, _lineP(ink, 3));
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.ink != ink;
}

/// A shop awning: alternating brick-red and paper stripes with scalloped
/// edges, drawn with the card outline. Put it at the top of a card.
class Awning extends StatelessWidget {
  const Awning({super.key, this.height = 46});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _AwningPainter(
          ink: context.mascot.line,
          red: context.mascot.danger,
          paper: context.mascot.card,
        ),
      ),
    );
  }
}

class _AwningPainter extends CustomPainter {
  _AwningPainter({required this.ink, required this.red, required this.paper});

  final Color ink;
  final Color red;
  final Color paper;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = AppPaletteT2.outlineWidth;
    final count = (size.width / 44).round().clamp(4, 12);
    final w = size.width / count;
    final flat = size.height * 0.5;
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    // The card around it clips to its rounded corners and draws the outline
    // on top, so only the dividers and scallops are drawn here.
    canvas.save();
    for (var i = 0; i < count; i++) {
      final x = i * w;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + w, 0)
        ..lineTo(x + w, flat)
        ..arcToPoint(
          Offset(x, flat),
          radius: Radius.elliptical(w / 2, size.height - flat - stroke),
          clockwise: true,
        )
        ..close();
      fill.color = i.isEven ? red : paper;
      canvas.drawPath(path, fill);
      // Divider on the stripe's left (the card's border is the outer edge)
      // and the scallop under it.
      if (i > 0) canvas.drawLine(Offset(x, 0), Offset(x, flat), line);
      final scallop = Path()
        ..moveTo(x + w, flat)
        ..arcToPoint(
          Offset(x, flat),
          radius: Radius.elliptical(w / 2, size.height - flat - stroke),
          clockwise: true,
        );
      canvas.drawPath(scallop, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AwningPainter old) =>
      old.ink != ink || old.red != red || old.paper != paper;
}

/// A small status dot with the outline: green when [on], gray otherwise.
class TownDot extends StatelessWidget {
  const TownDot({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.mascot;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c.safe : c.inkFaint,
        border: Border.all(color: c.line, width: 2.5),
      ),
    );
  }
}

/// A big number with the mascot-yellow drop shadow, for the one hero figure of
/// a card. Drawn in the look's number face.
TextStyle townHeroStyle(BuildContext context, double size) => context.look
    .number(size, color: context.mascot.ink)
    .copyWith(
      shadows: [Shadow(color: context.mascot.gold, offset: const Offset(4, 4))],
    );
