import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/relative_time.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/pages/map_page.dart'
    show kMapFallbackCenter;
import 'package:silversole/shared/providers/device_location_provider.dart';
import 'package:silversole/shared/widgets/safe_zone_map_view.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Map tab, mascot theme. Same data as [MapPage] — and, like it, no safe zone
/// until that feature exists — only the framing, copy and art differ.
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
                    showDevice: location != null,
                    markerIcon: _mascotMarker,
                    outlinedControls: true,
                    zoneColor: AppPaletteT2.safe,
                  ),
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
