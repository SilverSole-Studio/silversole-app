import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_look.dart';
import 'package:silversole/core/theme/app_palette.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/core/theme/app_theme_base.dart';
import 'package:silversole/core/theme/app_tokens.dart';
import 'package:silversole/core/theme/app_typography.dart';

/// Builds the app [ThemeData] for a given [brightness].
///
/// Color model:
///  * [AppPalette.brandSeed] is pinned as `primary` (exact brand blue, both
///    modes); secondary/tertiary/containers still derive from it via fromSeed.
///  * All neutral surfaces/outlines are locked to a grayscale ramp via the
///    monochrome scheme variant, so the body stays white/gray for any accent.
///  * Light surface is #FCFCFC (off-white, not pure white). No elevation tint.
///
/// This file only chooses the classic *colors*; the type scale, radii, card and
/// button shapes come from [buildAppThemeData], shared with the mascot theme.
ThemeData appTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final accents = ColorScheme.fromSeed(
    seedColor: AppPalette.brandSeed,
    brightness: brightness,
  );
  // Monochrome variant is the only one with a zero-cast grayscale ramp.
  final neutrals = ColorScheme.fromSeed(
    seedColor: AppPalette.brandSeed,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
    brightness: brightness,
  );
  final scheme = accents.copyWith(
    // Pin the main action color to the exact brand blue in BOTH modes (M3
    // would otherwise desaturate it in light and lighten it in dark). White
    // foreground keeps AA contrast on it.
    primary: AppPalette.brandSeed,
    onPrimary: Colors.white,
    surface: isLight ? const Color(0xFFFCFCFC) : neutrals.surface,
    onSurface: neutrals.onSurface,
    onSurfaceVariant: neutrals.onSurfaceVariant,
    surfaceDim: neutrals.surfaceDim,
    surfaceBright: neutrals.surfaceBright,
    surfaceContainerLowest: neutrals.surfaceContainerLowest,
    surfaceContainerLow: neutrals.surfaceContainerLow,
    surfaceContainer: neutrals.surfaceContainer,
    surfaceContainerHigh: neutrals.surfaceContainerHigh,
    surfaceContainerHighest: neutrals.surfaceContainerHighest,
    outline: neutrals.outline,
    outlineVariant: neutrals.outlineVariant,
    inverseSurface: neutrals.inverseSurface,
    onInverseSurface: neutrals.onInverseSurface,
    // No accent-colored elevation tint on raised surfaces.
    surfaceTint: Colors.transparent,
  );

  final cardHairline = BorderSide(
    color: scheme.outlineVariant.withValues(alpha: isLight ? 0.9 : 0.5),
  );

  return buildAppThemeData(
    AppSkin(
      scheme: scheme,
      fontFamily: AppTypography.fontFamily,
      // Page body is a soft light gray in light mode (AppPalette.pageLight)
      // so pure-white cards float above it; dark keeps the deep body.
      scaffoldColor: isLight ? AppPalette.pageLight : scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        AppTokens.of(brightness),
        AppLook(
          isLight ? AppThemeVariant.techLight : AppThemeVariant.techDark,
        ),
      ],
      cardColor: isLight ? Colors.white : scheme.surfaceContainerLow,
      cardSide: cardHairline,
      cardElevation: isLight ? 0.5 : 0,
      cardShadowColor: isLight
          ? Colors.black.withValues(alpha: 0.05)
          : Colors.transparent,
      sheetColor: scheme.surface,
      secondaryFill: scheme.surfaceContainerHigh,
      // Navigation: the selected tab gets a tinted indicator (not just a
      // color change) so the current place is obvious.
      navColor: scheme.surface,
      navIndicatorColor: scheme.primary.withValues(alpha: 0.14),
      navSelectedColor: scheme.primary,
      navSelectedLabelColor: scheme.primary,
      navUnselectedColor: scheme.onSurfaceVariant,
      chipSelectedColor: scheme.inverseSurface,
    ),
  );
}
