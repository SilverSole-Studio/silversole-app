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
