import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/ble/ble_service_channel.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/pages/device_connect_bottom_modal.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';
import 'package:silversole/shared/widgets/status_card.dart';

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  void callOpenDeviceConnection() {
    showDeviceConnectBottomModal(context);
  }

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
      text: 'set_primary_device_content'.tr(namedArgs: {'deviceName': target.name}),
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
    if (!mounted || !result || newName.isEmpty || newName == device.name) return;
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final pairedDevicesList = settings.pairedDevicesList;

    return Scaffold(
      appBar: AppBar(
        title: Text('devices'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: debugStartService, icon: Icon(Icons.play_arrow)),
          IconButton(onPressed: debugStopService, icon: Icon(Icons.stop)),
        ],
      ),
      // Add Device
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_devices_page',
        onPressed: callOpenDeviceConnection,
        child: Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchBar(
                  leading: Container(
                    margin: EdgeInsets.only(left: 8),
                    child: Icon(LucideIcons.search, color: cs.onSurfaceVariant),
                  ),
                  hintText: 'search_device'.tr(),
                  elevation: const WidgetStatePropertyAll(0),
                ),
                const SizedBox(height: 16),
                Text('current_devices'.tr(), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ...pairedDevicesList.map(
                  (item) => DeviceStatusCard(
                    type: StatusCardType.menu,
                    name: item.name,
                    model: item.displayModel ?? 'unknown_model'.tr(),
                    id: item.remoteId,
                    menuItems: [
                      ListTileData.normal(
                        title: 'rename'.tr(),
                        icon: LucideIcons.pencil,
                        onClick: () => renameDevice(item),
                      ),
                      ListTileData.normal(
                        title: 'delete'.tr(),
                        icon: LucideIcons.trash,
                        needCheck: true,
                        checkTitle: 'delete_device_title'.tr(),
                        checkContent: 'delete_device_content'.tr(),
                        onClick: () => deleteDevice(item),
                      ),
                    ],
                    activeDisplay: false,
                    onClick: () => setPreferredDevice(item),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
