import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/models/device_location_model.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/sole_provider.dart';

import '../../core/error/result.dart';

class MapCard extends ConsumerStatefulWidget {
  const MapCard({super.key});

  @override
  ConsumerState<MapCard> createState() => _MapCardState();
}

class _MapCardState extends ConsumerState<MapCard> {
  String? lightStyle;
  String? darkStyle;

  final _marker = <Marker>{};
  final _polyline = <Polyline>{};
  GoogleMapController? _controller;
  LatLng initialCenter = LatLng(25.0330, 121.5654);
  final _zoom = 14.0;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _checkLocationPermission();
  }

  Future<void> _loadStyle() async {
    final dark = await rootBundle.loadString('assets/map_styles/map_style_dark.json');
    final light = await rootBundle.loadString('assets/map_styles/map_style_light.json');
    if (!mounted) return;
    setState(() {
      lightStyle = light;
      darkStyle = dark;
    });
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    setState(() {
      _hasLocationPermission = status.isGranted || status.isLimited;
    });
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double? minLat, maxLat, minLng, maxLng;

    for (final p in list) {
      minLat = minLat == null ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = maxLat == null ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = minLng == null ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = maxLng == null ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }

    return LatLngBounds(southwest: LatLng(minLat!, minLng!), northeast: LatLng(maxLat!, maxLng!));
  }

  Future<void> _fitAll(List<LatLng> points) async {
    if (points.isEmpty) return;
    if (points.length == 1) {
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
      return;
    }
    final bounds = _boundsFromLatLngList(points);
    await _controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  // void _drawLine(LatLng a, LatLng b) {
  //   setState(() {
  //     _polyline.add(
  //       Polyline(
  //         polylineId: const PolylineId('ab'),
  //         color: Colors.redAccent,
  //         width: 4,
  //         points: [a, b],
  //         endCap: Cap.roundCap,
  //       ),
  //     );
  //   });
  // }

  Future<Position?> _getPhoneLocation() async {
    final serviceEnable = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnable) {
      showErrorSnakeBar('get_phone_location_service_failed'.tr());
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      showErrorSnakeBar('get_phone_location_permission_failed'.tr());
      return null;
    }

    LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
    } else if (Platform.isIOS || Platform.isMacOS) {
      settings = AppleSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
    }

    return Geolocator.getCurrentPosition(locationSettings: settings);
  }

  Future<void> controlMapWithPhonePosition() async {
    final position = await _getPhoneLocation();
    if (position == null) return;
    final latLng = LatLng(position.latitude, position.longitude);
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
  }

  Future<void> refreshMapAndResetCenter() async {
    final settings = ref.read(settingsProvider);
    final service = ref.read(soleProvider);
    final deviceId = settings.deviceId;
    final result = await service.getRecentDeviceLocation(deviceId: deviceId);
    switch (result) {
      case Ok<List<DeviceLocationModel>>():
        final points = result.value.map((it) => LatLng(it.lat, it.lng)).toList();
        _fitAll(points);
        if (!mounted) return;
        setState(() {
          _marker.clear();
          final locations = result.value.map(
            (it) => Marker(markerId: MarkerId(it.id.toString()), position: LatLng(it.lat, it.lng)),
          );
          _marker.addAll(locations);
        });
        showMessage('refresh_map_success'.tr());
      case Error():
        showErrorSnakeBar(result.error.toString());
    }
  }

  Widget googleMap(String? style) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GoogleMap(
              style: style,
              markers: _marker,
              polylines: _polyline,
              zoomControlsEnabled: false,
              // myLocationButtonEnabled: _hasLocationPermission,
              // myLocationEnabled: _hasLocationPermission,
              initialCameraPosition: CameraPosition(target: initialCenter, zoom: _zoom),
              onMapCreated: (c) => _controller = c,
              gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
            ),
          ),
          if (_hasLocationPermission)
            Positioned(
              right: 4,
              top: 4,
              child: FloatingActionButton.small(
                heroTag: 'fab_map_card',
                backgroundColor: cs.surfaceContainer,
                onPressed: controlMapWithPhonePosition,
                child: const Icon(LucideIcons.locateFixed),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = isDark ? darkStyle : lightStyle;

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: refreshMapAndResetCenter,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            // child: settings.deviceId != null ? googleMap(style) : hintBindingPage(),
            child: googleMap(style),
          ),
        ),
      ),
    );
  }
}
