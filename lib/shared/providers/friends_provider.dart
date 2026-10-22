import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friends_repository.dart';
import 'package:silversole/core/friends/supabase_friends_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the friends feature is shown at all.
///
/// The Supabase side (`supabase/migrations/20261019120000_friends.sql`) is not
/// applied to any project yet, so a release build hides friends entirely.
/// Debug builds show it on in-memory demo data so the screens can be tried.
/// Once the migration is live, build with `--dart-define=FRIENDS_BACKEND=supabase`
/// (see [Constants.friendsBackend]) and it is on everywhere.
final friendsEnabledProvider = Provider<bool>(
  (ref) => Constants.friendsOnSupabase || kDebugMode,
);

/// The friends backend: the Supabase RPCs when [Constants.friendsOnSupabase],
/// otherwise the in-memory demo (`FakeFriendsRepository.seeded()`). Tests
/// override this provider with their own fake.
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  if (Constants.friendsOnSupabase) {
    return SupabaseFriendsRepository(Supabase.instance.client);
  }
  final repo = FakeFriendsRepository.seeded();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Unwraps a [Result] for a [FutureProvider]: an error becomes the provider's
/// error state (always a `FriendException`).
Future<T> _unwrap<T>(Future<Result<T>> call) async {
  return switch (await call) {
    Ok(:final value) => value,
    Error(:final error) => throw error,
  };
}

final myFriendProfileProvider = FutureProvider<MyProfile>(
  (ref) => _unwrap(ref.watch(friendsRepositoryProvider).getMyProfile()),
);

final friendsListProvider = FutureProvider<List<Friend>>(
  (ref) => _unwrap(ref.watch(friendsRepositoryProvider).getFriends()),
);

final friendRequestsProvider = FutureProvider<List<FriendRequest>>(
  (ref) => _unwrap(ref.watch(friendsRepositoryProvider).getFriendRequests()),
);

/// Drives the red dot on the plaza's friends building and the requests row.
final incomingRequestCountProvider = Provider<int>((ref) {
  final requests = ref.watch(friendRequestsProvider).value ?? const [];
  return requests.where((r) => r.incoming).length;
});

final myOrgsProvider = FutureProvider<List<OrgSummary>>(
  (ref) => _unwrap(ref.watch(friendsRepositoryProvider).getMyOrgs()),
);

final orgMembersProvider = FutureProvider.family<List<OrgMember>, String>(
  (ref, orgId) =>
      _unwrap(ref.watch(friendsRepositoryProvider).getOrgMembers(orgId)),
);

final blockedListProvider = FutureProvider<List<FriendProfile>>(
  (ref) => _unwrap(ref.watch(friendsRepositoryProvider).getBlocked()),
);

/// Re-reads everything after a change. The lists are small, so one refresh
/// is simpler than tracking which list a given action touched.
void refreshFriendsData(WidgetRef ref) {
  ref.invalidate(myFriendProfileProvider);
  ref.invalidate(friendsListProvider);
  ref.invalidate(friendRequestsProvider);
  ref.invalidate(myOrgsProvider);
  ref.invalidate(orgMembersProvider);
  ref.invalidate(blockedListProvider);
}

/// [refreshFriendsData] from outside a widget, or after the widget that
/// started the call has gone.
void refreshFriendsDataIn(ProviderContainer container) {
  container
    ..invalidate(myFriendProfileProvider)
    ..invalidate(friendsListProvider)
    ..invalidate(friendRequestsProvider)
    ..invalidate(myOrgsProvider)
    ..invalidate(orgMembersProvider)
    ..invalidate(blockedListProvider);
}

/// Second line of the games-hub friends card: pending requests first, else
/// how many friends there are.
String friendsCardSubtitle(WidgetRef ref) {
  final incoming = ref.watch(incomingRequestCountProvider);
  if (incoming > 0) return 'friends_card_requests'.tr(args: ['$incoming']);
  final count = ref.watch(friendsListProvider).value?.length;
  return count == null
      ? 'friends_card_open'.tr()
      : 'friends_card_count'.tr(args: ['$count']);
}
