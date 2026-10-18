import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';

/// Everything the app asks of the friends backend. One method per RPC in the
/// spec (§8.2); a failure is always a `FriendException`.
///
/// Today only [FakeFriendsRepository] implements it. The Supabase version
/// calls the same-named RPCs once they exist, and nothing above this layer
/// should need to change.
abstract interface class FriendsRepository {
  Future<Result<MyProfile>> getMyProfile();

  Future<Result<MyProfile>> updateProfile({
    String? nickname,
    int? avatarPreset,
    bool? showInOrgList,
  });

  /// [localPath] is an already square-cropped, 512px JPEG on the device.
  Future<Result<MyProfile>> setAvatarPhoto(String localPath);

  Future<Result<MyProfile>> clearAvatarPhoto();

  /// Clears the "your nickname / photo was removed" notice once shown.
  Future<Result<void>> acknowledgeRemovals();

  Future<Result<MyProfile>> rotateFriendCode();

  Future<Result<List<Friend>>> getFriends();

  Future<Result<QrToken>> createQrToken();

  Future<Result<FriendProfile>> previewByQr(String token);

  Future<Result<FriendProfile>> previewByCode(String code);

  /// [ref] is the QR token, the friend code, or (for [FriendSource.org]) the
  /// user id of someone on a shared org list.
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
