import 'dart:async';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/ble/ble_permissions.dart';
import 'package:silversole/core/ble/sole_scanner.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/build_material_list.dart';
import 'package:silversole/shared/widgets/settings_hint.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

Future<T?> showDeviceConnectBottomModal<T>(BuildContext context) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height,
      width: double.infinity,
      child: const DeviceConnectBottomModal(),
    ),
  );
}

/// What stops the pairing sheet from scanning.
enum _BleBlock { adapterOff, permission }

class DeviceConnectBottomModal extends ConsumerStatefulWidget {
  const DeviceConnectBottomModal({super.key});

  @override
  ConsumerState<DeviceConnectBottomModal> createState() =>
      _DeviceConnectBottomModalState();
}

class _DeviceConnectBottomModalState
    extends ConsumerState<DeviceConnectBottomModal>
    with WidgetsBindingObserver {
  final Map<DeviceIdentifier, ScanResult> _scanMap = {};
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _retryTimer;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  bool _isScanning = false;

  /// Why scanning cannot run, or null. Shown in place of the endless progress
  /// bar, with a button that leads to the fix.
  _BleBlock? _block;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _adapterSub = FlutterBluePlus.adapterState.listen(_onAdapterState);
    } catch (_) {
      // No Bluetooth plugin here (desktop, tests): scanning will say so.
    }
    startNimBleScanLoop();
  }

  void _onAdapterState(BluetoothAdapterState state) {
    if (!mounted) return;
    if (state == BluetoothAdapterState.off) {
      setState(() => _block = _BleBlock.adapterOff);
    } else if (state == BluetoothAdapterState.on &&
        _block == _BleBlock.adapterOff) {
      startNimBleScanLoop();
    }
  }

  /// Back from the system settings: try again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _block != null) {
      startNimBleScanLoop();
    }
  }

  Future<void> _openFix() async {
    if (_block == _BleBlock.adapterOff &&
        defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterBluePlus.turnOn();
        return;
      } catch (_) {
        // Refused or unsupported: fall through to the settings page.
      }
    }
    await ph.openAppSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _retryTimer?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> startNimBleScanLoop() async {
    final hasPermission = await ensureScanPermission();
    if (!hasPermission) {
      if (mounted) setState(() => _block = _BleBlock.permission);
      return;
    }
    if (_adapterOff) {
      if (mounted) setState(() => _block = _BleBlock.adapterOff);
      return;
    }
    if (_block != null && mounted) setState(() => _block = null);

    _scanSub ??= FlutterBluePlus.scanResults.listen((results) {
      var changed = false;
      for (final r in results) {
        if (!isSoleName(scanResultName(r))) continue;
        _scanMap[r.device.remoteId] = r;
        changed = true;
      }
      if (changed && mounted) setState(() {});
    });

    await startScan();
  }

  Future<bool> ensureScanPermission() async {
    try {
      return await requestBleScanPermission();
    } on MissingPluginException {
      // Desktop (macOS) has no permission_handler implementation; CoreBluetooth
      // prompts for Bluetooth on the first scan, so just proceed.
      return true;
    }
  }

  bool get _adapterOff {
    try {
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.off;
    } catch (_) {
      return false;
    }
  }

  Future<void> startScan() async {
    if (_isScanning || FlutterBluePlus.isScanningNow) return;
    _isScanning = true;
    if (mounted) setState(() {});
    try {
      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } on PlatformException catch (e) {
      final message = e.message ?? e.code;
      showErrorSnakeBar(message);

      if (message.toLowerCase().contains('scanning too frequently')) {
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 15), () {
          if (mounted) startScan();
        });
      }
    } catch (e) {
      showErrorSnakeBar(e.toString());
    } finally {
      _isScanning = false;
      if (mounted) setState(() {});
    }
  }

  /// Every sole advertises the same name, so each row is told apart by the
  /// last 4 characters of its chip ID. A sole on firmware too old to send one
  /// shows its address instead, marked as old firmware.
  List<ListTileData> getNearbyDevices(List<BlePairedDevice> paired) {
    final soles = _scanMap.values.map(SoleCandidate.fromScanResult).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return soles.map((sole) {
      final id = sole.deviceId;
      final subtitle = [
        if (id != null)
          'ID ••••${id.substring(id.length - 4)}'
        else ...[
          sole.remoteId,
          'sole_legacy_firmware'.tr(),
        ],
        if (paired.any((d) => isSameSole(sole, d))) 'sole_already_paired'.tr(),
      ].join(' · ');
      return ListTileData.normal(
        title: sole.name.isEmpty ? 'unknown_device'.tr() : sole.name,
        subtitle: subtitle,
        icon: LucideIcons.bluetooth,
        onClick: () => connectAndBindDevice(sole),
      );
    }).toList();
  }

  Future<void> connectAndBindDevice(SoleCandidate sole) async {
    final settings = ref.read(settingsProvider);
    final hasPreferredDevice = settings.preferredDevice != null;
    // Re-pairing a known sole keeps what the user gave it (its name, the
    // remembered battery level) and only moves it to the address it is on now.
    final known = settings.pairedDevicesList.firstWhereOrNull(
      (d) => isSameSole(sole, d),
    );
    final device =
        known?.copyWith(
          remoteId: sole.remoteId,
          deviceId: sole.deviceId ?? known.deviceId,
          lastRssi: sole.rssi,
          lastConnectedAt: DateTime.now(),
        ) ??
        BlePairedDevice(
          remoteId: sole.remoteId,
          name: sole.name.isEmpty ? 'unknown_device'.tr() : sole.name,
          deviceId: sole.deviceId,
          lastRssi: sole.rssi,
          lastConnectedAt: DateTime.now(),
        );
    final name = device.name;

    // Add paired device
    await ref.read(settingsProvider.notifier).addOrUpdatePairedDevice(device);
    var shouldSetPreferred = false;

    // Also try to set prefer device
    if (mounted && !hasPreferredDevice) {
      await showConfirmLeaveDialog(
        context,
        title: 'set_primary_device_title'.tr(),
        text: 'set_primary_device_content'.tr(namedArgs: {'deviceName': name}),
        onConfirm: () {
          shouldSetPreferred = true;
        },
      );
    }
    if (shouldSetPreferred) {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.isScanning
          .firstWhere((value) => value == false)
          .timeout(const Duration(seconds: 3));
      await ref.read(settingsProvider.notifier).setPreferredDevice(device);
      showMessage('set_primary_device_success'.tr());
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const hPadding = EdgeInsets.symmetric(horizontal: AppSpacing.base);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 52, 0, 36),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.base,
          children: [
            Padding(
              padding: hPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.base,
                children: [
                  Text(
                    'scanning_nearby_devices'.tr(),
                    style: context.textTheme.displaySmall,
                  ),
                  Text(
                    'select_your_silversole_device'.tr(),
                    style: context.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            if (_block == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: LinearProgressIndicator(),
              )
            else
              SettingsHint(
                icon: LucideIcons.bluetoothOff,
                title:
                    (_block == _BleBlock.adapterOff
                            ? 'ble_off_title'
                            : 'ble_permission_title')
                        .tr(),
                body:
                    (_block == _BleBlock.adapterOff
                            ? 'ble_off_body'
                            : 'ble_permission_body')
                        .tr(),
                buttonLabel:
                    _block == _BleBlock.adapterOff &&
                        defaultTargetPlatform == TargetPlatform.android
                    ? 'ble_turn_on'.tr()
                    : 'open_settings'.tr(),
                onPressed: _openFix,
              ),
            Expanded(
              child: Padding(
                padding: hPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.md,
                  children: [
                    Text(
                      'nearby_devices'.tr(),
                      style: context.textTheme.titleLarge,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: buildMaterialList(
                          context,
                          raw: getNearbyDevices(
                            ref.watch(settingsProvider).pairedDevicesList,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: hPadding,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('cancel'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
