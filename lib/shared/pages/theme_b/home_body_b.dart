import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/home_data_providers.dart';
import 'package:silversole/shared/providers/home_tab_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/widgets/app_card.dart';
import 'package:silversole/shared/widgets/foot_health_check_card.dart'
    show lastFootCheckDate;
import 'package:silversole/shared/widgets/home_hello.dart';

/// 今天 in look B, 大數字健康儀表板 (subscribers) — the mock 首頁風格打樣/b.html.
///
/// Warm black. The hero is a ring of sixty ticks, one for each second of the
/// check, lit by how well the last check went; the figures that follow (minutes
/// today, battery) are big numerals in the dashboard face.
///
/// The ring's numeral is the check's level, 1 to 3: the app judges a check by
/// three bands and never gives a score, so there is no "86 分" to show.
class HomeBodyB extends ConsumerWidget {
  const HomeBodyB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hello = homeHello(context, ref);
    final status = ref.watch(soleStatusProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hello.date,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: AppPaletteB.muted,
                          ),
                        ),
                        Text(
                          hello.hello,
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontSize: 24,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SolePill(status: status),
                ],
              ),
              const SizedBox(height: 10),
              const _Ring(),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => context.push('/foot-check'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  shape: const StadiumBorder(),
                ),
                icon: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppPaletteB.onYellow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppPaletteB.yellow,
                    size: 24,
                  ),
                ),
                label: Text(
                  'start_check'.tr(),
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                    letterSpacing: 2,
                    color: AppPaletteB.onYellow,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _ExerciseTile(),
              const _SectionHead(),
              const _Tasks(),
              const SizedBox(height: 24),
              const _InsoleTile(),
              const SizedBox(height: 28),
              const _TownCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolePill extends StatelessWidget {
  const _SolePill({required this.status});

  final SoleStatus status;

  @override
  Widget build(BuildContext context) {
    final level = status.battery.percent;
    return Material(
      color: AppPaletteB.panel,
      shape: const StadiumBorder(
        side: BorderSide(color: AppPaletteB.line, width: 1.5),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.push('/my-devices'),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status.online ? AppPaletteB.mint : AppPaletteB.muted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'home_insole_title'.tr(),
                style: context.textTheme.titleMedium,
              ),
              if (level != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$level%',
                  style: context.look.number(
                    24,
                    color: status.battery.isLive
                        ? AppPaletteB.text
                        : AppPaletteB.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero ring ─────────────────────────────────────────────────────────────

class _Ring extends ConsumerWidget {
  const _Ring();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFootCheckProvider);
    final level = last?.rating.level ?? 0;
    // Sixty ticks = the minute; a third lit per level of the verdict.
    final lit = level * 20;

    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: const Size(300, 300), painter: _RingPainter(lit)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'foot_check_title'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: AppPaletteB.muted,
                  ),
                ),
                if (last == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56),
                    child: Text(
                      'foot_check_none_yet'.tr(),
                      textAlign: TextAlign.center,
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                      ),
                    ),
                  )
                else ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$level',
                        style: context.look.number(
                          150,
                          color: AppPaletteB.text,
                          height: 0.95,
                        ),
                      ),
                      Text(
                        '/${FootCheckRating.values.length}',
                        style: context.look.number(
                          36,
                          color: AppPaletteB.yellow,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    last.rating.labelKey.tr(),
                    style: context.textTheme.titleLarge?.copyWith(
                      color: AppPaletteB.yellow,
                    ),
                  ),
                  Text(
                    'foot_health_check_last'.tr(
                      args: [lastFootCheckDate(context, last)],
                    ),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppPaletteB.muted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.lit);

  final int lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * math.pi * 2 - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final on = i < lit;
      paint
        ..strokeWidth = i % 5 == 0 ? 6 : 4.5
        ..color = on
            ? AppPaletteB.yellow.withValues(
                alpha: 0.55 + 0.45 * i / math.max(lit, 1),
              )
            : AppPaletteB.line;
      canvas.drawLine(c + dir * 122, c + dir * 146, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.lit != lit;
}

// ── Tiles ─────────────────────────────────────────────────────────────────

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(exerciseTodayProvider);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'today_exercise'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: AppPaletteB.muted,
                  ),
                ),
              ),
              Text(
                today.reached
                    ? 'exercise_reached'.tr()
                    : 'exercise_remaining'.tr(args: ['${today.remaining}']),
                style: context.textTheme.titleSmall?.copyWith(
                  color: AppPaletteB.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${today.minutes}',
                style: context.look.number(96, color: AppPaletteB.mint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'exercise_goal_unit'.tr(args: ['${today.goal}']),
                    style: context.textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // One cell per minute of the goal.
          _Cells(count: today.goal, lit: today.minutes, height: 22),
        ],
      ),
    );
  }
}

