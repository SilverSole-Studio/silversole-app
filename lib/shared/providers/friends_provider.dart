import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friends_repository.dart';

/// The friends backend. Fake (in-memory demo data) until the Supabase RPCs
/// in the friends spec exist; swap the implementation here and nothing else.
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
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

/// Drives the red dot on the games-hub card and the requests row.
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
