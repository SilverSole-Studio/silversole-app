import 'package:flutter/material.dart';

/// Single source of truth for every raw brand / functional color in the app.
///
/// To re-theme the app's accent, change [brandSeed] (and optionally
/// [brandCyan] for the highlight). Everything chromatic derives from these —
/// you should not need to touch any other file. Neutral surfaces stay
/// grayscale regardless (see `app_theme.dart`).
abstract final class AppPalette {
  // ── Brand ──────────────────────────────────────────────────────────────
  /// The accent seed. Drives primary/secondary/tertiary via
  /// `ColorScheme.fromSeed`. Swap ONLY this to re-theme the accent.
  /// Royal blue, per DESIGN.md.
  static const Color brandSeed = Color(0xFF2F6BFF);

  /// Highlight cyan — hero emphasis words, gradient end, logo tail.
  static const Color brandCyan = Color(0xFF29B6E8);

  /// Brand gradient (logo / hero highlight). Blue → cyan.
  static const List<Color> brandGradient = [brandSeed, brandCyan];

  // ── Functional hues (theme-independent: same in light & dark) ───────────
  /// Reward / points actions (可領取-style buttons, point badges).
  static const Color rewardGold = Color(0xFFFAC42A);

  /// Foreground text/icon placed on [rewardGold].
  static const Color onReward = Color(0xFF5A4500);

  /// Data emphasis (chart segments, highlights).
  static const Color dataOrange = Color(0xFFFF9A1F);

  /// Negative / warning values (over-budget, high severity).
  static const Color alert = Color(0xFFE5392E);

  /// Positive / healthy status (wear OK, normal).
  static const Color success = Color(0xFF1E9E5A);

  // ── Domain data-viz ramps (carry clinical meaning — DO NOT recolor) ─────
  /// Jet colormap for the foot-pressure heatmap (low → high pressure).
  static const List<Color> pressureJet = [
    Color(0xFF00007F),
    Color(0xFF0000FF),
    Color(0xFF00FFFF),
    Color(0xFF00FF00),
    Color(0xFFFFFF00),
    Color(0xFFFF7F00),
    Color(0xFFFF0000),
  ];

  /// Analytics pressure-distribution gradient (low → high).
  static const List<Color> pressureGradient = [
    Color(0xFF2F56B3),
    Color(0xFF126BFF),
    Color(0xFF4AC663),
    Color(0xFFFFE735),
    Color(0xFFFF8A1D),
    Color(0xFFFF2D20),
  ];

  /// Multi-series line/chart palette. Theme-stable, high-contrast. Index with
  /// modulo so any number of series stays in range.
  static const List<Color> chartSeries = [
    Color(0xFF2F6BFF),
    Color(0xFFFF9A1F),
    Color(0xFF1E9E5A),
    Color(0xFFE5392E),
    Color(0xFF8B5CF6),
    Color(0xFF29B6E8),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
    Color(0xFF84CC16),
    Color(0xFFEF4444),
  ];
}
