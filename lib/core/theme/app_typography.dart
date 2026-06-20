import 'package:flutter/material.dart';

/// App typography. Every [TextTheme] slot carries its size + weight (per
/// DESIGN.md §3), so widgets use `context.textTheme.titleMedium` etc. directly —
/// no more `.copyWith(fontWeight: ...)` chains.
///
/// Text renders in [fontFamily] — Google Sans, bundled as a variable font
/// (assets/fonts, declared in pubspec.yaml under `fonts:`). Latin glyphs +
/// digits use Google Sans; scripts it doesn't cover (e.g. Chinese) fall back
/// to the platform system font automatically. Weight is carried by
/// [FontWeight] via the font's `wght` axis.
abstract final class AppTypography {
  /// The bundled app font family. Must match the `family:` in pubspec.yaml.
  static const String fontFamily = 'Google Sans';

  static FontWeight _fw(int wght) {
    if (wght >= 800) return FontWeight.w800;
    if (wght >= 700) return FontWeight.w700;
    if (wght >= 600) return FontWeight.w600;
    if (wght >= 500) return FontWeight.w500;
    return FontWeight.w400;
  }

  static TextStyle _s(double size, int wght, {double height = 1.25}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height,
      fontWeight: _fw(wght),
    );
  }

  /// Base (uncolored) text theme. Colors are applied in `app_theme.dart` via
  /// `.apply(bodyColor:, displayColor:)` so they track the brightness.
  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: _s(36, 800, height: 1.1),
      displayMedium: _s(32, 800, height: 1.12),
      displaySmall: _s(28, 800, height: 1.15),
      headlineLarge: _s(28, 700, height: 1.15),
      headlineMedium: _s(26, 700, height: 1.18),
      headlineSmall: _s(24, 700, height: 1.2),
      titleLarge: _s(20, 700),
      titleMedium: _s(16, 700),
      titleSmall: _s(14, 600),
      bodyLarge: _s(16, 500, height: 1.4),
      bodyMedium: _s(15, 400, height: 1.4),
      bodySmall: _s(13, 400, height: 1.35),
      labelLarge: _s(14, 600),
      labelMedium: _s(12, 500),
      labelSmall: _s(11, 500),
    );
  }
}
