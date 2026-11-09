import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_look.dart';
import 'package:silversole/core/theme/app_palette_skins.dart';
import 'package:silversole/core/theme/app_theme_base.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/core/theme/app_tokens.dart';

/// Builds the [ThemeData] for look C, 溫暖紙本手帳風 (subscribers): paper, slate
/// "pen" ink, pastel sticky notes, the yellow as a highlighter, a handwritten
/// Kai face. Light only.
ThemeData appThemeC() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppPaletteC.highlight,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppPaletteC.highlight,
        onPrimary: AppPaletteC.ink,
        secondary: AppPaletteC.sage,
        onSecondary: AppPaletteC.ink,
        tertiary: AppPaletteC.lilac,
        surface: AppPaletteC.card,
        onSurface: AppPaletteC.ink,
        onSurfaceVariant: AppPaletteC.muted,
        surfaceContainerLowest: AppPaletteC.paper,
        surfaceContainerLow: AppPaletteC.butter,
        surfaceContainer: AppPaletteC.card,
        surfaceContainerHigh: AppPaletteC.sage,
        surfaceContainerHighest: AppPaletteC.sage,
        outline: AppPaletteC.ink,
        outlineVariant: const Color(0xFFD8D1BC),
        inverseSurface: AppPaletteC.ink,
        onInverseSurface: AppPaletteC.card,
        error: AppPaletteC.alert,
        surfaceTint: Colors.transparent,
      );
  const pen = BorderSide(color: AppPaletteC.ink, width: 2.5);

  return buildAppThemeData(
    AppSkin(
      scheme: scheme,
      fontFamily: AppPaletteC.fontFamily,
      scaffoldColor: AppPaletteC.paper,
      extensions: <ThemeExtension<dynamic>>[
        AppTokens.light.copyWith(success: const Color(0xFF4C8A55)),
        const AppLook(AppThemeVariant.journal),
      ],
      cardColor: AppPaletteC.card,
      cardSide: BorderSide.none,
      cardElevation: 1,
      cardShadowColor: const Color(0x333C321E),
      sheetColor: AppPaletteC.paper,
      // The primary button is a stamp: yellow with a drawn border.
      filledSide: pen,
      secondarySide: pen,
      secondaryFill: AppPaletteC.card,
      textButtonColor: AppPaletteC.ink,
      navColor: AppPaletteC.card,
      navIndicatorColor: AppPaletteC.highlight,
      navHeight: 80,
      navSelectedColor: AppPaletteC.ink,
      navSelectedLabelColor: AppPaletteC.ink,
      navUnselectedColor: const Color(0xFF7B8594),
      chipSelectedColor: AppPaletteC.highlight,
      chipSide: pen,
      dividerColor: AppPaletteC.rule,
      progressColor: AppPaletteC.highlight,
      progressTrackColor: AppPaletteC.card,
      progressMinHeight: 14,
    ),
  );
}
