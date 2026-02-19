import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/build_material_list.dart';

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

class DeviceConnectBottomModal extends ConsumerStatefulWidget {
  const DeviceConnectBottomModal({super.key});

  @override
  ConsumerState<DeviceConnectBottomModal> createState() => _DeviceConnectBottomModalState();
}

class _DeviceConnectBottomModalState extends ConsumerState<DeviceConnectBottomModal> {
  final Map<DeviceIdentifier, ScanResult> _scanMap = {};
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _retryTimer;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    startNimBleScanLoop();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _retryTimer?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> startNimBleScanLoop() async {
    final hasPermission = await ensureScanPermission();
    if (!hasPermission) return;

    _scanSub ??= FlutterBluePlus.scanResults.listen((results) {
      var changed = false;
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.platformName;
        if (!name.toLowerCase().contains('silversole')) continue;
        _scanMap[r.device.remoteId] = r;
        changed = true;
      }
      if (changed && mounted) setState(() {});
    });

    await startScan();
  }

  Future<bool> ensureScanPermission() async {
    final statuses = await [Permission.bluetoothScan, Permission.locationWhenInUse].request();
    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;
    if (scanGranted) return true;
    showErrorSnakeBar('Bluetooth scan permission is required.');
    return false;
  }

  Future<void> startScan() async {
    if (_isScanning || FlutterBluePlus.isScanningNow) return;
    _isScanning = true;
    if (mounted) setState(() {});
    try {
      await FlutterBluePlus.startScan(androidScanMode: AndroidScanMode.lowLatency);
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

  List<ListTileData> getNearbyDevices() {
    final item = _scanMap.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    return item.map((r) {
      final name = r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.platformName;
      return ListTileData.normal(
        title: name.isEmpty ? 'unknown_device'.tr() : name,
        subtitle: r.device.remoteId.str,
        icon: LucideIcons.bluetooth,
        onClick: () => connectAndBindDevice(r),
      );
    }).toList();
  }

  Future<void> connectAndBindDevice(ScanResult result) async {
    final hasPreferredDevice = ref.read(settingsProvider).preferredDevice != null;
    final name = result.advertisementData.advName.isNotEmpty
        ? result.advertisementData.advName
        : result.device.platformName;
    final device = BlePairedDevice(
      remoteId: result.device.remoteId.str,
      name: name.isEmpty ? 'unknown_device'.tr() : name,
      lastRssi: result.rssi,
      lastConnectedAt: DateTime.now(),
    );

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
      await ref.read(settingsProvider.notifier).setPreferredDevice(device);
      showMessage('set_primary_device_success'.tr());
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const hPadding = EdgeInsets.symmetric(horizontal: 16);

    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 52, 0, 36),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Padding(
              padding: hPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  Text('scanning_nearby_devices'.tr(), style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                  Text('select_your_silversole_device'.tr(), style: tt.bodyLarge),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: const LinearProgressIndicator()),
            Expanded(
              child: Padding(
                padding: hPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Text('nearby_devices'.tr(), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: SingleChildScrollView(
                        child: buildMaterialList(context, raw: getNearbyDevices(), themeColor: cs.surface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: hPadding,
              child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text('cancel'.tr())),
            ),
          ],
        ),
      ),
    );
  }
}
