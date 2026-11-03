import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_look.dart';
import 'package:silversole/core/theme/app_palette_skins.dart';
import 'package:silversole/core/theme/app_theme_base.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/core/theme/app_tokens.dart';
import 'package:silversole/core/theme/app_typography.dart';

/// Builds the [ThemeData] for look B, 大數字健康儀表板 (subscribers): warm black,
/// panels with a hairline, the brand yellow as the one action color and mint for
/// "on track". Dark only.
ThemeData appThemeB() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppPaletteB.yellow,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppPaletteB.yellow,
        onPrimary: AppPaletteB.onYellow,
        secondary: AppPaletteB.mint,
        onSecondary: AppPaletteB.onYellow,
        tertiary: AppPaletteB.mint,
        surface: AppPaletteB.bg,
        onSurface: AppPaletteB.text,
        onSurfaceVariant: AppPaletteB.muted,
        surfaceDim: AppPaletteB.bg,
        surfaceBright: AppPaletteB.panel2,
        surfaceContainerLowest: AppPaletteB.bg,
        surfaceContainerLow: AppPaletteB.panel,
        surfaceContainer: AppPaletteB.panel,
        surfaceContainerHigh: AppPaletteB.panel2,
        surfaceContainerHighest: AppPaletteB.panel2,
        outline: AppPaletteB.line,
        outlineVariant: AppPaletteB.line,
        inverseSurface: AppPaletteB.text,
        onInverseSurface: AppPaletteB.bg,
        error: AppPaletteB.alert,
        surfaceTint: Colors.transparent,
      );
  const hairline = BorderSide(color: AppPaletteB.line, width: 1.5);

  return buildAppThemeData(
    AppSkin(
      scheme: scheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldColor: AppPaletteB.bg,
      extensions: <ThemeExtension<dynamic>>[
        AppTokens.dark.copyWith(
          success: AppPaletteB.mint,
          brandCyan: AppPaletteB.mint,
          rewardGold: AppPaletteB.yellow,
          onReward: AppPaletteB.onYellow,
          brandGradient: const [AppPaletteB.yellow, AppPaletteB.mint],
        ),
        const AppLook(AppThemeVariant.dashboard),
      ],
      cardColor: AppPaletteB.panel,
      cardSide: hairline,
      sheetColor: AppPaletteB.panel,
      secondaryFill: AppPaletteB.panel,
      secondarySide: hairline,
      textButtonColor: AppPaletteB.yellow,
      navColor: AppPaletteB.bg,
      navIndicatorColor: AppPaletteB.yellow.withValues(alpha: 0.16),
      navSelectedColor: AppPaletteB.yellow,
      navSelectedLabelColor: AppPaletteB.yellow,
      navUnselectedColor: AppPaletteB.muted,
      chipSelectedColor: AppPaletteB.yellow,
      progressColor: AppPaletteB.mint,
      progressTrackColor: AppPaletteB.line,
    ),
  );
}
