import 'package:flutter/material.dart';

/// The five type sizes of the app, shared by both themes (the themes differ
/// only in font family and ink color, never in the scale).
///
/// Nothing is smaller than [label] (14): with 「標準」 text size the app scales
/// text by 0.9, so 14 renders at about 12.6 — the floor for anything a person
/// has to read, navigation labels included.
abstract final class AppType {
  /// Big numbers and hero figures.
  static const double display = 36;

  /// Page titles.
  static const double headline = 28;

  /// Section titles, card titles.
  static const double title = 20;

  /// Body text and button labels.
  static const double body = 16;

  /// Secondary text, captions, navigation labels.
  static const double label = 14;
}

/// App typography. Every [TextTheme] slot carries its size + weight, so widgets
/// use `context.textTheme.titleMedium` etc. directly — no `.copyWith`
/// size/weight chains.
///
/// Slot → size: display* 36/36/28, headline* 28/20/20, title* 20/16/14,
/// body* 16/14/14, label* 16/14/14.
abstract final class AppTypography {
  /// Latin family of the classic theme (bundled variable font, pubspec.yaml).
  /// Scripts it doesn't cover (Chinese) fall back to the system font.
  static const String fontFamily = 'Google Sans';

  /// Latin family of the mascot theme (ships with the mascot art pack).
  static const String mascotFontFamily = 'DM Sans';

  static FontWeight _fw(int wght) {
    if (wght >= 800) return FontWeight.w800;
    if (wght >= 700) return FontWeight.w700;
    if (wght >= 600) return FontWeight.w600;
    if (wght >= 500) return FontWeight.w500;
    return FontWeight.w400;
  }

  static TextStyle _s(
    String family,
    double size,
    int wght, {
    double height = 1.25,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height,
      fontWeight: _fw(wght),
    );
  }

  /// Base (uncolored) text theme. Colors are applied by the theme builder via
  /// `.apply(bodyColor:, displayColor:)` so they track the brightness.
  static TextTheme textTheme({String family = fontFamily}) {
    return TextTheme(
      displayLarge: _s(family, AppType.display, 800, height: 1.1),
      displayMedium: _s(family, AppType.display, 800, height: 1.1),
      displaySmall: _s(family, AppType.headline, 800, height: 1.15),
      headlineLarge: _s(family, AppType.headline, 800, height: 1.15),
      headlineMedium: _s(family, AppType.title, 800, height: 1.2),
      headlineSmall: _s(family, AppType.title, 700, height: 1.2),
      titleLarge: _s(family, AppType.title, 700),
      titleMedium: _s(family, AppType.body, 700),
      titleSmall: _s(family, AppType.label, 700),
      bodyLarge: _s(family, AppType.body, 500, height: 1.4),
      bodyMedium: _s(family, AppType.label, 500, height: 1.4),
      bodySmall: _s(family, AppType.label, 400, height: 1.35),
      labelLarge: _s(family, AppType.body, 700),
      labelMedium: _s(family, AppType.label, 600),
      labelSmall: _s(family, AppType.label, 600),
    );
  }
}
