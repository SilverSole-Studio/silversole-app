import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_theme.dart';
import 'package:silversole/core/theme/app_theme_b.dart';
import 'package:silversole/core/theme/app_theme_c.dart';
import 'package:silversole/core/theme/app_theme_t2.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';

/// The [ThemeData] of [variant]. Light or dark is part of the look, so the app
/// passes this as its one `theme`.
ThemeData appThemeFor(AppThemeVariant variant) => switch (variant) {
  AppThemeVariant.mascot => appThemeT2(),
  AppThemeVariant.techLight => appTheme(Brightness.light),
  AppThemeVariant.techDark => appTheme(Brightness.dark),
  AppThemeVariant.dashboard => appThemeB(),
  AppThemeVariant.journal => appThemeC(),
};
