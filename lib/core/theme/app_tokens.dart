import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette.dart';

/// Custom theme tokens that don't fit Material's [ColorScheme] roles
/// (reward gold, data orange, alert/success, brand cyan + gradient).
///
/// Registered on [ThemeData.extensions] and read via `context.tokens`
/// (see `core/utils/useful_extension.dart`). Implements [lerp] so values
/// animate smoothly across a light/dark theme transition.
///
/// Functional hues are intentionally the same in light and dark (per
/// DESIGN.md): gold stays gold, alert stays red, etc.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color brandCyan;
  final Color rewardGold;
  final Color onReward;
  final Color dataOrange;
  final Color alert;
  final Color success;
  final List<Color> brandGradient;

  const AppTokens({
    required this.brandCyan,
    required this.rewardGold,
    required this.onReward,
    required this.dataOrange,
    required this.alert,
    required this.success,
    required this.brandGradient,
  });

  static const AppTokens light = AppTokens(
    brandCyan: AppPalette.brandCyan,
    rewardGold: AppPalette.rewardGold,
    onReward: AppPalette.onReward,
    dataOrange: AppPalette.dataOrange,
    alert: AppPalette.alert,
    success: AppPalette.success,
    brandGradient: AppPalette.brandGradient,
  );

  /// Same accents in dark mode (functional hues are theme-independent).
  static const AppTokens dark = light;

  static AppTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  AppTokens copyWith({
    Color? brandCyan,
    Color? rewardGold,
    Color? onReward,
    Color? dataOrange,
    Color? alert,
    Color? success,
    List<Color>? brandGradient,
  }) {
    return AppTokens(
      brandCyan: brandCyan ?? this.brandCyan,
      rewardGold: rewardGold ?? this.rewardGold,
      onReward: onReward ?? this.onReward,
      dataOrange: dataOrange ?? this.dataOrange,
      alert: alert ?? this.alert,
      success: success ?? this.success,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      brandCyan: Color.lerp(brandCyan, other.brandCyan, t)!,
      rewardGold: Color.lerp(rewardGold, other.rewardGold, t)!,
      onReward: Color.lerp(onReward, other.onReward, t)!,
      dataOrange: Color.lerp(dataOrange, other.dataOrange, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      success: Color.lerp(success, other.success, t)!,
      brandGradient: [
        for (var i = 0; i < brandGradient.length; i++)
          Color.lerp(brandGradient[i], other.brandGradient[i], t)!,
      ],
    );
  }
}
