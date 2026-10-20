/// Which foot a sole is worn on.
///
/// The firmware has no left/right concept — every sole runs the same image and
/// is told apart only by its chip ID — so the side is assigned by the app and
/// stored on the paired entry. See
/// `docs/superpowers/specs/2026-10-20-double-feet-design.md`.
enum FootSide {
  left('left_foot'),
  right('right_foot');

  const FootSide(this.labelKey);

  /// Key in `strings.csv`.
  final String labelKey;

  /// The other foot — assigning one sole a side gives the other sole this.
  FootSide get other => this == FootSide.left ? FootSide.right : FootSide.left;
}
