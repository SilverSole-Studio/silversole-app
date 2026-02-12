import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/result.dart';

import '../../core/error/error_logger.dart';
import '../models/app_settings.dart';
import '../models/user_identity.dart';
import '../providers/settings_provider.dart';
import '../providers/sole_provider.dart';
import 'account_card.dart';

class DeviceStatusCard extends ConsumerStatefulWidget {
  const DeviceStatusCard({super.key});

  @override
  ConsumerState<DeviceStatusCard> createState() => _DeviceStatusCard();
}

class _DeviceStatusCard extends ConsumerState<DeviceStatusCard> {
  ProviderSubscription<AppSettings>? _sub;
  bool _load = false;
  bool? _online;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<AppSettings>(settingsProvider, (prev, next) {
      final deviceId = next.deviceId;
      if (!_load && deviceId != null && deviceId.isNotEmpty) {
        _load = true;
        refreshDeviceStatus(deviceId);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _sub?.close();
  }

  Future<void> refreshDeviceStatus(String deviceId) async {
    setState(() {
      _online = null;
    });
    final service = ref.read(soleProvider);
    final result = await service.getDeviceLastUpdateTime(deviceId: deviceId);
    switch (result) {
      case Ok<DateTime?>():
        if (!mounted) return;
        setState(() {
          _online = service.checkDeviceOnline(result.value);
        });
        return showMessage('get_last_update_time_success'.tr());
      case Error():
        return showErrorSnakeBar(result.error.toString());
    }
  }

  Future<void> openDeviceStatusPage() async {
    //TODO: this is test feature now
    // context.push('/device-status');
    debugPrint('click device card');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final deviceNickName = settings.deviceId != null ? 'SilverSole 原型機' : 'not_binding'.tr(); //FIXME: Test code
    final deviceId = settings.deviceId ?? '';
    final identity = settings.identity;
    final activeDisplay = identity == UserIdentity.transmitter.value && settings.deviceId != null; //FIXME: Test code

    return statusCard(
      context,
      type: StatusCardType.statusDisplay,
      title: deviceNickName,
      subtitle: deviceId,
      icon: LucideIcons.footprints,
      active: activeDisplay ? _online : null,
      onTap: () => refreshDeviceStatus(deviceId),
    );
  }
}
