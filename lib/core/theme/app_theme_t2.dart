import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_look.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/theme/app_theme_base.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/core/theme/app_tokens.dart';
import 'package:silversole/core/theme/app_typography.dart';

/// Builds the [ThemeData] for look A, 粗哥手繪小鎮風 (the mascot theme).
///
/// Same type scale, radii and button sizes as every look (see
/// [buildAppThemeData]); what is its own is the grass-and-sky canvas, cream
/// paper, the mascot's yellow as a large fill, Chiron GoRound, and a thick
/// brown outline with a hard shadow on every card and the primary button.
/// Light only: dark is a different look.
ThemeData appThemeT2() {
  const c = MascotColors.light;
  const outline = BorderSide(
    color: AppPaletteT2.ink,
    width: AppPaletteT2.outlineWidth,
  );

  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppPaletteT2.gold,
        brightness: Brightness.light,
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
        onInverseSurface: c.card,
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
      extensions: <ThemeExtension<dynamic>>[
        AppTokens.of(Brightness.light),
        c,
        const AppLook(AppThemeVariant.mascot),
      ],
      // The outline, not a blurred shadow, is what reads as "card" here.
      cardColor: c.card,
      cardSide: outline,
      sheetColor: c.canvas,
      filledSide: BorderSide.none,
      filledDecoration: (states) {
        final off = states.contains(WidgetState.disabled);
        final pressed = states.contains(WidgetState.pressed);
        return BoxDecoration(
          color: off ? c.inkFaint : c.gold,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line, width: AppPaletteT2.outlineWidth),
          boxShadow: [
            BoxShadow(
              color: c.line,
              offset: Offset(0, pressed ? 1 : AppPaletteT2.shadowDrop),
            ),
          ],
        );
      },
      secondarySide: outline,
      secondaryFill: c.card,
      textButtonColor: c.ink,
      navColor: c.card,
      navIndicatorColor: c.gold,
      navIndicatorSide: outline,
      navHeight: 80,
      // Selected: dark icon on the gold, outlined indicator; the label is ink on
      // the bar; unselected = muted ink.
      navSelectedColor: c.onGold,
      navSelectedLabelColor: c.ink,
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
