import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:silversole/shared/widgets/safe_zone_map_view.dart';

/// The wearer's own position is drawn by the map's built-in blue dot, which
/// only shows when `myLocationEnabled` is on. Before this, it never was: the
/// locate button moved the camera to the wearer but nothing marked the spot.
Future<GoogleMap> _pumpMap(
  WidgetTester tester,
  LocationPermission permission,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: SafeZoneMapView(
            center: const LatLng(25.0330, 121.5654),
            showDevice: false,
            checkLocationPermission: () async => permission,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<GoogleMap>(find.byType(GoogleMap));
}

/// Off Android/iOS the maps plugin renders a placeholder instead of a platform
/// view, so the GoogleMap widget can be inspected in a unit test.
final _offDevice = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  testWidgets(
    'shows the wearer\'s own position once location is allowed',
    (tester) async {
      final map = await _pumpMap(tester, LocationPermission.whileInUse);
      expect(map.myLocationEnabled, isTrue);
      // The map's own locate button stays off: the page has its own control.
      expect(map.myLocationButtonEnabled, isFalse);
    },
    variant: _offDevice,
  );

  testWidgets('also when location is always allowed', (tester) async {
    final map = await _pumpMap(tester, LocationPermission.always);
    expect(map.myLocationEnabled, isTrue);
  }, variant: _offDevice);

  testWidgets('no blue dot while location is not allowed', (tester) async {
    final denied = await _pumpMap(tester, LocationPermission.denied);
    expect(denied.myLocationEnabled, isFalse);
  }, variant: _offDevice);

  testWidgets('no blue dot when location is denied for good', (tester) async {
    final map = await _pumpMap(tester, LocationPermission.deniedForever);
    expect(map.myLocationEnabled, isFalse);
  }, variant: _offDevice);
}
