import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_tokens.dart';

extension TextStyleExtension on TextStyle? {
  TextStyle? get bold => this?.copyWith(fontWeight: FontWeight.w700);
}

/// Shorthand theme access from a [BuildContext].
///
/// * `context.textTheme` — text theme (every slot pre-sized/weighted; see
///   `app_typography.dart`).
/// * `context.colorScheme` — color scheme (brand accent + grayscale neutrals).
/// * `context.tokens` — custom [AppTokens] (reward gold, data orange, alert,
///   success, brand cyan + gradient) that don't fit a ColorScheme role.
extension ContextThemeX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

extension ListExtension<T> on List<T> {
  /// Example:
  /// ```dart
  /// final numbers = <int>[1, 2, 3, 5, 6, 7];
  /// final result = numbers.takeLast(4); // (3, 5, 6, 7)
  /// final takeNeg = numbers.skip(-1); // () - no elements.
  /// final takeLastAll = numbers.skip(100); // (1, 2, 3, 5, 6, 7) - all elements.
  /// ```
  List<T> takeLast(int count) {
    if (count <= 0) return <T>[];
    if (count >= length) return this;
    return skip((length - count).clamp(0, length)).toList(growable: false);
  }
}
