/// Spacing scale (logical pixels), per DESIGN.md §4.
///
/// Use instead of bare literals: `EdgeInsets.all(AppSpacing.base)`.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// Default content/card padding and page rhythm unit.
  static const double base = 16;

  /// Page left/right margin.
  static const double lg = 20;

  /// Section spacing.
  static const double xl = 24;
  static const double xxl = 32;
}
