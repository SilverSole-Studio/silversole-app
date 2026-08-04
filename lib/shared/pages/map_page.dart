import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/relative_time.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/providers/device_location_provider.dart';
import 'package:silversole/shared/widgets/safe_zone_map_view.dart';

/// Fallback camera target when the device has never reported a position.
const kMapFallbackCenter = LatLng(25.0330, 121.5654);

/// Demo safe-zone radius, in meters. Front-end only — not configurable and not
/// evaluated against the device's position yet.
const kDemoSafeRadius = 300.0;

/// Map tab, classic theme: where the device was last seen, a demo safe-zone
/// ring, and the (not yet implemented) safe-zone setup entry.
class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(latestDeviceLocationProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.base,
            children: [
              Text('map'.tr(), style: context.textTheme.headlineMedium),
              Text(
                _subtitle(location.value),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              ClipRRect(
                borderRadius: AppRadius.cardR,
                child: SizedBox(
                  height: 380,
                  child: SafeZoneMapView(
                    center: _centerOf(location.value),
                    safeRadiusMeters: kDemoSafeRadius,
                  ),
                ),
              ),
              const _SafeZoneStatusCard(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: comingSoon,
                  icon: const Icon(LucideIcons.mapPin),
                  label: Text('set_safe_zone'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _subtitle(DeviceLocationModel? location) => location == null
    ? 'no_location_yet'.tr()
    : 'last_located'.tr(args: [formatTimeAgo(location.receivedAt)]);

LatLng _centerOf(DeviceLocationModel? location) =>
    location == null ? kMapFallbackCenter : LatLng(location.lat, location.lng);

class _SafeZoneStatusCard extends StatelessWidget {
  const _SafeZoneStatusCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            spacing: AppSpacing.base,
            children: [
              Icon(
                LucideIcons.shieldCheck,
                color: context.tokens.success,
                size: 32,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'in_safe_zone'.tr(),
                      style: context.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'safe_zone_hint'.tr(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
