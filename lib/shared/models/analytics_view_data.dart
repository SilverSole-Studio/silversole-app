/// Which window the analytics screens are summarising.
enum AnalyticsRange {
  day,
  week,
  month,
  quarter;

  /// Translation key for the selector label.
  String get labelKey => switch (this) {
    AnalyticsRange.day => 'range_day',
    AnalyticsRange.week => 'range_week',
    AnalyticsRange.month => 'range_month',
    AnalyticsRange.quarter => 'range_quarter',
  };

  /// Month and quarter have no aggregation pipeline yet, so both themes show
  /// the same "still crunching" state instead of an empty chart.
  bool get isReady => this == AnalyticsRange.day || this == AnalyticsRange.week;
}

/// A game achievement. Earned badges show in full colour; the rest are
/// desaturated with a lock, which is what makes the grid read as progress.
class BadgeEntry {
  const BadgeEntry({
    required this.nameKey,
    required this.art,
    required this.earned,
  });

  final String nameKey;
  final String art;
  final bool earned;
}

/// Shared by both themes so a badge is added in one place.
///
/// Earned flags are mockup copy — there is no achievement backend.
List<BadgeEntry> badgeCatalog() {
  const art = 'assets/mascot-assets/badges';
  return const [
    BadgeEntry(
      nameKey: 'badge_fish',
      art: '$art/badge_fish.webp',
      earned: true,
    ),
    BadgeEntry(
      nameKey: 'badge_quiz',
      art: '$art/badge_quiz.webp',
      earned: true,
    ),
    BadgeEntry(
      nameKey: 'badge_canoe',
      art: '$art/badge_canoe.webp',
      earned: true,
    ),
    BadgeEntry(
      nameKey: 'badge_bike',
      art: '$art/badge_bike.webp',
      earned: false,
    ),
    BadgeEntry(
      nameKey: 'badge_drums',
      art: '$art/badge_drums.webp',
      earned: false,
    ),
    BadgeEntry(nameKey: 'badge_bat', art: '$art/badge_bat.webp', earned: false),
    BadgeEntry(
      nameKey: 'badge_zombie',
      art: '$art/badge_zombie.webp',
      earned: false,
    ),
  ];
}

/// Gait figures shown under every range.
///
/// All mockup copy: the app measures none of these yet. Kept in one place so
/// both themes read the same numbers and there is a single site to swap for a
/// real source.
abstract final class MockGait {
  static const todaySteps = 5110;
  static const balanceGrade = 'A';

  /// Steps per weekday, Mon..Sun — the week chart's series.
  static const weekSteps = <int>[3200, 4100, 2900, 5100, 4400, 6000, 5600];
  static const weekTotal = 31800;
  static const weekDeltaPercent = 12;

  static const strideLengthCm = '62.4';
  static const symmetryScore = 94;
  static const stancePercent = 61;
  static const swingPercent = 39;
  static const dragCount = 8;
}
