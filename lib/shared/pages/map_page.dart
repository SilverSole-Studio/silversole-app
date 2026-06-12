import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Full-screen map tab. For now this is just a full-bleed Google Map with a
/// "locate me" control. Light mode uses Google Maps' default (colorful) style;
/// dark mode uses the custom dark JSON.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  String? _darkStyle;
  GoogleMapController? _controller;
  bool _hasLocationPermission = false;

  static const LatLng _initialCenter = LatLng(25.0330, 121.5654);

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _checkPermission();
  }

  Future<void> _loadStyle() async {
    final dark = await rootBundle.loadString(
      'assets/map_styles/map_style_dark.json',
    );
    if (!mounted) return;
    setState(() => _darkStyle = dark);
  }

  Future<void> _checkPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    setState(() {
      _hasLocationPermission = status.isGranted || status.isLimited;
    });
  }

  Future<void> _goToMyLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(accuracy: LocationAccuracy.high);
    } else if (Platform.isIOS || Platform.isMacOS) {
      settings = AppleSettings(accuracy: LocationAccuracy.high);
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.high);
    }

    final pos = await Geolocator.getCurrentPosition(locationSettings: settings);
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            style: isDark ? _darkStyle : null,
            zoomControlsEnabled: false,
            initialCameraPosition: const CameraPosition(
              target: _initialCenter,
              zoom: 14,
            ),
            onMapCreated: (c) => _controller = c,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
          if (_hasLocationPermission)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: FloatingActionButton.small(
                    heroTag: 'fab_map_page',
                    backgroundColor: context.cs.surfaceContainer,
                    onPressed: _goToMyLocation,
                    child: const Icon(LucideIcons.locateFixed),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
