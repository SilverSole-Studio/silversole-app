import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette_skins.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/core/theme/app_typography.dart';

/// Which look is active, plus the few things that differ between looks and do
/// not fit a [ColorScheme] or [TextTheme]: how a number is drawn, how a card
/// is lifted off the page.
///
/// Registered on every theme's `extensions`; read it with `context.look`.
@immutable
class AppLook extends ThemeExtension<AppLook> {
  const AppLook(this.variant);

  final AppThemeVariant variant;

  /// A hero figure (a count, a percentage, minutes). Every look draws these big;
  /// this is the one place that says in which face and weight.
  TextStyle number(double size, {Color? color, double? height}) {
    switch (variant) {
      case AppThemeVariant.mascot:
        return TextStyle(
          fontFamily: AppTypography.mascotFontFamily,
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: height ?? 1,
          letterSpacing: -size * 0.02,
          color: color,
        );
      case AppThemeVariant.dashboard:
        return TextStyle(
          fontFamily: AppPaletteB.numberFamily,
          fontSize: size * 1.08,
          fontWeight: FontWeight.w900,
          height: height ?? 0.9,
          color: color,
        );
      case AppThemeVariant.journal:
        return TextStyle(
          fontFamily: AppPaletteC.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: height ?? 1,
          letterSpacing: -size * 0.02,
          color: color,
        );
      case AppThemeVariant.techLight:
      case AppThemeVariant.techDark:
        return TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: size,
          fontWeight: FontWeight.w800,
          height: height ?? 1,
          letterSpacing: -size * 0.02,
          color: color,
        );
    }
  }

  @override
  AppLook copyWith({AppThemeVariant? variant}) =>
      AppLook(variant ?? this.variant);

  @override
  AppLook lerp(ThemeExtension<AppLook>? other, double t) =>
      other is AppLook && t >= 0.5 ? other : this;
}

extension AppLookContext on BuildContext {
  /// The active look; 極簡科技・白 when a bare `ThemeData` (a test) has none.
  AppLook get look =>
      Theme.of(this).extension<AppLook>() ??
      const AppLook(AppThemeVariant.techLight);

  AppThemeVariant get variant => look.variant;
}