/// A row of cells, [lit] of them filled mint.
class _Cells extends StatelessWidget {
  const _Cells({required this.count, required this.lit, required this.height});

  final int count;
  final int lit;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        spacing: 4,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < lit ? AppPaletteB.mint : AppPaletteB.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHead extends ConsumerWidget {
  const _SectionHead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(todayMissionLinesProvider);
    final done = lines?.where((m) => m.done).length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 30, 4, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              'today_mission'.tr(),
              style: context.textTheme.headlineMedium?.copyWith(fontSize: 22),
            ),
          ),
          if (lines != null) ...[
            Text(
              '$done',
              style: context.look.number(30, color: AppPaletteB.yellow),
            ),
            Text(
              '／${lines.length}',
              style: context.textTheme.titleMedium?.copyWith(
                color: AppPaletteB.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tasks extends ConsumerWidget {
  const _Tasks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(todayMissionLinesProvider);
    if (lines == null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'missions_loading'.tr(),
          style: context.textTheme.bodyLarge?.copyWith(
            color: AppPaletteB.muted,
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => showDailyMissionsBottomSheet(context),
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++)
            Container(
              constraints: const BoxConstraints(minHeight: 62),
              decoration: BoxDecoration(
                border: i == lines.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppPaletteB.line, width: 1.5),
                      ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: lines[i].done ? AppPaletteB.yellow : null,
                      border: Border.all(
                        color: lines[i].done
                            ? AppPaletteB.yellow
                            : const Color(0xFF5B4E35),
                        width: 3,
                      ),
                    ),
                    child: lines[i].done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: AppPaletteB.onYellow,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      lines[i].titleKey.tr(),
                      style: context.textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        color: lines[i].done
                            ? AppPaletteB.muted
                            : AppPaletteB.text,
                        decoration: lines[i].done
                            ? TextDecoration.lineThrough
                            : null,
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
    );
  }
}

class _InsoleTile extends ConsumerWidget {
  const _InsoleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(soleStatusProvider);
    final level = status.battery.percent;
    return AppCard(
      onTap: () => context.push('/my-devices'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'home_insole_title'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              color: AppPaletteB.muted,
            ),
          ),
          const SizedBox(height: 4),
          if (!status.paired)
            Text(
              'device_tap_to_pair'.tr(),
              style: context.textTheme.headlineMedium,
            )
          else ...[
            Row(
              children: [
                Text(
                  level == null ? '-' : '$level',
                  style: context.look.number(64, color: AppPaletteB.text),
                ),
                Text(
                  '%',
                  style: context.look.number(24, color: AppPaletteB.muted),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _Cells(
                    count: 10,
                    lit: ((status.battery.fraction) * 10).round(),
                    height: 34,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status.online ? AppPaletteB.mint : AppPaletteB.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status.online ? 'device_synced'.tr() : 'offline'.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: AppPaletteB.muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TownCard extends ConsumerWidget {
  const _TownCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF34290F), Color(0xFF4A3512)],
            ),
            border: Border.all(color: const Color(0xFF5B4720), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'home_town_title'.tr(),
                style: context.textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 120),
                child: Text(
                  'home_town_hint'.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFDCCB9A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 150,
                child: FilledButton(
                  onPressed: () => ref
                      .read(homeTabProvider.notifier)
                      .select(HomeTabNotifier.games),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'home_town_go'.tr(),
                    style: context.textTheme.titleLarge?.copyWith(
                      color: AppPaletteB.onYellow,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          top: -26,
          child: Transform.rotate(
            angle: 0.07,
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppPaletteB.text, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/mascot-assets/cards/card_hop.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
