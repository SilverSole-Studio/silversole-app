import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/home_data_providers.dart';
import 'package:silversole/shared/providers/home_tab_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/widgets/foot_health_check_card.dart'
    show lastFootCheckDate;
import 'package:silversole/shared/widgets/home_hello.dart';

/// 今天 in look C, 溫暖紙本手帳風 (subscribers) — the mock 首頁風格打樣/c.html.
///
/// A page of a planner on dot-grid paper: a sticky note for the foot check, two
/// stickers (insole, exercise), a ruled to-do page for the missions, and a
/// ticket to the town with a polaroid. Everything sits a degree or two crooked
/// on purpose; the text inside never does.
///
/// The check's verdict is a band, never a score, so the sticky note's big
/// figure is the band word, not the mock's "86 分".
class HomeBodyC extends ConsumerWidget {
  const HomeBodyC({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: CustomPaint(
            painter: _DotGridPainter(),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hello(),
                  SizedBox(height: 22),
                  _Sticky(),
                  SizedBox(height: 26),
                  _Duo(),
                  SizedBox(height: 30),
                  _TodoPage(),
                  SizedBox(height: 30),
                  _Ticket(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppPaletteC.dot;
    for (var y = 11.0; y < size.height; y += 22) {
      for (var x = 11.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 1.3, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}

/// A strip of washi tape.
class _Tape extends StatelessWidget {
  const _Tape({this.yellow = false});

  final bool yellow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(92, 26),
      painter: _TapePainter(
        yellow ? AppPaletteC.highlight : const Color(0xFF96CDE1),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawShadow(Path()..addRect(rect), Colors.black, 2, false);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.8));
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 8;
    for (var x = -size.height; x < size.width + size.height; x += 18) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.color != color;
}

// ── Greeting ──────────────────────────────────────────────────────────────

class _Hello extends ConsumerWidget {
  const _Hello();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hello = homeHello(context, ref);
    final i = hello.hello.indexOf('，');
    final greeting = i < 0 ? hello.hello : hello.hello.substring(0, i + 1);
    final name = i < 0 ? '' : hello.hello.substring(i + 1);

    return SizedBox(
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 4,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.rotate(
                  angle: -0.035,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppPaletteC.sage,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1F000000), blurRadius: 2),
                      ],
                    ),
                    child: Text(
                      hello.date,
                      style: context.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // A long name shrinks to fit rather than being cut.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting,
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 36,
                        ),
                      ),
                      _Highlight(
                        child: Text(
                          name,
                          style: context.textTheme.displaySmall?.copyWith(
                            fontSize: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: -6,
            child: Transform.rotate(
              angle: 0.12,
              child: Image.asset('assets/mascot-assets/happy.webp', width: 96),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text under a highlighter stroke.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color(0xBFFCBD3C),
            Color(0xBFFCBD3C),
            Colors.transparent,
          ],
          stops: [0, 0.62, 0.62, 0.9, 0.9],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: child,
      ),
    );
  }
}

// ── The sticky note: the foot check ───────────────────────────────────────

/// A stamp button: yellow, with a dashed inner border and a ledge under it.
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.onTap,
    this.fill = AppPaletteC.highlight,
    this.ledge = AppPaletteC.highlightShade,
    this.height = 64,
    this.fontSize = 28,
  });

  final String label;
  final VoidCallback onTap;
  final Color fill;
  final Color ledge;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const r = BorderRadius.only(
      topLeft: Radius.circular(14),
      topRight: Radius.circular(18),
      bottomRight: Radius.circular(14),
      bottomLeft: Radius.circular(20),
    );
    return Transform.rotate(
      angle: 0.014,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: r,
          boxShadow: [BoxShadow(color: ledge, offset: const Offset(0, 4))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: CustomPaint(
              painter: _DashedPainter(r),
              child: SizedBox(
                height: height,
                child: Center(
                  child: Text(
                    label,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: fontSize,
                      letterSpacing: fontSize * 0.14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius
        .resolve(ui.TextDirection.ltr)
        .toRRect((Offset.zero & size).deflate(5));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppPaletteC.ink.withValues(alpha: 0.55);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 7, m.length)), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => false;
}

class _Sticky extends ConsumerWidget {
  const _Sticky();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFootCheckProvider);
    return Transform.rotate(
      angle: -0.017,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: const BoxDecoration(
              color: AppPaletteC.butter,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(22),
                bottomLeft: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33503F14),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'foot_check_title'.tr(),
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(right: 96),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _Highlight(
                      child: Text(
                        last == null
                            ? 'foot_check_none_yet'.tr()
                            : last.rating.labelKey.tr(),
                        style: context.look
                            .number(
                              last == null ? 30 : 64,
                              color: AppPaletteC.ink,
                            )
                            .copyWith(height: 1.15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    last == null
                        ? 'foot_check_none_yet_hint'.tr()
                        : 'foot_health_check_last'.tr(
                            args: [lastFootCheckDate(context, last)],
                          ),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                _Stamp(
                  label: 'start_check'.tr(),
                  onTap: () => context.push('/foot-check'),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 150,
            top: -14,
            child: _TiltedTape(angle: 0.05),
          ),
          Positioned(
            right: 8,
            top: 44,
            child: Transform.rotate(
              angle: 0.09,
              child: Image.asset(
                'assets/mascot-assets/checking.webp',
                width: 104,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TiltedTape extends StatelessWidget {
  const _TiltedTape({required this.angle, this.yellow = false});

  final double angle;
  final bool yellow;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: _Tape(yellow: yellow),
  );
}

// ── Two stickers ──────────────────────────────────────────────────────────

class _Duo extends StatelessWidget {
  const _Duo();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 100, child: _InsoleSticker()),
          SizedBox(width: 16),
          Expanded(flex: 105, child: _ExerciseSticker()),
        ],
      ),
    );
  }
}

class _InsoleSticker extends ConsumerWidget {
  const _InsoleSticker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(soleStatusProvider);
    final level = status.battery.percent;
    return Transform.rotate(
      angle: 0.028,
      child: Material(
        color: AppPaletteC.sage,
        elevation: 4,
        shadowColor: const Color(0x2B3C321E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(22),
            bottomRight: Radius.circular(34),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: InkWell(
          onTap: () => context.push('/my-devices'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'home_insole_title'.tr(),
                        style: context.textTheme.titleLarge,
                      ),
                    ),
                    Image.asset(
                      'assets/mascot-assets/icons/dev_foot.webp',
                      width: 56,
                    ),
                  ],
                ),
                if (!status.paired)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'device_tap_to_pair'.tr(),
                      style: context.textTheme.titleLarge,
                    ),
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        level == null ? '-' : '$level',
                        style: context.look.number(50, color: AppPaletteC.ink),
                      ),
                      Text(
                        '%',
                        style: context.look.number(20, color: AppPaletteC.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.online ? 'device_synced'.tr() : 'offline'.tr(),
                    style: context.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExerciseSticker extends ConsumerWidget {
  const _ExerciseSticker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(exerciseTodayProvider);
    return Transform.rotate(
      angle: -0.024,
      child: Material(
        color: AppPaletteC.peach,
        elevation: 4,
        shadowColor: const Color(0x2B3C321E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(22),
            bottomLeft: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('today_exercise'.tr(), style: context.textTheme.titleLarge),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${today.minutes}',
                    style: context.look.number(50, color: AppPaletteC.ink),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      'exercise_goal_unit'.tr(args: ['${today.goal}']),
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPaletteC.ink, width: 2.5),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: today.fraction,
                  heightFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppPaletteC.highlight, Color(0xFFFDD47A)],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                today.reached
                    ? 'exercise_reached'.tr()
                    : 'exercise_remaining'.tr(args: ['${today.remaining}']),
                style: context.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF3D4A5C),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── The ruled to-do page ──────────────────────────────────────────────────

class _TodoPage extends ConsumerWidget {
  const _TodoPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(todayMissionLinesProvider);
    final done = lines?.where((m) => m.done).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'today_mission'.tr(),
                style: context.textTheme.displaySmall?.copyWith(fontSize: 24),
              ),
              const SizedBox(width: 10),
              Text(
                lines == null
                    ? 'missions_loading'.tr()
                    : 'missions_done_count'.tr(
                        args: ['$done', '${lines.length}'],
                      ),
                style: context.textTheme.bodyLarge?.copyWith(
                  color: AppPaletteC.muted,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => showDailyMissionsBottomSheet(context),
          child: CustomPaint(
            painter: _RuledPainter(rows: math.max(lines?.length ?? 1, 1)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(54, 8, 18, 10),
              child: Column(
                children: [
                  for (final m in lines ?? const <MissionLine>[])
                    SizedBox(
                      height: 64,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: m.done
                                  ? const Color(0xFFFFF7D6)
                                  : Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(10),
                                bottomRight: Radius.circular(7),
                                bottomLeft: Radius.circular(9),
                              ),
                              border: Border.all(
                                color: AppPaletteC.ink,
                                width: 2.5,
                              ),
                            ),
                            child: m.done
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 22,
                                    color: AppPaletteC.ink,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              m.titleKey.tr(),
                              style: context.textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                color: m.done
                                    ? const Color(0xFF55606F)
                                    : AppPaletteC.ink,
                                decoration: m.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: AppPaletteC.highlight,
                                decorationThickness: 5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A sheet of ruled paper: horizontal rules, a red margin line, punch holes.
class _RuledPainter extends CustomPainter {
  _RuledPainter({required this.rows});

  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final page = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomRight: const Radius.circular(18),
      bottomLeft: const Radius.circular(8),
    );
    canvas.drawShadow(
      Path()..addRRect(page),
      const Color(0xFF3C321E),
      6,
      false,
    );
    canvas.drawRRect(page, Paint()..color = AppPaletteC.card);
    final rule = Paint()
      ..color = AppPaletteC.rule
      ..strokeWidth = 2;
    for (var i = 1; i <= rows; i++) {
      final y = 8 + i * 64.0;
      if (y < size.height - 4) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
      }
    }
    canvas.drawLine(
      Offset(38, 0),
      Offset(38, size.height),
      Paint()
        ..color = AppPaletteC.margin
        ..strokeWidth = 2.5,
    );
    final hole = Paint()..color = AppPaletteC.paper;
    for (final f in [0.12, 0.5, 0.88]) {
      canvas.drawCircle(Offset(16, size.height * f), 6, hole);
    }
  }

  @override
  bool shouldRepaint(_RuledPainter old) => old.rows != rows;
}

// ── The ticket to the town ────────────────────────────────────────────────

class _Ticket extends ConsumerWidget {
  const _Ticket();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: AppPaletteC.lilac,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x333C323C),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // The polaroid.
          Transform.rotate(
            angle: -0.05,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 132,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x38000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 984 / 1200,
                    child: Image.asset(
                      'assets/mascot-assets/cards/card_hop.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const Positioned(
                  left: 34,
                  top: -11,
                  child: _TiltedTape(angle: 0.05, yellow: true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home_town_title'.tr(),
                  style: context.textTheme.displaySmall?.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 6),
                Text(
                  'home_town_hint'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF4A4F66),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                _Stamp(
                  label: 'home_town_go'.tr(),
                  fill: AppPaletteC.card,
                  ledge: const Color(0xFF9A97C0),
                  height: 56,
                  fontSize: 23,
                  onTap: () => ref
                      .read(homeTabProvider.notifier)
                      .select(HomeTabNotifier.games),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
