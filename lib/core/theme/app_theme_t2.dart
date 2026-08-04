import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/theme/app_tokens.dart';

/// Builds the [ThemeData] for the illustrated "mascot" theme (theme two).
///
/// Kept in its own file rather than parameterizing `appTheme()` so the classic
/// theme's tuned color model is not disturbed. The look is defined by three
/// things the classic theme deliberately avoids: a warm cream canvas, gold as
/// a large fill, and a hard dark outline on every card (no soft shadow).
///
/// Only light is designed for now — the mockup is a light design. Dark mode
/// returns the same scheme so switching brightness cannot produce an unstyled
/// screen; a proper dark variant is future work.
ThemeData appThemeT2(Brightness brightness) {
  const outline = BorderSide(
    color: AppPaletteT2.ink,
    width: AppPaletteT2.outlineWidth,
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppPaletteT2.cardRadius),
    side: outline,
  );

  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppPaletteT2.gold,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppPaletteT2.gold,
        onPrimary: AppPaletteT2.ink,
        secondary: AppPaletteT2.goldDeep,
        onSecondary: AppPaletteT2.ink,
        surface: AppPaletteT2.card,
        onSurface: AppPaletteT2.ink,
        onSurfaceVariant: AppPaletteT2.inkMuted,
        surfaceContainerLow: AppPaletteT2.cardWarm,
        surfaceContainer: AppPaletteT2.cardWarm,
        outline: AppPaletteT2.ink,
        outlineVariant: AppPaletteT2.ink,
        error: AppPaletteT2.danger,
        surfaceTint: Colors.transparent,
      );

  // DM Sans ships with the mascot art pack; its rounded, heavy weights carry
  // this theme's voice the way Google Sans carries the classic one.
  const family = 'DM Sans';

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final textTheme = base.textTheme
      .apply(
        fontFamily: family,
        bodyColor: AppPaletteT2.ink,
        displayColor: AppPaletteT2.ink,
      )
      .copyWith(
        headlineLarge: const TextStyle(
          fontFamily: family,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppPaletteT2.ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: family,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppPaletteT2.ink,
        ),
        titleLarge: const TextStyle(
          fontFamily: family,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppPaletteT2.ink,
        ),
        titleMedium: const TextStyle(
          fontFamily: family,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppPaletteT2.ink,
        ),
        bodyLarge: const TextStyle(
          fontFamily: family,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppPaletteT2.ink,
        ),
        bodyMedium: const TextStyle(
          fontFamily: family,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppPaletteT2.inkMuted,
        ),
        labelLarge: const TextStyle(
          fontFamily: family,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppPaletteT2.ink,
        ),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: family,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppPaletteT2.canvas,
    splashFactory: InkSparkle.splashFactory,
    // Reuse the functional accents; this theme overrides what it needs locally.
    extensions: <ThemeExtension<dynamic>>[AppTokens.of(brightness)],

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppPaletteT2.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    // The outline — not a shadow — is what reads as "card" in this theme.
    cardTheme: CardThemeData(
      color: AppPaletteT2.card,
      elevation: 0,
      shape: cardShape,
      margin: EdgeInsets.zero,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPaletteT2.gold,
        foregroundColor: AppPaletteT2.ink,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontFamily: family,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: outline,
        ),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppPaletteT2.ink,
      thickness: 1,
      space: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppPaletteT2.safe,
      linearTrackColor: AppPaletteT2.card,
      linearMinHeight: 14,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppPaletteT2.card,
      indicatorColor: AppPaletteT2.gold,
      elevation: 0,
      height: 74,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: outline,
      ),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: family,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppPaletteT2.ink,
        ),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPaletteT2.canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: outline,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppPaletteT2.card,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
    ),
  );
}
