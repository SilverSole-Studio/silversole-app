import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/relative_time.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_view_data.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/pages/theme_two/devices_page_t2.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/build_material_popup_menu.dart';
import 'package:silversole/shared/widgets/rader_dot.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// Route target for `/my-devices`: picks the themed implementation, so
/// switching theme while the page is open swaps it rather than leaving the
/// other theme's chrome on screen.
class DevicesRoute extends ConsumerWidget {
  const DevicesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(settingsProvider.select((s) => s.themeVariant));
    return variant == AppThemeVariant.mascot
        ? const DevicesPageT2()
        : const DevicesPage();
  }
}

/// "My devices", classic theme — the panel behind the home screen's device
/// status card.
///
/// Same content as [DevicesPageT2] in this theme's vocabulary ([SectionCard],
/// stock progress/chips, the blue accent), with one deliberate difference:
/// no "pair new device" button. The classic home already pairs from the device
/// carousel's trailing "+" page and its add-device FAB, so a third entry point
/// here would be redundant.
///
/// The paired rows and their battery levels are real; the firmware block is
/// [MockFirmware] — the sole does not report a version yet.
class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  Future<void> debugStartService() async {
    try {
      await startBleService();
      showMessage('BLE service started');
    } catch (e) {
      showErrorSnakeBar(e.toString());
    }
  }

  Future<void> debugStopService() async {
    try {
      await stopBleService();
      showMessage('BLE service stopped');
    } catch (e) {
      showErrorSnakeBar(e.toString());
    }
  }

  void setPreferredDevice(BlePairedDevice target) {
    final settings = ref.read(settingsProvider.notifier);
    showConfirmLeaveDialog(
      context,
      title: 'set_primary_device_title'.tr(),
      text: 'set_primary_device_content'.tr(
        namedArgs: {'deviceName': target.name},
      ),
      onConfirm: () async {
        await settings.setPreferredDevice(target);
        showMessage('set_primary_device_success'.tr());
      },
    );
  }

  Future<void> renameDevice(BlePairedDevice device) async {
    bool result = false;
    String newName = device.name;
    final controller = TextEditingController(text: device.name);
    try {
      await showContentDialog(
        context,
        title: 'rename_this_device'.tr(),
        confirmText: 'rename'.tr(),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          maxLength: 24,
          decoration: InputDecoration(
            hintText: 'device_name'.tr(),
            counterText: '',
          ),
          onChanged: (v) => newName = v.trim(),
        ),
        onClick: () => result = true,
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
    if (!mounted || !result || newName.isEmpty || newName == device.name) {
      return;
    }
    final settings = ref.read(settingsProvider.notifier);
    await settings.addOrUpdatePairedDevice(device.copyWith(name: newName));
    showMessage('rename_device_success'.tr());
  }

  Future<void> deleteDevice(BlePairedDevice device) async {
    final settings = ref.read(settingsProvider.notifier);
    await settings.removePairedDevice(device);
    showMessage('delete_device_success'.tr());
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('my_devices'.tr(), style: context.textTheme.titleLarge),
        actions: [
          // Debug-only handles on the Android foreground service.
          if (kDebugMode) ...[
            IconButton(
              onPressed: debugStartService,
              icon: const Icon(Icons.play_arrow),
            ),
            IconButton(
              onPressed: debugStopService,
              icon: const Icon(Icons.stop),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.base,
            children: [
              const _HeroCard(),
              _DeviceListCard(
                rows: rows,
                onRename: renameDevice,
                onDelete: deleteDevice,
                onSetPreferred: setPreferredDevice,
              ),
              const _FirmwareCard(),
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
    return SectionCard(
      child: Column(
        children: [
          Image.asset(
            'assets/images/silversole_full.png',
            height: 150,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'device_hero_caption'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Paired devices ─────────────────────────────────────────────────────

class _DeviceListCard extends StatelessWidget {
  const _DeviceListCard({
    required this.rows,
    required this.onRename,
    required this.onDelete,
    required this.onSetPreferred,
  });

  final List<DeviceRow> rows;
  final ValueChanged<BlePairedDevice> onRename;
  final ValueChanged<BlePairedDevice> onDelete;
  final ValueChanged<BlePairedDevice> onSetPreferred;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'current_devices'.tr(),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
              child: Text(
                'no_paired_devices'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: AppSpacing.lg),
                  _DeviceRowTile(
                    row: rows[i],
                    onRename: onRename,
                    onDelete: onDelete,
                    onSetPreferred: onSetPreferred,
                  ),
                ],
              ],
            ),
    );
  }
}

class _DeviceRowTile extends StatelessWidget {
  const _DeviceRowTile({
    required this.row,
    required this.onRename,
    required this.onDelete,
    required this.onSetPreferred,
  });

  final DeviceRow row;
  final ValueChanged<BlePairedDevice> onRename;
  final ValueChanged<BlePairedDevice> onDelete;
  final ValueChanged<BlePairedDevice> onSetPreferred;

  @override
  Widget build(BuildContext context) {
    final device = row.device;
    final battery = row.batteryPercent;
    final lastSeen = device.lastConnectedAt;
    final status = row.online
        ? 'signal_good'.tr()
        : (lastSeen != null
              ? 'last_connected'.tr(args: [formatTimeAgo(lastSeen)])
              : 'offline'.tr());
    final statusColor = row.online
        ? context.tokens.success
        : context.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          LucideIcons.footprints,
          color: context.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                device.name,
                style: context.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                spacing: AppSpacing.sm,
                children: [
                  RadarDot(active: row.online, color: statusColor),
                  Flexible(
                    child: Text(
                      status,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 72,
          child: LinearProgressIndicator(
            year2023: false, // ignore: deprecated_member_use
            value: (battery ?? 0) / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            stopIndicatorRadius: 0,
            trackGap: 4,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              context.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 46,
          child: Text(
            battery != null ? '$battery%' : '--',
            textAlign: TextAlign.right,
            style: context.textTheme.titleMedium,
          ),
        ),
        buildMaterialPopupMenu(
          context,
          raw: [
            ListTileData.normal(
              title: 'set_primary_device_title'.tr(),
              icon: LucideIcons.star,
              enable: !device.isPreferred,
              onClick: () => onSetPreferred(device),
            ),
            ListTileData.normal(
              title: 'rename'.tr(),
              icon: LucideIcons.pencil,
              onClick: () => onRename(device),
            ),
            ListTileData.normal(
              title: 'delete'.tr(),
              icon: LucideIcons.trash,
              needCheck: true,
              checkTitle: 'delete_device_title'.tr(),
              checkContent: 'delete_device_content'.tr(),
              onClick: () => onDelete(device),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 3. Firmware ───────────────────────────────────────────────────────────

class _FirmwareCard extends StatelessWidget {
  const _FirmwareCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
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
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'firmware_detail'.tr(
                    args: [
                      MockFirmware.version,
                      '${MockFirmware.sampleRateHz}',
                    ],
                  ),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Chip(
            avatar: Icon(
              LucideIcons.check,
              size: 16,
              color: context.tokens.success,
            ),
            label: Text('firmware_up_to_date'.tr()),
          ),
        ],
      ),
    );
  }
}
