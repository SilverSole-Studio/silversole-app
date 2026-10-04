/// The verdict a one-minute foot check reports.
///
/// Derived from the measured load balance rather than picked — see
/// [FootLoadBalance.rating] for the standard. There is deliberately no numeric
/// score: "how many points" needs a clinical scoring standard, so the three
/// bands *are* the standard.
///
/// Ordered weakest first: [level] is how many of the three segments the result
/// panel fills.
enum FootCheckRating {
  good('foot_check_rating_good'),
  veryGood('foot_check_rating_very_good'),
  excellent('foot_check_rating_excellent');

  const FootCheckRating(this.labelKey);

  /// Key in `strings.csv`.
  final String labelKey;

  /// 1, 2 or 3 — segments filled on the three-part indicator.
  int get level => index + 1;
}
