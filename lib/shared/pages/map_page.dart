import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/relative_time.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/providers/device_location_provider.dart';
import 'package:silversole/shared/widgets/safe_zone_map_view.dart';

/// Fallback camera target when the device has never reported a position.
const kMapFallbackCenter = LatLng(25.0330, 121.5654);

/// Map tab, classic theme: where the device was last seen.
///
/// No safe zone: there is no safe-zone feature yet, so the page draws no ring,
/// claims no "in the safe zone" status and offers no setup button.
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
                    showDevice: location.value != null,
                  ),
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
