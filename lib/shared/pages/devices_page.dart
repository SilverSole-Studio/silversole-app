import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/ble/debug_fake_sole.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/relative_time.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_view_data.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/pages/theme_two/devices_page_t2.dart';
import 'package:silversole/shared/providers/firmware_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_facade_provider.dart';
import 'package:silversole/shared/widgets/build_material_popup_menu.dart';
import 'package:silversole/shared/widgets/firmware_card_parts.dart';
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
/// The paired rows and their battery levels are real, and the firmware block
/// shows the connected sole's version and offers updates
/// ([firmwareCheckProvider]).
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

  /// Forgets every paired device. Soles are recognised by their chip ID, but
  /// older entries recorded by address only can still pile up (one per reboot,
  /// from before the firmware sent an ID); clearing them also stops
  /// auto-connect until the next manual pairing.
  void clearAllDevices() {
    final settings = ref.read(settingsProvider.notifier);
    showConfirmLeaveDialog(
      context,
      title: 'clear_all_devices_title'.tr(),
      text: 'clear_all_devices_content'.tr(),
      confirmText: 'clear_all_devices'.tr(),
      confirmType: ConfirmType.delete,
      onConfirm: () async {
        await settings.setPairedDevices([]);
        showMessage('clear_all_devices_success'.tr());
      },
    );
  }

  /// Assigning a foot takes it off whichever sole had it — see
  /// [assignFootSide].
  Future<void> setFootSide(BlePairedDevice device, FootSide side) async {
    await ref
        .read(settingsProvider.notifier)
        .setFootSide(device.identityKey, side);
    showMessage(side.labelKey.tr());
  }

  Future<void> deleteDevice(BlePairedDevice device) async {
    final settings = ref.read(settingsProvider.notifier);
    await settings.removePairedDevice(device);
    showMessage('delete_device_success'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // Value unused on purpose: checkDeviceOnline compares against the clock,
    // and nothing rebuilds when a sole goes silent. Watching this provider is
    // what re-runs build when its timer fires.
    ref.watch(deviceOnlineProvider);
    final facade = ref.watch(telemetryFacadeProvider);
    final rows = buildDeviceRows(
      devices: settings.pairedDevicesList,
      liveFor: (key) {
        final telemetry = ref.watch(liveTelemetryProvider(key));
        return SoleLiveFacts(
          online: facade.checkDeviceOnline(telemetry.updatedAt),
          batteryPercent: telemetry.recentImu.lastOrNull?.batteryPercent,
        );
      },
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
                onSetFootSide: setFootSide,
              ),
              const _FirmwareCard(),
              if (kDebugMode) const _DebugFakeSoleCard(),
              if (rows.isNotEmpty)
                TextButton.icon(
                  onPressed: clearAllDevices,
                  icon: const Icon(LucideIcons.trash2),
                  label: Text('clear_all_devices'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colorScheme.error,
                  ),
                ),
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
    required this.onSetFootSide,
  });

  final List<DeviceRow> rows;
  final ValueChanged<BlePairedDevice> onRename;
  final ValueChanged<BlePairedDevice> onDelete;
  final ValueChanged<BlePairedDevice> onSetPreferred;
  final void Function(BlePairedDevice device, FootSide side) onSetFootSide;

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
                    onSetFootSide: onSetFootSide,
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
    required this.onSetFootSide,
  });

  final DeviceRow row;
  final ValueChanged<BlePairedDevice> onRename;
  final ValueChanged<BlePairedDevice> onDelete;
  final ValueChanged<BlePairedDevice> onSetPreferred;
  final void Function(BlePairedDevice device, FootSide side) onSetFootSide;

  @override
  Widget build(BuildContext context) {
    final device = row.device;
    final battery = row.battery;
    // A remembered (not live) level is grayed out so it reads as "previous".
    final batteryColor = battery.isLive
        ? context.colorScheme.primary
        : context.colorScheme.onSurfaceVariant;
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
              // Every sole is called "SilverSole"; the ID suffix tells them
              // apart.
              Row(
                spacing: AppSpacing.sm,
                children: [
                  Flexible(
                    child: Text(
                      device.name,
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (device.shortId case final shortId?)
                    Text(
                      '••••$shortId',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (device.footSide case final side?)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: ShapeDecoration(
                        color: context.colorScheme.secondaryContainer,
                        shape: AppRadius.pillShape,
                      ),
                      child: Text(
                        side.labelKey.tr(),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
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
            value: battery.fraction,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            stopIndicatorRadius: 0,
            trackGap: 4,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            // A remembered level fills in the track's own gray; the track gap
            // still marks the level.
            valueColor: AlwaysStoppedAnimation<Color>(
              battery.isLive
                  ? context.colorScheme.primary
                  : context.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 46,
          child: Text(
            battery.label,
            textAlign: TextAlign.right,
            style: battery.isLive
                ? context.textTheme.titleMedium
                : context.textTheme.titleMedium?.copyWith(color: batteryColor),
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
              title: 'set_left_foot'.tr(),
              icon: LucideIcons.footprints,
              enable: device.footSide != FootSide.left,
              onClick: () => onSetFootSide(device, FootSide.left),
            ),
            ListTileData.normal(
              title: 'set_right_foot'.tr(),
              icon: LucideIcons.footprints,
              enable: device.footSide != FootSide.right,
              onClick: () => onSetFootSide(device, FootSide.right),
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

class _FirmwareCard extends ConsumerWidget {
  const _FirmwareCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final check = ref.watch(firmwareCheckProvider);
    final devMode = ref.watch(
      settingsProvider.select((s) => s.firmwareDevMode),
    );
    final value = check.value;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpacing.xs,
                  children: [
                    DevModeTapTarget(
                      child: Row(
                        spacing: AppSpacing.sm,
                        children: [
                          Text(
                            'firmware_version'.tr(),
                            style: context.textTheme.titleMedium,
                          ),
                          if (devMode)
                            Text(
                              'firmware_beta'.tr(),
                              style: context.textTheme.labelMedium?.copyWith(
                                color: context.colorScheme.tertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      firmwareCardDetail(value) ??
                          'firmware_not_connected'.tr(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (check.isLoading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (value != null)
                Flexible(child: _FirmwareStatus(check: value)),
            ],
          ),
          if (kDebugMode && (value?.sole?.dfuSupported ?? false))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => pickLocalFirmware(context, ref),
                icon: const Icon(Icons.upload_file),
                label: Text('firmware_update_from_file'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

class _FirmwareStatus extends ConsumerWidget {
  const _FirmwareStatus({required this.check});

  final FirmwareCheck check;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget flag(IconData icon, Color color, String label) => Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
    );
    final version = check.manifest?.version ?? '';
    return switch (firmwareCardAction(check)) {
      FirmwareCardAction.none => const SizedBox.shrink(),
      FirmwareCardAction.upToDate => flag(
        LucideIcons.check,
        context.tokens.success,
        'firmware_up_to_date'.tr(),
      ),
      FirmwareCardAction.update => FilledButton(
        onPressed: () => openFirmwareUpdate(context, check),
        child: Text(
          'firmware_update_to'.tr(args: [version]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      FirmwareCardAction.downgrade => OutlinedButton(
        onPressed: () => confirmDowngrade(context, check),
        child: Text(
          'firmware_downgrade_to'.tr(args: [version]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      FirmwareCardAction.needsWiredUpdate => flag(
        Icons.warning_amber_rounded,
        context.tokens.alert,
        'firmware_needs_wired_update'.tr(),
      ),
      FirmwareCardAction.versionUnreadable => flag(
        Icons.warning_amber_rounded,
        context.tokens.alert,
        'firmware_version_unreadable'.tr(),
      ),
      FirmwareCardAction.appTooOld => flag(
        Icons.warning_amber_rounded,
        context.tokens.alert,
        'firmware_manifest_unsupported'.tr(),
      ),
      FirmwareCardAction.retry => TextButton(
        onPressed: () => ref.invalidate(firmwareCheckProvider),
        child: Text(
          'firmware_check_failed'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    };
  }
}

/// Debug-only handle on the fake second sole — the only way to exercise two
/// feet with one sole in hand.
class _DebugFakeSoleCard extends ConsumerStatefulWidget {
  const _DebugFakeSoleCard();

  @override
  ConsumerState<_DebugFakeSoleCard> createState() => _DebugFakeSoleCardState();
}

class _DebugFakeSoleCardState extends ConsumerState<_DebugFakeSoleCard> {
  @override
  Widget build(BuildContext context) {
    final fake = ref.watch(debugFakeSoleProvider);
    return SectionCard(
      title: 'debug_add_fake_sole'.tr(),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () async {
                fake.isRunning ? await fake.stop() : await fake.start();
                if (context.mounted) setState(() {});
              },
              child: Text(
                fake.isRunning
                    ? 'debug_remove_fake_sole'.tr()
                    : 'debug_add_fake_sole'.tr(),
              ),
            ),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: fake.isRunning ? fake.stomp : null,
              child: Text('debug_fake_sole_stomp'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
