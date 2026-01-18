import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/sole_record_data_model.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/sole_provider.dart';

import '../../core/error/result.dart';

class RecentDataList extends ConsumerStatefulWidget {
  const RecentDataList({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _RecentDataListState();
}

class _RecentDataListState extends ConsumerState<RecentDataList> {
  final List<SilverSoleRecordModel> _items = [];
  ProviderSubscription<AppSettings>? _sub;
  bool _loaded = false;

  Future<void> getRecentData() async {
    final userProvider = ref.read(authUserProvider);
    final settings = ref.read(settingsProvider);
    if (userProvider == null) {
      showErrorSnakeBar('not_signed_in'.tr());
      return;
    }
    if (settings.deviceId == null) {
      showErrorSnakeBar('not_binding'.tr());
      return;
    }
    final soleService = ref.read(soleProvider);
    final result = await soleService.getRecentDeviceData(deviceId: settings.deviceId ?? '', limit: 20);
    debugPrint(result.toString());

    switch (result) {
      case Ok<List<SilverSoleRecordModel>>():
        if (mounted) {
          setState(() => _items.clear());
          setState(() => _items.addAll(result.value));
          showMessage('get_data_success'.tr());
        }
      case Error():
        return showErrorSnakeBar(result.error.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<AppSettings>(settingsProvider, (prev, next) {
      final id = next.deviceId;
      if (!_loaded && id != null && id.isNotEmpty) {
        _loaded = true;
        getRecentData();
      }
    });
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    const outerRadius = 16.0;
    const innerRadius = 4.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          ElevatedButton(onPressed: () => getRecentData(), child: Text('Refresh')),
          for (var i = 0; i < _items.length; i++)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(i == 0 ? outerRadius : innerRadius),
                  bottom: Radius.circular(i == _items.length - 1 ? outerRadius : innerRadius),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  spacing: 4,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            spacing: 4,
                            children: [
                              Icon(LucideIcons.dot, color: _items[i].wearStatus ? Colors.green : Colors.red, size: 40),
                              Text(_items[i].createdAt.toString(), style: tt.titleSmall?.copyWith(color: Colors.grey)),
                            ],
                          ),
                          Row(
                            spacing: 4,
                            children: [
                              Chip(avatar: Icon(LucideIcons.moveVertical), label: Text(_items[i].pitch.toString())),
                              Chip(avatar: Icon(LucideIcons.moveHorizontal), label: Text(_items[i].roll.toString())),
                              Chip(
                                avatar: const Icon(LucideIcons.mapPin),
                                label: Text(
                                  '${_items[i].latitude?.toStringAsFixed(2)} ${_items[i].longitude?.toStringAsFixed(2)}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      ((_items[i].pressure ?? 0) / 5).toStringAsFixed(0),
                      style: tt.displaySmall?.copyWith(
                        fontFamily: 'Oxanium',
                        color: Colors.grey,
                        fontVariations: [FontVariation('wght', 500)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
