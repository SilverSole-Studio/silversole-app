import 'package:flutter/material.dart';

/// Raw colors for look B, 大數字健康儀表板 (subscribers). Warm black, the brand
/// yellow for the one thing to press, mint for "good / on track". From the
/// design mock (首頁風格打樣/b.html).
abstract final class AppPaletteB {
  static const Color bg = Color(0xFF14110C);
  static const Color panel = Color(0xFF201A11);
  static const Color panel2 = Color(0xFF2B2317);
  static const Color line = Color(0xFF3B3224);
  static const Color text = Color(0xFFF6EFD8);
  static const Color muted = Color(0xFFB3A687);
  static const Color yellow = Color(0xFFFCBD3C);
  static const Color onYellow = Color(0xFF1A1409);
  static const Color mint = Color(0xFF7FE3C7);
  static const Color alert = Color(0xFFFF7A66);

  /// Latin family for numerals (bundled, OFL).
  static const String numberFamily = 'Big Shoulders Display';
}

/// Raw colors for look C, 溫暖紙本手帳風 (subscribers). Dot-grid paper, a
/// slate-blue "ink pen", and a set of pastel sticky-note fills. From the design
/// mock (首頁風格打樣/c.html).
abstract final class AppPaletteC {
  static const Color paper = Color(0xFFF3EFE4);
  static const Color card = Color(0xFFFFFDF6);
  static const Color ink = Color(0xFF2E3A4D);
  static const Color muted = Color(0xFF6D7684);
  static const Color dot = Color(0xFFCBC3AB);
  static const Color butter = Color(0xFFFFF0A8);
  static const Color sage = Color(0xFFCFE3CF);
  static const Color peach = Color(0xFFFBD5BD);
  static const Color lilac = Color(0xFFDCD9F3);
  static const Color sky = Color(0xFFC3E2EF);
  static const Color highlight = Color(0xFFFCBD3C);
  static const Color highlightShade = Color(0xFFB8841C);
  static const Color rule = Color(0xFFCFD9E6);
  static const Color margin = Color(0xFFF0A9A0);
  static const Color alert = Color(0xFFC7503F);

  /// Handwritten Kai family (bundled, OFL).
  static const String fontFamily = 'LXGW WenKai TC';
}
