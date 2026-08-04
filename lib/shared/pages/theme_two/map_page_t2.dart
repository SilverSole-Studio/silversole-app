import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/relative_time.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/pages/map_page.dart'
    show kDemoSafeRadius, kMapFallbackCenter;
import 'package:silversole/shared/providers/device_location_provider.dart';
import 'package:silversole/shared/widgets/safe_zone_map_view.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Map tab, mascot theme. Same data and same demo safe zone as [MapPage] —
/// only the framing, copy and art differ.
class MapPageT2 extends ConsumerStatefulWidget {
  const MapPageT2({super.key});

  @override
  ConsumerState<MapPageT2> createState() => _MapPageT2State();
}

class _MapPageT2State extends ConsumerState<MapPageT2> {
  BitmapDescriptor? _mascotMarker;

  @override
  void initState() {
    super.initState();
    _loadMarker();
  }

  /// The mascot doubles as the map pin here. Loaded once; until it resolves
  /// the map falls back to the default marker rather than showing nothing.
  Future<void> _loadMarker() async {
    final icon = await AssetMapBitmap.create(
      const ImageConfiguration(size: Size(52, 52)),
      'assets/mascot-assets/happy.webp',
    );
    if (!mounted) return;
    setState(() => _mascotMarker = icon);
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(latestDeviceLocationProvider).value;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Text(
                'mascot_where_title'.tr(),
                style: context.textTheme.headlineLarge,
              ),
              Text(
                location == null
                    ? 'no_location_yet'.tr()
                    : 'last_located'.tr(
                        args: [formatTimeAgo(location.receivedAt)],
                      ),
                style: context.textTheme.bodyMedium,
              ),
              MascotCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 380,
                  child: SafeZoneMapView(
                    center: _center(location),
                    safeRadiusMeters: kDemoSafeRadius,
                    markerIcon: _mascotMarker,
                    outlinedControls: true,
                    zoneColor: AppPaletteT2.safe,
                  ),
                ),
              ),
              MascotCard(
                child: Row(
                  children: [
                    Image.asset('assets/mascot-assets/happy.webp', height: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'in_safe_zone'.tr(),
                            style: context.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'safe_zone_hint'.tr(),
                            style: context.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

  LatLng _center(DeviceLocationModel? location) => location == null
      ? kMapFallbackCenter
      : LatLng(location.lat, location.lng);
}
