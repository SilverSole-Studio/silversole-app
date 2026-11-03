import 'package:flutter/material.dart';

/// Raw colors for look A, 粗哥手繪小鎮風 (the mascot theme, the default).
///
/// Taken from the design mock (首頁風格打樣/a.html), which is itself the game's
/// own town: a sky-blue top, grass underfoot, cream-paper cards drawn with a
/// thick brown outline and a hard offset shadow, and the mascot's yellow
/// (#FCBD3C) as the one action color. Text is the same brown as the outline.
abstract final class AppPaletteT2 {
  // ── Canvas & surfaces ──────────────────────────────────────────────────
  /// Page body — the town's grass.
  static const Color canvas = Color(0xFF9CCC6B);

  /// Lighter grass: hills, the far side of a gradient.
  static const Color grassLight = Color(0xFFB6DC8B);

  /// The sky behind the greeting.
  static const Color sky = Color(0xFFA9DDF2);

  /// Cards: cream paper.
  static const Color card = Color(0xFFFFF6DC);

  /// A warmer paper for a second kind of card (today's exercise, tinted).
  static const Color cardWarm = Color(0xFFFFF0C0);

  /// Notice-board wood (the missions board).
  static const Color wood = Color(0xFFDFAE6C);

  // ── Brand ──────────────────────────────────────────────────────────────
  /// The mascot's yellow — primary buttons, the selected tab, hero numerals'
  /// shadow.
  static const Color gold = Color(0xFFFCBD3C);

  /// Brighter yellow for small icon fills (the sun, the play disc).
  static const Color goldBright = Color(0xFFFFD23F);

  /// Pressed / deeper yellow.
  static const Color goldDeep = Color(0xFFE9A23B);

  // ── Ink (text + the signature outline) ─────────────────────────────────
  /// Primary text and the outline stroke drawn around cards.
  static const Color ink = Color(0xFF3B3325);

  /// Secondary text on paper.
  static const Color inkMuted = Color(0xFF6B5E45);

  /// Progress fill for a stale value, e.g. a remembered (not live) battery
  /// level: a pale warm gray that reads as "previous" against the white track.
  static const Color inkFaint = Color(0xFFD9D2BE);

  // ── Functional ─────────────────────────────────────────────────────────
  /// Positive / safe status (progress fill, "安全" badge).
  static const Color safe = Color(0xFF4FAE45);

  /// Tinted fill behind [safe] text, e.g. the "已是最新" firmware pill.
  static const Color safeSoft = Color(0xFFBFE6A2);

  /// Warning / streak flame.
  static const Color flame = Color(0xFFF2622E);

  /// Negative status — the awning's brick red.
  static const Color danger = Color(0xFFE5533D);

  // ── Shape ──────────────────────────────────────────────────────────────
  /// Stroke width of the outline that defines this look's card.
  static const double outlineWidth = 3;

  /// Card corner radius (the mock's 22).
  static const double cardRadius = 22;

  /// How far the hard shadow drops under a card.
  static const double shadowDrop = 5;
}

/// Look A's colors as a [ThemeExtension]; widgets read `context.mascot`.
///
///  * [ink] is text; [line] is the outline stroke drawn around cards (the same
///    brown).
///  * [onGold] is text/icon on a [gold] fill.
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
    required this.sky,
    required this.wood,
    required this.goldBright,
    required this.grassLight,
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
  final Color sky;
  final Color wood;
  final Color goldBright;
  final Color grassLight;

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
    sky: AppPaletteT2.sky,
    wood: AppPaletteT2.wood,
    goldBright: AppPaletteT2.goldBright,
    grassLight: AppPaletteT2.grassLight,
  );

  /// There is only a light version: dark is a different look (極簡科技・黑).
  static MascotColors of(Brightness brightness) => light;

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
    Color? sky,
    Color? wood,
    Color? goldBright,
    Color? grassLight,
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
    sky: sky ?? this.sky,
    wood: wood ?? this.wood,
    goldBright: goldBright ?? this.goldBright,
    grassLight: grassLight ?? this.grassLight,
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
      sky: l(sky, other.sky),
      wood: l(wood, other.wood),
      goldBright: l(goldBright, other.goldBright),
      grassLight: l(grassLight, other.grassLight),
    );
  }
}
