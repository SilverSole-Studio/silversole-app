/// Which visual language the app renders in.
///
/// This is a bigger switch than a color swap: each variant owns its own
/// [ThemeData] builder *and* its own page/widget implementations, because the
/// two designs lay their screens out differently. Shared providers and the
/// data layer stay common to both.
enum AppThemeVariant {
  /// The original blue design system — grayscale neutrals, one accent seed.
  classic,

  /// Illustrated "mascot" design — cream canvas, gold cards, thick dark
  /// outlines, DM Sans, character art.
  mascot;

  /// Nothing saved yet (first launch) → mascot, the illustrated design.
  static AppThemeVariant fromName(String? value) => switch (value) {
    'classic' => AppThemeVariant.classic,
    _ => AppThemeVariant.mascot,
  };
}
