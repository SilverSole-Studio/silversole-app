import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Shortest side (logical pixels) from which a screen counts as a tablet.
/// Same threshold Android uses for `sw600dp`.
const double kTabletShortestSide = 600;

/// True when the *physical screen* (not the app window) is tablet-sized.
///
/// The display is measured on purpose: with Stage Manager or split view the
/// app window can be narrower than 600 and would otherwise flip an iPad back
/// to the phone rule.
bool isTabletDisplay([ui.FlutterView? view]) {
  view ??= ui.PlatformDispatcher.instance.implicitView;
  if (view == null) return false;
  final display = view.display;
  final shortest = display.size.shortestSide / display.devicePixelRatio;
  return shortest >= kTabletShortestSide;
}

/// Orientations this device may rotate to: all four on tablets, portrait only
/// on phones.
List<DeviceOrientation> defaultOrientationsFor({required bool tablet}) => tablet
    ? const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]
    : const [DeviceOrientation.portraitUp];

/// Applies the device's default orientations. Call at start-up and whenever a
/// page that temporarily changed the orientation (e.g. the 銀足樂齡 class page
/// allowing landscape on phones) goes away — never hard-code `portraitUp`
/// there, or an iPad gets locked back to portrait.
Future<void> restoreDefaultOrientations() =>
    SystemChrome.setPreferredOrientations(
      defaultOrientationsFor(tablet: isTabletDisplay()),
    );
