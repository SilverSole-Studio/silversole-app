import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_radius.dart';
import 'package:silversole/core/theme/app_spacing.dart';
import 'package:silversole/core/theme/app_typography.dart';

/// What differs between the two themes. Everything else (type scale, radii,
/// button sizes, the three button kinds, the one card shape) is decided once
/// in [buildAppThemeData], so the classic and mascot themes cannot drift apart:
/// each theme only supplies colors, a font family and how loud the outline is.
@immutable
class AppSkin {
  const AppSkin({
    required this.scheme,
    required this.fontFamily,
    required this.scaffoldColor,
    required this.cardColor,
    required this.cardSide,
    required this.sheetColor,
    required this.navColor,
    required this.navIndicatorColor,
    required this.navSelectedColor,
    required this.navSelectedLabelColor,
    required this.navUnselectedColor,
    required this.extensions,
    this.cardElevation = 0,
    this.cardShadowColor = Colors.transparent,
    this.filledSide = BorderSide.none,
    this.secondarySide,
    this.secondaryFill,
    this.navIndicatorSide = BorderSide.none,
    this.textButtonColor,
    this.chipSelectedColor,
    this.chipSide,
    this.dividerColor,
    this.progressColor,
    this.progressTrackColor,
    this.progressMinHeight,
    this.inputFill,
    this.filledDecoration,
    this.navHeight,
  });

  final ColorScheme scheme;
  final String fontFamily;
  final Color scaffoldColor;

  // Card: the single card shape of the app.
  final Color cardColor;
  final BorderSide cardSide;
  final double cardElevation;
  final Color cardShadowColor;

  final Color sheetColor;

  // Buttons.
  final BorderSide filledSide;
  final BorderSide? secondarySide;
  final Color? secondaryFill;
  final Color? textButtonColor;

  // Navigation bar.
  final Color navColor;
  final Color navIndicatorColor;
  final BorderSide navIndicatorSide;
  final Color navSelectedColor;

  /// The selected tab's label color. The label sits under the indicator (not
  /// on it), so it can differ from the icon, which sits on the indicator.
  final Color navSelectedLabelColor;
  final Color navUnselectedColor;

  final Color? chipSelectedColor;
  final BorderSide? chipSide;
  final Color? dividerColor;
  final Color? progressColor;
  final Color? progressTrackColor;
  final double? progressMinHeight;
  final Color? inputFill;

  /// Draws the primary button by hand (a hard shadow, say), given the button's
  /// current states. Null = the usual filled Material button.
  final BoxDecoration Function(Set<WidgetState> states)? filledDecoration;

  /// Bottom navigation height; null = [kNavBarHeight].
  final double? navHeight;

  final List<ThemeExtension<dynamic>> extensions;
}

/// Height of the primary action button: one size app-wide.
const double kPrimaryButtonHeight = 56;

/// Smallest touch target (Material and WCAG both say 48).
const double kMinTouchTarget = 48;

/// Height of the bottom navigation bar.
const double kNavBarHeight = 72;

/// Builds the [ThemeData] both themes share: one type scale, three radii, one
/// card, three button kinds (primary = filled, secondary = outlined/elevated,
/// text), all from [AppSkin].
ThemeData buildAppThemeData(AppSkin skin) {
  final scheme = skin.scheme;
  final textTheme = AppTypography.textTheme(
    family: skin.fontFamily,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  const buttonPadding = EdgeInsets.symmetric(horizontal: AppSpacing.xl);
  final secondarySide =
      skin.secondarySide ?? BorderSide(color: scheme.outlineVariant);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: skin.fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: skin.scaffoldColor,
    splashFactory: InkSparkle.splashFactory,
    extensions: skin.extensions,

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),

    // The one card. Classic reads as a card through a hairline + faint shadow,
    // mascot through a hard outline; shape and radius are the same.
    cardTheme: CardThemeData(
      color: skin.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: skin.cardElevation,
      shadowColor: skin.cardShadowColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardR,
        side: skin.cardSide,
      ),
      clipBehavior: Clip.antiAlias,
    ),

    // Primary: solid, full-height, at most one per page.
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            // A hand-drawn button paints its own fill (see filledDecoration).
            backgroundColor: skin.filledDecoration == null
                ? scheme.primary
                : Colors.transparent,
            disabledBackgroundColor: skin.filledDecoration == null
                ? null
                : Colors.transparent,
            foregroundColor: scheme.onPrimary,
            minimumSize: const Size(0, kPrimaryButtonHeight),
            padding: buttonPadding,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.controlR,
              side: skin.filledSide,
            ),
            textStyle: textTheme.labelLarge,
          ).copyWith(
            backgroundBuilder: skin.filledDecoration == null
                ? null
                : (context, states, child) {
                    final pressed = states.contains(WidgetState.pressed);
                    return Transform.translate(
                      offset: Offset(0, pressed ? 4 : 0),
                      child: DecoratedBox(
                        decoration: skin.filledDecoration!(states),
                        child: child,
                      ),
                    );
                  },
          ),
    ),
    // Secondary: outlined. Elevated buttons map onto the same look so the app
    // has one secondary button, not two.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, kPrimaryButtonHeight),
        padding: buttonPadding,
        shape: AppRadius.controlShape,
        side: secondarySide,
        backgroundColor: skin.secondaryFill,
        textStyle: textTheme.labelLarge,
        foregroundColor: scheme.onSurface,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, kPrimaryButtonHeight),
        padding: buttonPadding,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlR,
          side: secondarySide,
        ),
        textStyle: textTheme.labelLarge,
        backgroundColor: skin.secondaryFill ?? scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
      ),
    ),
    // Text: cancel / "see more" only.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: skin.textButtonColor ?? scheme.primary,
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
        shape: AppRadius.controlShape,
        textStyle: textTheme.labelLarge,
      ),
    ),

    chipTheme: ChipThemeData(
      shape: AppRadius.pillShape,
      side:
          skin.chipSide ??
          BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: skin.chipSelectedColor ?? scheme.inverseSurface,
      checkmarkColor: scheme.onInverseSurface,
      labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      showCheckmark: false,
    ),

    // Bottom navigation: icon + label (14sp, never smaller), and a visible
    // selected state: a filled indicator, not just a color change.
    navigationBarTheme: NavigationBarThemeData(
      height: skin.navHeight ?? kNavBarHeight,
      backgroundColor: skin.navColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: skin.navIndicatorColor,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: AppRadius.controlR,
        side: skin.navIndicatorSide,
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? skin.navSelectedColor
              : skin.navUnselectedColor,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? skin.navSelectedLabelColor
              : skin.navUnselectedColor,
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.controlR,
        side: skin.filledSide,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: skin.inputFill != null,
      fillColor: skin.inputFill,
      border: const OutlineInputBorder(borderRadius: AppRadius.controlR),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.controlR,
        borderSide: secondarySide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.controlR,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: skin.dividerColor ?? scheme.outlineVariant,
      thickness: 1,
      space: AppSpacing.base,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        foregroundColor: scheme.onSurfaceVariant,
        minimumSize: const Size(0, kMinTouchTarget),
        shape: AppRadius.controlShape,
        side: secondarySide,
        textStyle: textTheme.labelMedium,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: skin.sheetColor,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
        side: skin.cardSide,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: skin.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardR,
        side: skin.cardSide,
      ),
    ),

    listTileTheme: const ListTileThemeData(shape: AppRadius.controlShape),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: skin.progressColor ?? scheme.primary,
      linearTrackColor: skin.progressTrackColor,
      linearMinHeight: skin.progressMinHeight,
    ),
  );
}
