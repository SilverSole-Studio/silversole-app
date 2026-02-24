import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/device_status_detail_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/device_status_card.dart';
import 'package:silversole/shared/widgets/map_card.dart';
import 'package:silversole/shared/widgets/recent_data_chart_card.dart';
import 'package:silversole/shared/widgets/status_card.dart';
import 'package:silversole/shared/widgets/warning_card.dart';

class HomeBody extends ConsumerStatefulWidget {
  const HomeBody({super.key});

  @override
  ConsumerState<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<HomeBody> {
  Widget notActiveBody() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safePadding = MediaQuery.paddingOf(context).vertical;
    final bodyHeight = (screenHeight - safePadding - 220).clamp(220.0, screenHeight);
    return SizedBox(
      height: bodyHeight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            SvgPicture.asset('assets/images/undraw_void_wez2.svg', width: 300),
            const SizedBox(height: 32),
            Text('no_primary_device_title'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              'no_primary_device_body'.tr(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget activeBody(BlePairedDevice device, DeviceStatusDetailModel detail) {
    return Column(
      spacing: 16,
      children: [
        DeviceStatusCard(
          name: device.name,
          type: StatusCardType.statusDisplay,
          model: device.displayModel ?? 'unknown_model'.tr(),
          id: device.remoteId,
          activeDisplay: true,
          detail: detail,
        ),
        MapCard(),
        WarningCard(),
        RecentDataChartCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final preferredDevice = settings.preferredDevice;
    final viewProvider = ref.watch(telemetryViewProvider);
    final lastest = viewProvider.recent.isNotEmpty ? viewProvider.recent.last : null;
    final detail = DeviceStatusDetailModel(
      lastHeartbeatAt: viewProvider.updatedAt,
      lastBatteryAt: viewProvider.updatedAt,
      lastBatteryPercent: lastest?.batteryPercent,
      isCharging: lastest?.isCharging,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              spacing: 16,
              children: [
                Row(
                  spacing: 16,
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(LucideIcons.user, color: cs.onPrimaryContainer),
                    ),
                    Text(
                      'SilverSole',
                      style: tt.titleLarge?.copyWith(
                        fontFamily: 'oxanium',
                        fontVariations: [FontVariation('wght', 700)],
                      ),
                    ),
                    Expanded(child: const SizedBox()),
                    IconButton(onPressed: comingSoon, icon: Icon(LucideIcons.bell)),
                  ],
                ),
                if (preferredDevice != null) activeBody(preferredDevice, detail) else notActiveBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
