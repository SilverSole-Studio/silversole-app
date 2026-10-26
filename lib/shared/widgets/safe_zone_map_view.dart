import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The map itself: the device's position, a safe-zone ring around it, and
/// zoom / locate controls.
///
/// Shared by both themes — only the frame around it and the control styling
/// differ, which the caller supplies. Keeping one map widget means the camera,
/// permission and geolocation logic exist once.
///
/// There is no safe-zone feature yet, so no caller passes [safeRadiusMeters]
/// and no ring is drawn; the parameter stays for when one exists.
class SafeZoneMapView extends StatefulWidget {
  const SafeZoneMapView({
    super.key,
    required this.center,
    this.showDevice = true,
    this.safeRadiusMeters,
    this.markerIcon,
    this.outlinedControls = false,
    this.zoneColor,
  });

  /// Where the device was last seen.
  final LatLng center;

  /// Whether [center] is a real device position. False when the device has
  /// never reported one and [center] is only a fallback camera target — then
  /// no marker is drawn, so the map never shows a made-up position.
  final bool showDevice;

  /// Radius of a safe-zone ring around [center], or null for none.
  final double? safeRadiusMeters;

  /// Marker bitmap; falls back to the platform default pin when null.
  final BitmapDescriptor? markerIcon;

  /// Draw the hard dark border the mascot theme uses on its controls.
  final bool outlinedControls;

  /// Ring stroke/fill color; defaults to the theme's primary.
  final Color? zoneColor;

  @override
  State<SafeZoneMapView> createState() => _SafeZoneMapViewState();
}

class _SafeZoneMapViewState extends State<SafeZoneMapView> {
  GoogleMapController? _controller;
  String? _darkStyle;

  @override
  void initState() {
    super.initState();
    _loadDarkStyle();
  }

  Future<void> _loadDarkStyle() async {
    final style = await rootBundle.loadString(
      'assets/map_styles/map_style_dark.json',
    );
    if (!mounted) return;
    setState(() => _darkStyle = style);
  }

  @override
  void didUpdateWidget(covariant SafeZoneMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recenter when a newer position arrives.
    if (oldWidget.center != widget.center) {
      _controller?.animateCamera(CameraUpdate.newLatLng(widget.center));
    }
  }

  Future<void> _zoomBy(double delta) async {
    await _controller?.animateCamera(
      delta > 0 ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
    );
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zone = widget.zoneColor ?? cs.primary;

    return Stack(
      children: [
        GoogleMap(
          style: isDark ? _darkStyle : null,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          initialCameraPosition: CameraPosition(
            target: widget.center,
            zoom: 15,
          ),
          onMapCreated: (c) => _controller = c,
          markers: {
            if (widget.showDevice)
              Marker(
                markerId: const MarkerId('device'),
                position: widget.center,
                icon: widget.markerIcon ?? BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
              ),
          },
          circles: {
            if (widget.showDevice && widget.safeRadiusMeters != null)
              Circle(
                circleId: const CircleId('safe_zone'),
                center: widget.center,
                radius: widget.safeRadiusMeters!,
                strokeWidth: 3,
                strokeColor: zone,
                fillColor: zone.withValues(alpha: 0.10),
              ),
          },
          // Let the map win the pan gesture inside a scrolling page.
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _MapControl(
                icon: LucideIcons.plus,
                outlined: widget.outlinedControls,
                onTap: () => _zoomBy(1),
              ),
              const SizedBox(height: 10),
              _MapControl(
                icon: LucideIcons.minus,
                outlined: widget.outlinedControls,
                onTap: () => _zoomBy(-1),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: _MapControl(
            icon: LucideIcons.locateFixed,
            outlined: widget.outlinedControls,
            onTap: _goToMyLocation,
          ),
        ),
      ],
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.onTap,
    required this.outlined,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: CircleBorder(
        side: outlined
            ? BorderSide(color: cs.outline, width: 2.5)
            : BorderSide.none,
      ),
      elevation: outlined ? 0 : 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: cs.onSurface),
        ),
      ),
    );
  }
}
