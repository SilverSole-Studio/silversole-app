// Value types for the friends system. They mirror what the RPCs in the spec
// return (動域科技/02_產品/鞋墊_SilverSole/_好友系統規格書_2026-10-18.md §8.2),
// so the Supabase implementation can map rows straight onto them.

/// How two people are related. Only [friend] exists for now; [family] is kept
/// so the garden can already branch on it once the family feature lands.
enum FriendRelation { friend, family }

/// Which of the three routes a friendship or request came through.
enum FriendSource { qr, code, org }

enum OrgKind { communityCenter, dayCare, other }

/// Where the viewer stands with someone on an org's member list.
enum OrgMemberStatus { friend, pendingOut, pendingIn, none }

enum FriendRequestAction { accept, decline, declineAndBlock }

enum SendRequestOutcome { sent, becameFriends, alreadyFriends }

enum ReportKind { photo, nickname }

enum ReportReason { indecent, violent, impersonation, ads, other }

/// Another person as the viewer is allowed to see them.
///
/// [photoPath] is only ever filled for a friend: on the org list, in a code or
/// QR preview, and on a pending request the server hands out the preset
/// mascot alone (spec §2.2).
class FriendProfile {
  const FriendProfile({
    required this.userId,
    required this.nickname,
    required this.avatarPreset,
    this.photoPath,
  });

  final String userId;
  final String nickname;

  /// 1-based index into the preset mascot avatars.
  final int avatarPreset;
  final String? photoPath;
}

/// The signed-in user's own profile.
class MyProfile {
  const MyProfile({
    required this.userId,
    required this.nickname,
    required this.avatarPreset,
    required this.friendCode,
    required this.showInOrgList,
    this.photoPath,
    this.photoUploadBannedUntil,
    this.nicknameWasRemoved = false,
    this.photoWasRemoved = false,
  });

  final String userId;

  /// Null until the first visit to the friends page sets one.
  final String? nickname;
  final int avatarPreset;
  final String? photoPath;

  /// 8 digits, never starting with 0.
  final String friendCode;
  final bool showInOrgList;
  final DateTime? photoUploadBannedUntil;

  /// Set when 動域 took down a reported nickname or photo; the app tells the
  /// user once, then clears it.
  final bool nicknameWasRemoved;
  final bool photoWasRemoved;

  bool get needsSetup => nickname == null;

  FriendProfile get asSeenByFriends => FriendProfile(
    userId: userId,
    nickname: nickname ?? '',
    avatarPreset: avatarPreset,
    photoPath: photoPath,
  );
}

class Friend {
  const Friend({
    required this.profile,
    required this.relation,
    required this.since,
    this.lastInteractionAt,
  });

  final FriendProfile profile;
  final FriendRelation relation;
  final DateTime since;
  final DateTime? lastInteractionAt;
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.other,
    required this.incoming,
    required this.source,
    required this.createdAt,
    required this.expiresAt,
    this.orgName,
  });

  final String id;

  /// The other side — sender when [incoming], recipient otherwise.
  final FriendProfile other;
  final bool incoming;
  final FriendSource source;
  final String? orgName;
  final DateTime createdAt;
  final DateTime expiresAt;
}

class QrToken {
  const QrToken({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

class OrgSummary {
  const OrgSummary({required this.id, required this.name, required this.kind});

  final String id;
  final String name;
  final OrgKind kind;
}

class OrgMember {
  const OrgMember({required this.profile, required this.status});

  final FriendProfile profile;
  final OrgMemberStatus status;
}
