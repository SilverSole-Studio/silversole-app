import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/device_online_provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import 'status_card.dart';

class DeviceStatusCard extends ConsumerStatefulWidget {
  final StatusCardType type;
  final String name;
  final String model;
  final String id;
  final bool activeDisplay;
  final bool frosted;
  final DeviceStatusDetailModel? detail;
  final DateTime? lastConnectedAt;
  final List<ListTileData> menuItems;
  final VoidCallback? onClick;

  const DeviceStatusCard({
    super.key,
    this.type = StatusCardType.normal,
    required this.name,
    required this.model,
    required this.id,
    required this.activeDisplay,
    this.frosted = false,
    this.detail,
    this.lastConnectedAt,
    this.menuItems = const <ListTileData>[],
    this.onClick,
  });

  @override
  ConsumerState<DeviceStatusCard> createState() => _DeviceStatusCard();
}

class _DeviceStatusCard extends ConsumerState<DeviceStatusCard> {
  ProviderSubscription<AppSettings>? _sub;
  bool _load = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<AppSettings>(settingsProvider, (prev, next) {
      final deviceId = next.deviceId;
      if (!_load && deviceId != null && deviceId.isNotEmpty) {
        _load = true;
        // refreshDeviceStatus(deviceId);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    super.dispose();
    _sub?.close();
  }

  Future<void> openDeviceStatusPage() async {
    //TODO: this is test feature now
    // context.push('/device-stat us');
    // debugPrint('click device card');
  }

  @override
  Widget build(BuildContext context) {
    return statusCard(
      context,
      type: widget.type,
      title: widget.name,
      model: widget.model,
      id: widget.id,
      icon: LucideIcons.footprints,
      menuItems: widget.menuItems,
      active: ref.watch(deviceOnlineProvider),
      addition: true,
      frosted: widget.frosted,
      detail: widget.detail,
      lastConnectedAt: widget.lastConnectedAt,
      onTap: widget.onClick ?? () {},
    );
  }
}
