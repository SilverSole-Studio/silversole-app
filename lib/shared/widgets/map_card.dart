import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:silversole/shared/providers/settings_provider.dart';

class MapCard extends ConsumerStatefulWidget {
  const MapCard({super.key});

  @override
  ConsumerState<MapCard> createState() => _MapCardState();
}

class _MapCardState extends ConsumerState<MapCard> {
  String? lightStyle;
  String? darkStyle;

  @override
  void initState() {
    super.initState();
    _loadStyle();
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

  final LatLng initialCenter = LatLng(25.0330, 121.5654);
  var zoom = 14.0;

  Widget googleMap(String? style) {
    return GoogleMap(
      style: style,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(target: initialCenter, zoom: zoom),
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
    );
  }

  Widget hintBindingPage() {
    final colorScheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(LucideIcons.link2, color: colorScheme.onPrimaryContainer, size: 28),
          ),
          Text('not_binding'.tr(), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(
            'map_binding_required'.tr(),
            style: tt.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = isDark ? darkStyle : lightStyle;
    final settings = ref.watch(settingsProvider);

    return SizedBox(
      width: double.infinity,
      height: 300,
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: (settings.deviceId != null) ? googleMap(style) : hintBindingPage(),
        ),
      ),
    );
  }
}
