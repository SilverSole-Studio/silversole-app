import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/theme/app_theme_base.dart';
import 'package:silversole/core/theme/app_tokens.dart';
import 'package:silversole/core/theme/app_typography.dart';

/// Builds the [ThemeData] for the illustrated "mascot" theme (theme two).
///
/// Same type scale, radii, card and button shapes as the classic theme (see
/// [buildAppThemeData]); what is its own is the warm canvas, gold as a large
/// fill, DM Sans, and a hard outline drawn on every card. Light and dark both
/// exist: [MascotColors] carries the values for each brightness.
ThemeData appThemeT2(Brightness brightness) {
  final c = MascotColors.of(brightness);
  final outline = BorderSide(color: c.line, width: AppPaletteT2.outlineWidth);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppPaletteT2.gold,
        brightness: brightness,
      ).copyWith(
        primary: c.gold,
        onPrimary: c.onGold,
        secondary: c.goldDeep,
        onSecondary: c.onGold,
        surface: c.card,
        onSurface: c.ink,
        onSurfaceVariant: c.inkMuted,
        surfaceContainerLowest: c.canvas,
        surfaceContainerLow: c.cardWarm,
        surfaceContainer: c.cardWarm,
        surfaceContainerHigh: c.cardWarm,
        surfaceContainerHighest: c.cardWarm,
        inverseSurface: c.ink,
        onInverseSurface: c.canvas,
        outline: c.line,
        outlineVariant: c.line,
        error: c.danger,
        surfaceTint: Colors.transparent,
      );

  return buildAppThemeData(
    AppSkin(
      scheme: scheme,
      fontFamily: AppTypography.mascotFontFamily,
      scaffoldColor: c.canvas,
      // Reuse the functional accents; this theme overrides what it needs.
      extensions: <ThemeExtension<dynamic>>[AppTokens.of(brightness), c],
      // The outline, not a shadow, is what reads as "card" in this theme.
      cardColor: c.card,
      cardSide: outline,
      sheetColor: c.canvas,
      filledSide: outline,
      secondarySide: outline,
      secondaryFill: c.card,
      textButtonColor: c.ink,
      navColor: c.card,
      navIndicatorColor: c.gold,
      navIndicatorSide: outline,
      // Selected = ink on gold; unselected = muted ink on the card.
      navSelectedColor: c.onGold,
      navUnselectedColor: c.inkMuted,
      chipSelectedColor: c.gold,
      chipSide: outline,
      dividerColor: c.line,
      progressColor: c.safe,
      progressTrackColor: c.card,
      progressMinHeight: 14,
    ),
  );
}
