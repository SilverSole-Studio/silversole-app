import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Home screen for the illustrated "mascot" theme.
///
/// Deliberately a separate implementation from [HomeBody] rather than a
/// restyle: the two designs group their content differently. Both read the
/// same providers, so there is one source of truth for the data.
///
/// Only blocks backed by real data are rendered. Figures the app does not
/// measure yet (step count, streak, health score) show 0 rather than a
/// plausible-looking number, and the mockup's weather strip is omitted
/// entirely — there is no weather source and none is planned.
class HomeBodyT2 extends ConsumerWidget {
  const HomeBodyT2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(settingsProvider).preferredDevice;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              const _GreetingHeader(),
              const _DailyMissionCard(),
              _DeviceCard(device: device),
              const _FootCheckCard(),
              const _FallGuardCard(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 1. Greeting ───────────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  /// Time-of-day greeting — derived from the clock, so it is real data.
  String _greetingKey(int hour) {
    if (hour < 12) return 'greeting_morning';
    if (hour < 18) return 'greeting_afternoon';
    return 'greeting_evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    final now = DateTime.now();
    // The account only gives us an email; use its local part as a display
    // name until a real profile name exists.
    final name = user?.email.split('@').first ?? 'silversole'.tr();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMMd（E）', context.locale.toString()).format(now),
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${_greetingKey(now.hour).tr()}，$name',
                style: context.textTheme.headlineLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Image.asset(
          'assets/mascot-assets/hero.png',
          height: 84,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

// ── 2. Daily mission ──────────────────────────────────────────────────────

class _DailyMissionCard extends StatelessWidget {
  const _DailyMissionCard();

  // TODO: no pedometer and no streak history yet — show 0 until they exist.
  static const int _steps = 0;
  static const int _stepGoal = 3500;
  static const int _streakDays = 0;

  @override
  Widget build(BuildContext context) {
    final progress = _stepGoal == 0
        ? 0.0
        : (_steps / _stepGoal).clamp(0.0, 1.0);

    return MascotCard(
      color: AppPaletteT2.cardWarm,
      onTap: () => showDailyMissionsBottomSheet(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/mascot-assets/icons/home_play.png', height: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'today_mission'.tr(),
                        style: context.textTheme.titleLarge,
                      ),
                    ),
                    MascotPill(
                      child: Text(
                        'streak_days'.tr(args: ['$_streakDays']),
                        style: context.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 14,
                          backgroundColor: AppPaletteT2.card,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppPaletteT2.safe,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'steps_progress'.tr(args: ['$_steps', '$_stepGoal']),
                      style: context.textTheme.labelLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3. Device ─────────────────────────────────────────────────────────────

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.device});

  final BlePairedDevice? device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(deviceOnlineProvider);
    final recent = ref.watch(telemetryViewProvider).recentImu;
    final battery = recent.isEmpty ? 0 : recent.last.batteryPercent;

    return MascotCard(
      color: AppPaletteT2.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  device?.name ?? 'not_binding'.tr(),
                  style: context.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online ? AppPaletteT2.safe : AppPaletteT2.inkMuted,
                  border: Border.all(color: AppPaletteT2.ink, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            online ? 'online'.tr() : 'offline'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppPaletteT2.ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (battery / 100).clamp(0.0, 1.0),
                    minHeight: 18,
                    backgroundColor: AppPaletteT2.card,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppPaletteT2.safe,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$battery%', style: context.textTheme.headlineMedium),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 4. Foot pressure check ────────────────────────────────────────────────

class _FootCheckCard extends StatelessWidget {
  const _FootCheckCard();

  // TODO: the check itself is not implemented; 0 until it produces a score.
  static const int _score = 0;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('foot_check_title'.tr(), style: context.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$_score',
                      style: context.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppPaletteT2.ink,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('score_unit'.tr(), style: context.textTheme.bodyLarge),
                  ],
                ),
              ),
              Image.asset('assets/mascot-assets/checking.png', height: 74),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: comingSoon,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('start_check_now'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. Fall guard ─────────────────────────────────────────────────────────

/// Mirrors `WarningCard`'s counting model: falls seen since the app started.
/// There is no persisted history, so this deliberately does not claim a
/// 7-day window.
class _FallGuardCard extends ConsumerStatefulWidget {
  const _FallGuardCard();

  @override
  ConsumerState<_FallGuardCard> createState() => _FallGuardCardState();
}

class _FallGuardCardState extends ConsumerState<_FallGuardCard> {
  int _eventCount = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen(fallEventStreamProvider, (_, next) {
      next.whenData((_) => setState(() => _eventCount++));
    });

    final safe = _eventCount == 0;

    return MascotCard(
      child: Row(
        children: [
          Image.asset('assets/mascot-assets/icons/home_shield.png', height: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'fall_guard_active'.tr(),
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'fall_guard_events'.tr(args: ['$_eventCount']),
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          MascotPill(
            color: safe ? AppPaletteT2.card : AppPaletteT2.danger,
            child: Text(
              safe ? 'safe'.tr() : 'alert_severity'.tr(),
              style: context.textTheme.labelLarge?.copyWith(
                color: safe ? AppPaletteT2.safe : AppPaletteT2.card,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
