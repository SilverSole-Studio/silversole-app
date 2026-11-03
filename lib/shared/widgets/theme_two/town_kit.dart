import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Pieces of look A (粗哥手繪小鎮風) that more than one page draws: the sky
/// behind a greeting, a shop awning, a status dot, a big outlined button label.

/// The town's sky: blue, a sun, two clouds and the near hills, 390x300 scaled to
/// the page width. The hills end in the page's own grass color so the sky melts
/// into the canvas below it.
class TownSky extends StatelessWidget {
  const TownSky({super.key});

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 390 300" preserveAspectRatio="xMidYMin slice">
<rect width="390" height="300" fill="#a9ddf2"/>
<g stroke="#3b3325" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">
<circle cx="352" cy="62" r="24" fill="#ffd23f"/>
<path d="M24 118c-14 0-20-18-4-24 3-14 24-16 30-4 16-4 24 14 12 26z" fill="#fff" transform="translate(20 -30)"/>
<path d="M190 74c-12 0-17-15-3-20 3-12 20-13 25-3 13-3 20 12 10 22z" fill="#fff" transform="translate(-60 -36)"/>
</g>
<path d="M0 232 Q70 196 150 222 T300 210 T390 226 V300 H0Z" fill="#b6dc8b"/>
<path d="M0 252 Q90 222 190 246 T390 240 V300 H0Z" fill="#9ccc6b"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 390 / 300,
      child: SvgPicture.string(_svg, fit: BoxFit.cover),
    );
  }
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
    final top = stroke;
    final flat = size.height * 0.5;
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    for (var i = 0; i < count; i++) {
      final x = i * w;
      final path = Path()
        ..moveTo(x, top)
        ..lineTo(x + w, top)
        ..lineTo(x + w, flat)
        ..arcToPoint(
          Offset(x, flat),
          radius: Radius.elliptical(w / 2, size.height - flat - stroke),
          clockwise: true,
        )
        ..close();
      fill.color = i.isEven ? red : paper;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, line);
    }
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
TextStyle townHeroStyle(BuildContext context, double size) =>
    context.look
        .number(size, color: context.mascot.ink)
        .copyWith(
          shadows: [
            Shadow(color: context.mascot.gold, offset: const Offset(4, 4)),
          ],
        );
