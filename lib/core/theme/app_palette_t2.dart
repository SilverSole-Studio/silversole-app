import 'package:flutter/material.dart';

/// Raw colors for the illustrated "mascot" theme (theme two).
///
/// Deliberately separate from `AppPalette` so the classic theme's carefully
/// tuned grayscale-neutral model stays untouched. Where the classic theme
/// keeps neutrals grayscale and lets one accent seed drive everything, this
/// one is the opposite: a warm cream canvas, a gold brand color used as a
/// large fill, and a near-black outline drawn on every card.
abstract final class AppPaletteT2 {
  // ── Canvas & surfaces ──────────────────────────────────────────────────
  /// Page body — warm cream.
  static const Color canvas = Color(0xFFF7F1E0);

  /// Cards that are not gold-filled.
  static const Color card = Color(0xFFFFFFFF);

  /// Slightly warmer card used for secondary blocks (e.g. the mission card).
  static const Color cardWarm = Color(0xFFFDF6E6);

  // ── Brand ──────────────────────────────────────────────────────────────
  /// Gold — the hero fill (device card, primary buttons, selected nav pill).
  static const Color gold = Color(0xFFF5C84A);

  /// Deeper gold for pressed/emphasis states.
  static const Color goldDeep = Color(0xFFE9B62E);

  // ── Ink (text + the signature outline) ─────────────────────────────────
  /// Primary text and the outline stroke drawn around cards.
  static const Color ink = Color(0xFF2B2621);

  /// Secondary text.
  static const Color inkMuted = Color(0xFF6B6154);

  /// Progress fill for a stale value, e.g. a remembered (not live) battery
  /// level: a pale warm gray that reads as "previous" against the white track.
  static const Color inkFaint = Color(0xFFE2DDD5);

  // ── Functional ─────────────────────────────────────────────────────────
  /// Positive / safe status (progress fill, "安全" badge).
  static const Color safe = Color(0xFF3E9E52);

  /// Tinted fill behind [safe] text, e.g. the "已是最新" firmware pill.
  static const Color safeSoft = Color(0xFFE3F3E6);

  /// Warning / streak flame.
  static const Color flame = Color(0xFFF2622E);

  /// Negative status.
  static const Color danger = Color(0xFFD8453B);

  // ── Shape ──────────────────────────────────────────────────────────────
  /// Stroke width of the outline that defines this theme's card look.
  static const double outlineWidth = 2.5;

  /// Card corner radius.
  static const double cardRadius = 24;
}

/// The mascot theme's colors as a [ThemeExtension], so they can change with
/// the brightness. [AppPaletteT2] keeps the light values as constants (the
/// theme builder and tests use them); widgets read `context.mascot` so the
/// dark mode toggle reaches them too.
///
///  * [ink] is text; [line] is the outline stroke drawn around cards (the same
///    color in light, a dimmer cream in dark so thick outlines do not glare).
///  * [onGold] is text/icon on a [gold] fill: dark in both modes.
@immutable
class MascotColors extends ThemeExtension<MascotColors> {
  const MascotColors({
    required this.canvas,
    required this.card,
    required this.cardWarm,
    required this.gold,
    required this.goldDeep,
    required this.onGold,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.safe,
    required this.safeSoft,
    required this.flame,
    required this.danger,
  });

  final Color canvas;
  final Color card;
  final Color cardWarm;
  final Color gold;
  final Color goldDeep;
  final Color onGold;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color line;
  final Color safe;
  final Color safeSoft;
  final Color flame;
  final Color danger;

  static const MascotColors light = MascotColors(
    canvas: AppPaletteT2.canvas,
    card: AppPaletteT2.card,
    cardWarm: AppPaletteT2.cardWarm,
    gold: AppPaletteT2.gold,
    goldDeep: AppPaletteT2.goldDeep,
    onGold: AppPaletteT2.ink,
    ink: AppPaletteT2.ink,
    inkMuted: AppPaletteT2.inkMuted,
    inkFaint: AppPaletteT2.inkFaint,
    line: AppPaletteT2.ink,
    safe: AppPaletteT2.safe,
    safeSoft: AppPaletteT2.safeSoft,
    flame: AppPaletteT2.flame,
    danger: AppPaletteT2.danger,
  );

  /// Warm dark: the cream canvas inverted into a dark brown, gold unchanged.
  static const MascotColors dark = MascotColors(
    canvas: Color(0xFF1C1814),
    card: Color(0xFF2B2621),
    cardWarm: Color(0xFF352E25),
    gold: AppPaletteT2.gold,
    goldDeep: AppPaletteT2.goldDeep,
    onGold: AppPaletteT2.ink,
    ink: Color(0xFFF7F1E0),
    inkMuted: Color(0xFFC2B8A6),
    inkFaint: Color(0xFF4A4238),
    line: Color(0xFF6E6354),
    safe: Color(0xFF5CC070),
    safeSoft: Color(0xFF223D29),
    flame: Color(0xFFF2622E),
    danger: Color(0xFFE5645A),
  );

  static MascotColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  MascotColors copyWith({
    Color? canvas,
    Color? card,
    Color? cardWarm,
    Color? gold,
    Color? goldDeep,
    Color? onGold,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? line,
    Color? safe,
    Color? safeSoft,
    Color? flame,
    Color? danger,
  }) => MascotColors(
    canvas: canvas ?? this.canvas,
    card: card ?? this.card,
    cardWarm: cardWarm ?? this.cardWarm,
    gold: gold ?? this.gold,
    goldDeep: goldDeep ?? this.goldDeep,
    onGold: onGold ?? this.onGold,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    inkFaint: inkFaint ?? this.inkFaint,
    line: line ?? this.line,
    safe: safe ?? this.safe,
    safeSoft: safeSoft ?? this.safeSoft,
    flame: flame ?? this.flame,
    danger: danger ?? this.danger,
  );

  @override
  MascotColors lerp(ThemeExtension<MascotColors>? other, double t) {
    if (other is! MascotColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MascotColors(
      canvas: l(canvas, other.canvas),
      card: l(card, other.card),
      cardWarm: l(cardWarm, other.cardWarm),
      gold: l(gold, other.gold),
      goldDeep: l(goldDeep, other.goldDeep),
      onGold: l(onGold, other.onGold),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      inkFaint: l(inkFaint, other.inkFaint),
      line: l(line, other.line),
      safe: l(safe, other.safe),
      safeSoft: l(safeSoft, other.safeSoft),
      flame: l(flame, other.flame),
      danger: l(danger, other.danger),
    );
  }
}
