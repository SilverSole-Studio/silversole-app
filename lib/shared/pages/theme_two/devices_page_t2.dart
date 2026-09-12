import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/battery_level.dart';
import 'package:silversole/core/utils/relative_time.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/device_view_data.dart';
import 'package:silversole/shared/pages/device_connect_bottom_modal.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// "My devices", mascot theme — the panel behind the home screen's device
/// card.
///
/// The product shot, the paired-device rows and the pairing button are real:
/// rows come from the paired list, and the connected one shows its live
/// battery. The firmware block is [MockFirmware] — the sole does not report a
/// version yet.
class DevicesPageT2 extends ConsumerWidget {
  const DevicesPageT2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final recent = ref.watch(telemetryViewProvider).recentImu;
    final rows = buildDeviceRows(
      devices: settings.pairedDevicesList,
      preferred: settings.preferredDevice,
      online: ref.watch(deviceOnlineProvider),
      liveBatteryPercent: recent.isEmpty ? null : recent.last.batteryPercent,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('my_devices'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              const _HeroCard(),
              _DeviceListCard(rows: rows),
              const _FirmwareCard(),
              const _PairButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 1. Product shot ───────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      child: Column(
        children: [
          Image.asset(
            'assets/images/silversole_full.png',
            height: 170,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 12),
          Text(
            'device_hero_caption'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

// ── 2. Paired devices ─────────────────────────────────────────────────────

class _DeviceListCard extends StatelessWidget {
  const _DeviceListCard({required this.rows});

  final List<DeviceRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return MascotCard(
        child: Text(
          'no_paired_devices'.tr(),
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge,
        ),
      );
    }

    return MascotCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            _DeviceRowTile(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _DeviceRowTile extends StatelessWidget {
  const _DeviceRowTile({required this.row});

  final DeviceRow row;

  @override
  Widget build(BuildContext context) {
    final battery = row.batteryPercent;
    final lastSeen = row.device.lastConnectedAt;
    final status = row.online
        ? 'signal_good'.tr()
        : (lastSeen != null
              ? 'last_connected'.tr(args: [formatTimeAgo(lastSeen)])
              : 'offline'.tr());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Image.asset('assets/mascot-assets/icons/dev_foot.webp', height: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.device.name,
                  style: context.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: context.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: MascotProgressBar(
              value: battery?.batteryFraction ?? 0,
              height: 18,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              battery?.batteryLabel ?? '-',
              textAlign: TextAlign.right,
              style: context.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3. Firmware ───────────────────────────────────────────────────────────

class _FirmwareCard extends StatelessWidget {
  const _FirmwareCard();

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'firmware_version'.tr(),
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'firmware_detail'.tr(
                    args: [
                      MockFirmware.version,
                      '${MockFirmware.sampleRateHz}',
                    ],
                  ),
                  style: context.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          MascotPill(
            color: AppPaletteT2.safeSoft,
            child: Text(
              'firmware_up_to_date'.tr(),
              style: context.textTheme.labelLarge?.copyWith(
                color: AppPaletteT2.safe,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 4. Pair a new device ──────────────────────────────────────────────────

class _PairButton extends StatelessWidget {
  const _PairButton();

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      onTap: () => showDeviceConnectBottomModal(context),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_circle_outline,
            size: 26,
            color: AppPaletteT2.ink,
          ),
          const SizedBox(width: 10),
          Text('device_pair_new'.tr(), style: context.textTheme.titleLarge),
        ],
      ),
    );
  }
}
