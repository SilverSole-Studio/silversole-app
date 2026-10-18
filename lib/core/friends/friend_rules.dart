import 'package:silversole/core/friends/friend_models.dart';

// Limits from the friends spec (§3, §4, §6). Every number marked 「待調」 there
// is a first guess; keep them here so tuning is a one-line change.

const kFriendLimit = 100;
const kOrgLimit = 3;
const kPendingOutLimit = 20;
const kAvatarPresetCount = 12;

const kQrTokenTtl = Duration(minutes: 5);
const kRequestTtl = Duration(days: 7);
const kDeclineCooldown = Duration(days: 30);

const kDailyLookups = 20;
const kFailedLookupStreak = 5;
const kLookupLock = Duration(minutes: 10);

const kNicknameMinLength = 2;
const kNicknameMaxLength = 8;
const kNicknameChangesPerDay = 3;

const kPhotoRemovalsBeforeBan = 3;
const kPhotoUploadBan = Duration(days: 30);

/// What a taken-down nickname is replaced with until the user picks a new one.
const kRemovedNicknamePlaceholder = '銀足朋友';

const kCodeLength = 8;

/// Every way a friends call can fail. The UI shows `friends_err_<name>.tr()`
/// and never the raw code (spec §8.3).
enum FriendError {
  notFound,
  qrExpired,
  limitReached,
  cooldown,
  friendLimit,
  orgLimit,
  pendingLimit,
  locked,
  nicknameInvalid,
  nicknameChangeLimit,
  uploadBanned,
  offline,
}

class FriendException implements Exception {
  const FriendException(this.code);

  final FriendError code;

  /// Translation key for the message shown to the user.
  String get messageKey => 'friends_err_${code.name}';

  @override
  String toString() => 'FriendException(${code.name})';
}

final _hasLetterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Null when [raw] is a usable nickname: 2–8 characters after trimming and
/// not made of symbols alone.
FriendError? validateNickname(String raw) {
  final name = raw.trim();
  final length = name.runes.length;
  if (length < kNicknameMinLength || length > kNicknameMaxLength) {
    return FriendError.nicknameInvalid;
  }
  if (!_hasLetterOrDigit.hasMatch(name)) return FriendError.nicknameInvalid;
  return null;
}

/// True for an 8-digit friend or org code. Codes never start with 0, so a
/// leading 0 is a typo rather than a valid code.
bool isWellFormedCode(String code) =>
    code.length == kCodeLength && RegExp(r'^[1-9]\d{7}$').hasMatch(code);

/// `38152704` → `3815 2704`, the way it is read out over the phone.
String formatCode(String code) {
  if (code.length <= 4) return code;
  return '${code.substring(0, 4)} ${code.substring(4)}';
}

// ── QR payloads ────────────────────────────────────────────────────────────
//
// Read only by the in-app scanner; there are no deep links. A person's QR
// carries a short-lived token, an org poster carries the org's join code.

const _personQrPrefix = 'SSF1:';
const _orgQrPrefix = 'SSO1:';

String personQrPayload(String token) => '$_personQrPrefix$token';

String orgQrPayload(String joinCode) => '$_orgQrPrefix$joinCode';

sealed class ScannedQr {
  const ScannedQr();

  static ScannedQr parse(String raw) {
    final text = raw.trim();
    if (text.startsWith(_personQrPrefix)) {
      final token = text.substring(_personQrPrefix.length);
      if (token.isNotEmpty) return PersonQr(token);
    }
    if (text.startsWith(_orgQrPrefix)) {
      final code = text.substring(_orgQrPrefix.length);
      if (isWellFormedCode(code)) return OrgQr(code);
    }
    return const UnknownQr();
  }
}

final class PersonQr extends ScannedQr {
  const PersonQr(this.token);
  final String token;
}

final class OrgQr extends ScannedQr {
  const OrgQr(this.joinCode);
  final String joinCode;
}

final class UnknownQr extends ScannedQr {
  const UnknownQr();
}

/// Friend list order (spec §4.1): most recent interaction first, then the
/// newest friendship.
int compareFriends(Friend a, Friend b) {
  final ai = a.lastInteractionAt;
  final bi = b.lastInteractionAt;
  if (ai != null && bi != null && ai != bi) return bi.compareTo(ai);
  if (ai != null && bi == null) return -1;
  if (ai == null && bi != null) return 1;
  return b.since.compareTo(a.since);
}
