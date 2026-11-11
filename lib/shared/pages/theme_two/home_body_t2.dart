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
import 'package:silversole/shared/widgets/app_card.dart';
import 'package:silversole/shared/widgets/home_hello.dart' show greetingName;
import 'package:silversole/shared/widgets/foot_health_check_card.dart'
    show lastFootCheckDate;
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';
import 'package:silversole/shared/widgets/theme_two/town_kit.dart';
import 'package:silversole/shared/widgets/town_icon.dart';

/// 今天 in look A, 粗哥手繪小鎮風 — the design mock 首頁風格打樣/a.html.
///
/// The town: sky and grass, the foot check as a shop with an awning (the one big
/// thing to do), two small stalls (the insole, today's exercise), a notice board
/// with today's missions, and the gate to the games. Every figure is a real one
/// from the phone or the sole — the mock's "86 分" has no source (a check ends on
/// a band, never a score), so the band is what gets the big type.
///
/// Fall detection is not here: it lives on the map tab. The raw IMU trace is not
/// here either: it stays one tap away on the analytics detail page.
class HomeBodyT2 extends ConsumerWidget {
  const HomeBodyT2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final phase = skyPhaseFor(DateTime.now());
    return Scaffold(
      // The grass gradient's far color, so nothing shows below the page.
      backgroundColor: const Color(0xFF8CC25C),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            const Positioned.fill(child: TownGrass()),
            Positioned(top: 0, left: 0, right: 0, child: TownSky(phase: phase)),
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Greeting(night: phase == SkyPhase.night),
                  SizedBox(height: 14),
                  FootCheckCardT2(),
                  SizedBox(height: 20),
                  _Stalls(),
                  SizedBox(height: 28),
                  _SectionTitle(icon: 'target', textKey: 'today_mission'),
                  SizedBox(height: 12),
                  _MissionBoard(),
                  SizedBox(height: 28),
                  _SectionTitle(icon: 'flag', textKey: 'home_town_title'),
                  SizedBox(height: 12),
                  _TownGate(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Greeting ──────────────────────────────────────────────────────────────

class _Greeting extends ConsumerWidget {
  const _Greeting({this.night = false});

  /// Night sky is dark: the greeting turns light so it stays readable.
  final bool night;

  /// Time-of-day greeting — derived from the clock, so it is real data.
  String _greetingKey(int hour) {
    if (hour < 12) return 'greeting_morning';
    if (hour < 18) return 'greeting_afternoon';
    return 'greeting_evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final locale = context.locale.toString();
    // The friends nickname when there is one; otherwise the account only gives
    // us an email, so use its local part.
    final name = greetingName(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MascotPill(
          child: Text(
            '${DateFormat.MMMd(locale).format(now)}　'
            '${DateFormat.E(locale).format(now)}',
            style: context.textTheme.titleSmall?.copyWith(height: 1.1),
          ),
        ),
        const SizedBox(height: 8),
        // Leave the sun its corner.
        Padding(
          padding: const EdgeInsets.only(right: 64),
          child: Text(
            '${_greetingKey(now.hour).tr()}，$name',
            style: context.textTheme.headlineLarge?.copyWith(
              fontSize: 34,
              color: night ? const Color(0xFFFFF6DC) : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── The shop: the foot check ──────────────────────────────────────────────

/// The last foot check the wearer finished: its band and when. With none on
/// record it says so — no number — and the button starts one.
class FootCheckCardT2 extends ConsumerWidget {
  const FootCheckCardT2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFootCheckProvider);
    final c = context.mascot;

    return AppCard(
      weight: CardWeight.hero,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Awning(),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.ink,
                              borderRadius: AppRadius.pillR,
                            ),
                            child: Text(
                              'foot_check_station'.tr(),
                              style: context.textTheme.labelMedium?.copyWith(
                                color: c.card,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'foot_check_title'.tr(),
                            style: context.textTheme.headlineMedium?.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // The one hero figure: the band, in big type.
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                last == null
                                    ? 'foot_check_none_yet'.tr()
                                    : last.rating.labelKey.tr(),
                                maxLines: 1,
                                softWrap: false,
                                // The yellow drop shadow is for the short
                                // verdict only; the empty-state sentence is
                                // plain ink so it doesn't read as a doubled,
                                // blurry line.
                                style: last == null
                                    ? context.look
                                          .number(26, color: context.mascot.ink)
                                          .copyWith(height: 1.1)
                                    : townHeroStyle(
                                        context,
                                        60,
                                      ).copyWith(height: 1.1),
                              ),
                            ),
                          ),
                          if (last != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (var i = 1; i <= 3; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: TownIcon(
                                      i <= last.rating.level ? 'star' : 'starO',
                                      size: 30,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // The mascot invites a check (or reads the result).
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 14),
                      child: Transform.rotate(
                        angle: 0.05,
                        child: Image.asset(
                          'assets/mascot-assets/checking.webp',
                          height: 132,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  last == null
                      ? 'foot_check_none_yet_hint'.tr()
                      : 'foot_health_check_last'.tr(
                          args: [lastFootCheckDate(context, last)],
                        ),
                  style: context.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.push('/foot-check'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const TownIcon('go', size: 32),
                        const SizedBox(width: 10),
                        Text(
                          'start_check'.tr(),
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontSize: 26,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
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

// ── Two stalls: the insole, today's exercise ──────────────────────────────

/// Header row of the two small cards: same height so the figures line up.
const double _stallHeader = 48;

/// The small status line under a stall's bar: big enough to read at arm's
/// length, in the card's secondary ink.
TextStyle _stallNote(BuildContext context) =>
    context.textTheme.bodyMedium!.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: context.mascot.inkMuted,
    );

class _Stalls extends StatelessWidget {
  const _Stalls();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 100, child: _InsoleStall()),
          SizedBox(width: 14),
          Expanded(flex: 108, child: _ExerciseStall()),
        ],
      ),
    );
  }
}

class _InsoleStall extends ConsumerWidget {
  const _InsoleStall();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(soleStatusProvider);
    final c = context.mascot;
    final hasLevel = status.battery.percent != null;

    return AppCard(
      onTap: () => context.push('/my-devices'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _stallHeader,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'home_insole_title'.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                ),
                Image.asset(
                  'assets/mascot-assets/icons/dev_foot.webp',
                  width: 48,
                ),
              ],
            ),
          ),
          if (!status.paired)
            Text('device_tap_to_pair'.tr(), style: context.textTheme.titleLarge)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  hasLevel ? '${status.battery.percent}' : '-',
                  style: context.look.number(46, color: c.ink),
                ),
                Text('%', style: context.look.number(20, color: c.ink)),
              ],
            ),
            const SizedBox(height: 8),
            MascotProgressBar(
              value: status.battery.fraction,
              height: 20,
              fill: status.battery.isLive ? c.safe : c.inkFaint,
            ),
          ],
          const Spacer(),
          const SizedBox(height: 8),
          if (status.paired)
            Row(
              children: [
                TownDot(on: status.online),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      status.online ? 'device_synced'.tr() : 'offline'.tr(),
                      style: _stallNote(context),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExerciseStall extends ConsumerWidget {
  const _ExerciseStall();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(exerciseTodayProvider);
    final c = context.mascot;

    return AppCard(
      tint: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _stallHeader,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'today_exercise'.tr(),
                style: context.textTheme.titleMedium,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${today.minutes}',
                style: context.look.number(46, color: c.ink),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  'exercise_goal_unit'.tr(args: ['${today.goal}']),
                  style: context.look.number(20, color: c.ink),
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MascotProgressBar(value: today.fraction, height: 20, fill: c.gold),
          const Spacer(),
          const SizedBox(height: 8),
          Text(
            today.reached
                ? 'exercise_reached'.tr()
                : 'exercise_remaining'.tr(args: ['${today.remaining}']),
            style: _stallNote(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Notice board: today's missions ────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.textKey});

  final String icon;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          TownIcon(icon, size: 28),
          const SizedBox(width: 8),
          Text(
            textKey.tr(),
            style: context.textTheme.headlineMedium?.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _MissionBoard extends ConsumerWidget {
  const _MissionBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(todayMissionLinesProvider);
    final c = context.mascot;
    final done = lines?.where((m) => m.done).length ?? 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showDailyMissionsBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 26, 14, 8),
        decoration: BoxDecoration(
          color: c.wood,
          borderRadius: BorderRadius.circular(AppPaletteT2.cardRadius),
          border: Border.all(color: c.line, width: AppPaletteT2.outlineWidth),
          boxShadow: [
            BoxShadow(
              color: c.line,
              offset: const Offset(0, AppPaletteT2.shadowDrop - 1),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The two pins.
            Positioned(top: -18, left: -2, child: _Pin(color: c.card)),
            Positioned(top: -18, right: -2, child: _Pin(color: c.card)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    lines == null
                        ? 'missions_loading'.tr()
                        : 'missions_done_count'.tr(
                            args: ['$done', '${lines.length}'],
                          ),
                    style: context.textTheme.titleMedium,
                  ),
                ),
                for (var i = 0; i < (lines?.length ?? 0); i++)
                  _Note(line: lines![i]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: context.mascot.line, width: 2.5),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.line});

  final MissionLine line;

  @override
  Widget build(BuildContext context) {
    final c = context.mascot;
    final done = line.done;
    // A finished note turns green and dims, with a ticked box: readable
    // at a glance, the way a quest list does it.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: done ? c.safeSoft : c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line, width: AppPaletteT2.outlineWidth),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done ? c.safe : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line, width: 3),
            ),
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: done ? 0.6 : 1,
              child: Text(
                line.titleKey.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationThickness: 1.5,
                  color: c.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── The gate to the games ─────────────────────────────────────────────────

class _TownGate extends ConsumerWidget {
  const _TownGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mascot;
    return AppCard(
      color: c.gold,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // An arched doorway with a picture of the town in it.
          Container(
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(60),
                topRight: Radius.circular(60),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              border: Border.all(color: c.line, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 984 / 1200,
              child: Image.asset(
                'assets/mascot-assets/cards/card_hop.webp',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home_town_headline'.tr(),
                  style: context.textTheme.displaySmall?.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 6),
                Text(
                  'home_town_hint'.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(homeTabProvider.notifier)
                        .select(HomeTabNotifier.games),
                    child: Text(
                      'home_town_go'.tr(),
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                      ),
                    ),
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
