import 'package:flutter/material.dart';

class AppTypography {
  static const String fontFamily = 'Oxanium';

  static TextTheme textTheme(TextTheme base) {
    return base.apply(fontFamily: fontFamily);
  }
}
