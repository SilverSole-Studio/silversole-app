import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';

import '../../core/error/error_logger.dart';

class DevicesPage extends ConsumerStatefulWidget {
  const DevicesPage({super.key});

  @override
  ConsumerState<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends ConsumerState<DevicesPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('devices'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: comingSoon,
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
                  leading: Container(margin: EdgeInsets.only(left: 8), child: Icon(LucideIcons.search, color: cs.onSurfaceVariant,)),
                  hintText: 'search_device'.tr(),
                ),
                const SizedBox(height: 16),
                Text('current_devices'.tr(), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),),
                DeviceStatusCard()
              ],
            ),
          ),
        ),
      ),
    );
  }
}
