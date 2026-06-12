import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette.dart';
import 'package:silversole/core/theme/app_radius.dart';
import 'package:silversole/core/theme/app_spacing.dart';
import 'package:silversole/core/theme/app_tokens.dart';
import 'package:silversole/core/theme/app_typography.dart';

/// Builds the app [ThemeData] for a given [brightness].
///
/// Color model (unchanged philosophy — see test/theme_test.dart):
///  * Accent roles (primary/secondary/tertiary) come from [AppPalette.brandSeed].
///  * All neutral surfaces/outlines are locked to a grayscale ramp via the
///    monochrome scheme variant, so the body stays white/gray for any accent.
///  * Light surface is #FCFCFC (off-white, not pure white). No elevation tint.
///
/// On top of that, this configures a full [TextTheme] and every component
/// theme so widgets render correctly with zero per-widget styling, and
/// registers [AppTokens] for the non-ColorScheme colors.
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

  final textTheme = AppTypography.textTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    extensions: <ThemeExtension<dynamic>>[AppTokens.of(brightness)],

    // ── App bar: transparent, flat, left-aligned title ───────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),

    // ── Cards: 20dp radius; soft shadow in light, color-step in dark ─────
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: isLight ? 1.5 : 0,
      shadowColor: isLight
          ? Colors.black.withValues(alpha: 0.10)
          : Colors.transparent,
      margin: EdgeInsets.zero,
      shape: AppRadius.cardShape,
      clipBehavior: Clip.antiAlias,
    ),

    // ── Buttons ──────────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        elevation: 0,
        shape: AppRadius.pillShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: AppRadius.pillShape,
        textStyle: textTheme.labelLarge,
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: AppRadius.pillShape,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: textTheme.labelLarge,
        foregroundColor: scheme.onSurface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: textTheme.labelLarge,
      ),
    ),

    // ── Chips: pill; selected uses inverse-surface (dark-in-light /
    //    white-in-dark), which is exactly the DESIGN inverse-chip rule ────
    chipTheme: ChipThemeData(
      shape: AppRadius.pillShape,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.inverseSurface,
      checkmarkColor: scheme.onInverseSurface,
      labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle:
          textTheme.labelLarge?.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      showCheckmark: false,
    ),

    // ── Bottom navigation: blue active icon+label, no indicator pill ─────
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),

    // ── FAB: blue squircle ───────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 4,
      shape: AppRadius.fabShape,
    ),

    // ── Inputs ─────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(borderRadius: AppRadius.fieldR),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.fieldR,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.fieldR,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: AppSpacing.base,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: textTheme.labelLarge,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: AppRadius.cardShape,
    ),

    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.subR),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}
