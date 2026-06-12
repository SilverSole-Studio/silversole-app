import 'package:flutter/material.dart';

/// Corner-radius scale + ready-made shapes, per DESIGN.md §4.
///
/// Prefer the pre-built [BorderRadius]/shape getters over
/// `BorderRadius.circular(20)` literals.
abstract final class AppRadius {
  static const double card = 20;
  static const double banner = 16;
  static const double fab = 18;
  static const double field = 12;
  static const double sub = 8;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius bannerR = BorderRadius.all(Radius.circular(banner));
  static const BorderRadius fabR = BorderRadius.all(Radius.circular(fab));
  static const BorderRadius fieldR = BorderRadius.all(Radius.circular(field));
  static const BorderRadius subR = BorderRadius.all(Radius.circular(sub));

  static const RoundedRectangleBorder cardShape =
      RoundedRectangleBorder(borderRadius: cardR);
  static const RoundedRectangleBorder bannerShape =
      RoundedRectangleBorder(borderRadius: bannerR);
  static const RoundedRectangleBorder fabShape =
      RoundedRectangleBorder(borderRadius: fabR);

  /// Fully-rounded pill (chips, CTAs).
  static const StadiumBorder pillShape = StadiumBorder();
}
