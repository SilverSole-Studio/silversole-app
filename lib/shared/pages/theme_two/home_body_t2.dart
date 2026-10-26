import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/pages/daily_missions_bottom_modal.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/fall_event_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';
import 'package:silversole/core/theme/app_palette.dart';
import 'package:silversole/shared/widgets/chart/chart_section.dart';
import 'package:silversole/shared/widgets/chart/imu_chart_section.dart';
import 'package:silversole/shared/widgets/foot_health_check_card.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Home screen for the illustrated "mascot" theme.
///
/// Deliberately a separate implementation from [HomeBody] rather than a
/// restyle: the two designs group their content differently. Both read the
/// same providers, so there is one source of truth for the data.
///
/// Every figure shown is real or absent: the mockup's step count, streak and
/// family contacts have no source in the app, so they are not drawn, and the
/// foot check shows the last real result or an empty state. The mockup's
/// weather strip is intentionally absent too — there is no weather source and
/// none is planned.
class HomeBodyT2 extends ConsumerWidget {
  const HomeBodyT2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(settingsProvider).preferredDevice;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              const _GreetingHeader(),
              const _DailyMissionCard(),
              _DeviceCard(device: device),
              const FootCheckCardT2(),
              const _FallGuardCard(),
              const _RecentDataCard(),
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
    final locale = context.locale.toString();
    // The account only gives us an email; use its local part as a display
    // name until a real profile name exists.
    final name = user?.email.split('@').first ?? 'silversole'.tr();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${DateFormat.MMMd(locale).format(now)} · '
                '${DateFormat.E(locale).format(now)}',
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${_greetingKey(now.hour).tr()}，$name',
                style: context.textTheme.headlineLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Image.asset(
          'assets/mascot-assets/applaud.webp',
          height: 88,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

// ── 2. Daily mission ──────────────────────────────────────────────────────

/// Opens today's missions. No step count or streak: the app has no pedometer
/// and keeps no streak, so the card only names what is waiting.
class _DailyMissionCard extends StatelessWidget {
  const _DailyMissionCard();

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      color: AppPaletteT2.cardWarm,
      onTap: () => showDailyMissionsBottomSheet(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/mascot-assets/icons/home_play.webp', height: 62),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('today_mission'.tr(), style: context.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'mission_cta'.tr(),
                  style: context.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
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
    // Value unused on purpose: checkDeviceOnline compares against the clock,
    // and nothing rebuilds when a sole goes silent. Watching this provider is
    // what re-runs build when its timer fires.
    ref.watch(deviceOnlineProvider);
    // This card is titled with [device]'s name, so it must report [device]'s
    // own link — not `deviceOnlineProvider`, which is true while *any* foot is
    // streaming, nor the primary sole's window.
    final telemetry = device == null
        ? const LiveTelemetryState()
        : ref.watch(liveTelemetryProvider(device!.identityKey));
    final online = ref
        .watch(telemetryFacadeProvider)
        .checkDeviceOnline(telemetry.updatedAt);
    final recent = telemetry.recentImu;
    // Live while online; otherwise the level remembered for this sole, grayed
    // out. A sole never connected shows an empty gray bar.
    final battery = BatteryDisplay.resolve(
      live: online && recent.isNotEmpty ? recent.last.batteryPercent : null,
      lastKnown: device?.lastBatteryPercent,
    );
    final name = device?.name ?? 'not_binding'.tr();

    return MascotCard(
      color: AppPaletteT2.gold,
      onTap: () => context.push('/my-devices'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$name ${'device_product_name'.tr()}',
                  style: context.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 4),
          Text(
            online ? 'device_synced'.tr() : 'offline'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppPaletteT2.ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MascotProgressBar(
                  value: battery.fraction,
                  height: 20,
                  fill: battery.isLive
                      ? AppPaletteT2.safe
                      : AppPaletteT2.inkFaint,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                battery.label,
                style: battery.isLive
                    ? context.textTheme.headlineMedium
                    : context.textTheme.headlineMedium?.copyWith(
                        color: AppPaletteT2.inkMuted,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 4. Foot pressure check ────────────────────────────────────────────────

/// The last foot check the wearer finished: its band and when. With none on
/// record it says so — no number — and the button starts one.
class FootCheckCardT2 extends ConsumerWidget {
  const FootCheckCardT2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastFootCheckProvider);

    return MascotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('foot_check_title'.tr(), style: context.textTheme.titleMedium),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      last == null
                          ? 'foot_check_none_yet'.tr()
                          : last.rating.labelKey.tr(),
                      style: last == null
                          ? context.textTheme.titleLarge
                          : context.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppPaletteT2.ink,
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      last == null
                          ? 'foot_check_none_yet_hint'.tr()
                          : 'foot_health_check_last'.tr(
                              args: [lastFootCheckDate(context, last)],
                            ),
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Image.asset('assets/mascot-assets/checking.webp', height: 86),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/foot-check'),
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

/// Mirrors `WarningCard`'s counting model: falls seen since the app started,
/// and the copy says exactly that — there is no persisted history and no
/// contacts feature, so no "7 days" and no "family notified".
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
          Image.asset(
            'assets/mascot-assets/icons/home_shield.webp',
            height: 54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'fall_guard_active'.tr(),
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  safe
                      ? 'fall_guard_none_since_open'.tr()
                      : 'fall_guard_count_since_open'.tr(
                          args: ['$_eventCount'],
                        ),
                  style: context.textTheme.bodyMedium,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

// ── 6. Recent device data ─────────────────────────────────────────────────

/// Live IMU trace + a legend, tapping through to the detail panel.
///
/// Real data — the mascot theme's counterpart to `RecentDataChartCard`. The
/// line colors come from `AppPalette.chartSeries` in both themes: they encode
/// which channel is which, so they are not restyled per theme.
class _RecentDataCard extends StatelessWidget {
  const _RecentDataCard();

  @override
  Widget build(BuildContext context) {
    Color colorOf(int i) =>
        AppPalette.chartSeries[i % AppPalette.chartSeries.length];

    return MascotCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      onTap: () => context.push('/analytics-detail'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'device_recent_data'.tr(),
                  style: context.textTheme.titleMedium,
                ),
              ),
              Text('view'.tr(), style: context.textTheme.labelLarge),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          ImuChartSection(type: ChardDisplayType.all),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < imuChannelLabels.length; i++)
                _LegendChip(color: colorOf(i), label: imuChannelLabels[i]),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small outlined swatch + channel name, this theme's answer to the classic
/// card's Material chips.
class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppPaletteT2.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppPaletteT2.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppPaletteT2.ink, width: 1),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: AppPaletteT2.ink,
            ),
          ),
        ],
      ),
    );
  }
}
