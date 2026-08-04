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

  // ── Functional ─────────────────────────────────────────────────────────
  /// Positive / safe status (progress fill, "安全" badge).
  static const Color safe = Color(0xFF3E9E52);

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
