import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/pages/device_connect_bottom_modal.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/device_carousel.dart';
import 'package:silversole/shared/widgets/home_device_status_section.dart';
import 'package:silversole/shared/widgets/recent_data_chart_card.dart';
import 'package:silversole/shared/widgets/warning_card.dart';

class HomeBody extends ConsumerStatefulWidget {
  const HomeBody({super.key});

  @override
  ConsumerState<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<HomeBody> {
  Widget notActiveBody() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final safePadding = MediaQuery.paddingOf(context).vertical;
    final bodyHeight = (screenHeight - safePadding - 220).clamp(
      220.0,
      screenHeight,
    );
    return SizedBox(
      height: bodyHeight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpacing.base,
          children: [
            SvgPicture.asset('assets/images/undraw_void_wez2.svg', width: 300),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'no_primary_device_title'.tr(),
              style: context.textTheme.titleLarge,
            ),
            Text(
              'no_primary_device_body'.tr(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget activeBody(BlePairedDevice device) {
    return Column(
      spacing: AppSpacing.base,
      children: [
        const DeviceCarousel(),
        HomeDeviceStatusSection(device: device),
        WarningCard(key: ValueKey(device.remoteId)),
        RecentDataChartCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final preferredDevice = settings.preferredDevice;

    return Scaffold(
      // With no primary device the FAB becomes an "add device" action that
      // opens the BLE pairing modal; otherwise it's the "Mission" placeholder.
      floatingActionButton: preferredDevice == null
          ? FloatingActionButton(
              heroTag: 'fab_home_add_device',
              onPressed: () => showDeviceConnectBottomModal(context),
              tooltip: 'add_device'.tr(),
              child: const Icon(LucideIcons.plus),
            )
          : FloatingActionButton(
              heroTag: 'fab_home_mission',
              onPressed: comingSoon,
              tooltip: 'mission'.tr(),
              child: const Icon(LucideIcons.target),
            ),
      body: Stack(
        children: [
          // Regional hero gradient: tints the top ~25–45% of the screen and
          // fades downward to enrich the page color (DESIGN.md hero accent).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.45,
                decoration: BoxDecoration(
                  // Gentle diagonal multi-hue wash (brand blue → tertiary
                  // accent → cyan) that fades to transparent above the
                  // container's lower edge, so there's no hard cut on the left.
                  gradient: LinearGradient(
                    begin: const Alignment(-0.3, -1.0),
                    end: const Alignment(0.3, 1.0),
                    colors: [
                      context.tokens.brandGradient.first.withValues(
                        alpha: 0.30,
                      ),
                      context.colorScheme.tertiary.withValues(alpha: 0.18),
                      context.tokens.brandGradient.last.withValues(alpha: 0.10),
                      context.tokens.brandGradient.last.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.32, 0.55, 0.82],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {},
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.xxl,
                  AppSpacing.base,
                  AppSpacing.base,
                ),
                child: Column(
                  spacing: AppSpacing.base,
                  children: [
                    Row(
                      spacing: AppSpacing.base,
                      children: [
                        Text(
                          'welcome_back'.tr(),
                          style: context.textTheme.displaySmall,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: comingSoon,
                          icon: Icon(LucideIcons.bell),
                        ),
                      ],
                    ),
                    if (preferredDevice != null)
                      activeBody(preferredDevice)
                    else
                      notActiveBody(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
