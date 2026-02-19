import 'dart:developer';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/pages/device_connect_bottom_modal.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  void callOpenDeviceConnection() {
    showDeviceConnectBottomModal(context);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final pairedDevicesList = settings.pairedDevicesList ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('devices'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                for (int i = 0; i < pairedDevicesList.length; i++)
                  DeviceStatusCard(
                    name: pairedDevicesList[i].name,
                    model: pairedDevicesList[i].displayModel ?? 'unknown_model'.tr(),
                    id: pairedDevicesList[i].remoteId,
                    onClick: () => setPreferredDevice(pairedDevicesList[i]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
