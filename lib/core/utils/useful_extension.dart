import 'package:flutter/material.dart';

extension TextStyleExtension on TextStyle? {
  TextStyle? get bold => this?.copyWith(fontWeight: FontWeight.bold);
}

extension ThemeExtension on BuildContext {
  TextTheme get tt => Theme.of(this).textTheme;
  ColorScheme get cs => Theme.of(this).colorScheme;
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
