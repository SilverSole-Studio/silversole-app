import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';

/// Everything the app asks of the friends backend. One method per RPC in the
/// spec (§8.2); a failure is always a `FriendException`.
///
/// [SupabaseFriendsRepository] calls the same-named RPCs; the in-memory
/// [FakeFriendsRepository] plays the same rules for tests and the demo.
abstract interface class FriendsRepository {
  Future<Result<MyProfile>> getMyProfile();

  Future<Result<MyProfile>> updateProfile({
    String? nickname,
    int? avatarPreset,
    bool? showInOrgList,
  });

  /// [localPath] is a picked photo on the device, at most 512px (JPEG, PNG
  /// or WebP — the file's own bytes decide which).
  Future<Result<MyProfile>> setAvatarPhoto(String localPath);

  Future<Result<MyProfile>> clearAvatarPhoto();

  /// Clears the "your nickname / photo was removed" notice once shown.
  Future<Result<void>> acknowledgeRemovals();

  Future<Result<MyProfile>> rotateFriendCode();

  Future<Result<List<Friend>>> getFriends();

  Future<Result<QrToken>> createQrToken();

  Future<Result<FriendProfile>> previewByQr(String token);

  Future<Result<FriendProfile>> previewByCode(String code);

  /// The signed-in user's share link: the one that still works, or a new one
  /// (7 days) if there is none. Only ever one at a time.
  Future<Result<ShareLink>> createShareLink();

  /// The share link as it stands now; null when there is none, it was
  /// switched off, or it ran out.
  Future<Result<ShareLink?>> getShareLink();

  /// Switches the share link off at once. A new one can be made afterwards.
  Future<Result<void>> disableShareLink();

  /// Who owns a share link, for the person who opened it. Fails with
  /// [FriendError.linkExpired] for a link that was switched off or ran out.
  Future<Result<SharedProfile>> previewByShareLink(String token);

  /// [ref] is the QR token, the friend code, or (for [FriendSource.org]) the
  /// user id of someone on a shared org list, or (for [FriendSource.link]) the
  /// token of their share link.
  Future<Result<SendRequestOutcome>> sendFriendRequest(
    FriendSource source,
    String ref,
  );

  Future<Result<List<FriendRequest>>> getFriendRequests();

  Future<Result<void>> respondFriendRequest(
    String requestId,
    FriendRequestAction action,
  );

  Future<Result<void>> cancelFriendRequest(String requestId);

  Future<Result<void>> removeFriend(String userId);

  Future<Result<void>> blockUser(String userId);

  Future<Result<void>> unblockUser(String userId);

  Future<Result<List<FriendProfile>>> getBlocked();

  Future<Result<OrgSummary>> previewOrg(String joinCode);

  Future<Result<OrgSummary>> joinOrg(String joinCode);

  Future<Result<void>> leaveOrg(String orgId);

  Future<Result<List<OrgSummary>>> getMyOrgs();

  Future<Result<List<OrgMember>>> getOrgMembers(String orgId);

  Future<Result<void>> reportProfile(
    String userId,
    ReportKind kind,
    ReportReason reason,
  );
}
