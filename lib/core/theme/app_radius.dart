import 'package:flutter/material.dart';

/// Corner-radius scale: exactly three radii, shared by both themes.
///
///  * [card] — every card, dialog, bottom sheet and large block.
///  * [control] — buttons, inputs, tiles, nav indicator and other small blocks.
///  * [pill] — tags, chips, progress capsules.
///
/// The older names ([banner], [fab], [field], [sub]) are kept as aliases of
/// [control] so existing call sites keep compiling; new code uses the three
/// names above.
abstract final class AppRadius {
  static const double card = 24;
  static const double control = 16;
  static const double pill = 999;

  // Aliases of [control] (the pre-token scale had eight different radii).
  static const double banner = control;
  static const double fab = control;
  static const double field = control;
  static const double sub = control;

  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius controlR = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius pillR = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius bannerR = controlR;
  static const BorderRadius fabR = controlR;
  static const BorderRadius fieldR = controlR;
  static const BorderRadius subR = controlR;

  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: cardR,
  );
  static const RoundedRectangleBorder controlShape = RoundedRectangleBorder(
    borderRadius: controlR,
  );
  static const RoundedRectangleBorder bannerShape = controlShape;
  static const RoundedRectangleBorder fabShape = controlShape;

  /// Fully-rounded pill (tags, chips).
  static const StadiumBorder pillShape = StadiumBorder();
}
