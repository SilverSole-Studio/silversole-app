import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friends_repository.dart';
import 'package:silversole/core/friends/nickname_generator.dart';
import 'package:silversole/core/friends/supabase_friends_repository.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
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
    // Signing out and in as someone else must not show the last person's
    // profile (and, with it, skip their successor's first-login name step).
    ref.watch(authUserProvider);
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

/// Source of the suggested names on the first-login name page. Tests
/// override it with a seeded one.
final nicknameGeneratorProvider = Provider<NicknameGenerator>(
  (ref) => NicknameGenerator(),
);

/// How long the app waits for the profile before letting a signed-in user
/// into the home page without the name step.
const kNicknameGateTimeout = Duration(seconds: 8);

/// True when a signed-in user has no nickname yet and must pick one before
/// the app opens (first login, or an older account that never opened the
/// friends page). Friends are shown only when [friendsEnabledProvider] is on,
/// so nothing is asked while the backend that stores the name is not live.
///
/// Fails open: if the profile cannot be read (offline, slow, server error)
/// the answer is false and the user is let in; the friends page asks for a
/// name when they next open it. Nobody is locked out of the app by a failed
/// friends call.
final needsNicknameProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(friendsEnabledProvider)) return false;
  if (ref.watch(authUserProvider) == null) return false;
  try {
    final me = await ref
        .watch(myFriendProfileProvider.future)
        .timeout(kNicknameGateTimeout);
    return me.needsSetup;
  } catch (_) {
    return false;
  }
});

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

/// The signed-in user's share link as it stands now; null when there is none
/// that still works. Drives the "turn off link" row on the friends page.
final shareLinkProvider = FutureProvider<ShareLink?>(
  (ref) => _unwrap(ref.watch(friendsRepositoryProvider).getShareLink()),
);

/// Opens the phone's share sheet with [text]. [origin] is where the sheet
/// points to on an iPad. A provider so tests can see what would be shared.
typedef ShareText = Future<void> Function(String text, Rect? origin);

final shareTextProvider = Provider<ShareText>(
  (ref) =>
      (text, origin) => SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      ),
);

/// A share link that was opened while nobody was signed in. The sign-in
/// screen is shown first; once the user is in, the router takes the token
/// from here and opens the link. Kept in memory only.
class PendingShareLink {
  String? _token;

  void hold(String token) => _token = token;

  /// The held token, once: a second call returns null.
  String? take() {
    final token = _token;
    _token = null;
    return token;
  }
}

final pendingShareLinkProvider = Provider<PendingShareLink>(
  (ref) => PendingShareLink(),
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
  ref.invalidate(shareLinkProvider);
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
    ..invalidate(blockedListProvider)
    ..invalidate(shareLinkProvider);
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
