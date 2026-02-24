import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/models/list_tile_data_model.dart';
import 'package:silversole/shared/providers/telemetry_facade_provider.dart';

import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import 'status_card.dart';

class DeviceStatusCard extends ConsumerStatefulWidget {
  final StatusCardType type;
  final String name;
  final String model;
  final String id;
  final bool activeDisplay;
  final DeviceStatusDetailModel? detail;
  final List<ListTileData> menuItems;
  final VoidCallback? onClick;

  const DeviceStatusCard({
    super.key,
    this.type = StatusCardType.normal,
    required this.name,
    required this.model,
    required this.id,
    required this.activeDisplay,
    this.detail,
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

  //TODO: Remove code and create reload logic in other place
  /*
  bool? _online;
  DeviceStatusDetailModel? _detail;
  Future<void> refreshDeviceStatus(String deviceId) async {
    setState(() {
      _online = null;
    });
    final service = ref.read(soleProvider);
    final result = await service.getDeviceStatusDetail(deviceId: deviceId);
    switch (result) {
      case Ok<DeviceStatusDetailModel>():
        if (!mounted) return;
        setState(() {
          _online = service.checkDeviceOnline(result.value.lastHeartbeatAt);
          _detail = result.value;
        });
        return showMessage('get_last_update_time_success'.tr());
      case Error():
        return showErrorSnakeBar(result.error.toString());
    }
  }
   */

  Future<void> openDeviceStatusPage() async {
    //TODO: this is test feature now
    // context.push('/device-stat us');
    // debugPrint('click device card');
  }

  @override
  Widget build(BuildContext context) {
    final facade = ref.watch(telemetryFacadeProvider);

    return statusCard(
      context,
      type: widget.type,
      title: widget.name,
      model: widget.model,
      id: widget.id,
      icon: LucideIcons.footprints,
      menuItems: widget.menuItems,
      active: facade.checkDeviceOnline(widget.detail?.lastHeartbeatAt),
      addition: true,
      detail: widget.detail,
      onTap: widget.onClick ?? () {},
    );
  }
}
