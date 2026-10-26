import 'package:silversole/core/friends/friend_models.dart';

// Limits from the friends spec (§3, §4, §6). Every number marked 「待調」 there
// is a first guess; keep them here so tuning is a one-line change.

const kFriendLimit = 100;
const kOrgLimit = 3;
const kPendingOutLimit = 20;
const kAvatarPresetCount = 12;

const kQrTokenTtl = Duration(minutes: 5);

/// How long after a QR token expires a request can still be sent through it,
/// as long as the sender previewed it before it expired — so someone who
/// scanned at 4:59 is not turned away while reading the name.
const kQrPreviewGrace = Duration(seconds: 60);
const kRequestTtl = Duration(days: 7);
const kDeclineCooldown = Duration(days: 30);

const kDailyLookups = 20;
const kFailedLookupStreak = 5;
const kLookupLock = Duration(minutes: 10);

const kNicknameMinLength = 2;
const kNicknameMaxLength = 8;
const kNicknameChangesPerDay = 3;

const kPhotoUploadsPerDay = 5;
const kReportsPerDay = 10;

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

  /// The other person already has [kFriendLimit] friends.
  otherFriendLimit,
  orgLimit,
  pendingLimit,
  locked,
  nicknameInvalid,
  nicknameChangeLimit,
  uploadBanned,

  /// 30 requests sent today (cancelled ones count too).
  sendLimit,

  /// Too many calls in a short time; try again in a moment.
  rateLimited,

  /// The photo did not reach storage for a reason other than the upload
  /// rules (network, size, file type).
  uploadFailed,
  offline,

  /// The server refused for a reason the app has no message for.
  unknown,
}

class FriendException implements Exception {
  const FriendException(this.code);

  final FriendError code;

  /// Translation key for the message shown to the user; see
  /// [friendErrorKey] for wording that depends on what they were doing.
  String get messageKey => friendErrorKey(code);

  @override
  String toString() => 'FriendException(${code.name})';
}

/// The same whitelist as `friends_clean_nickname()` in the SQL migration:
/// Latin, Greek, Cyrillic, Thai, kana, bopomofo, CJK, Hangul and full-width
/// letters and digits. Keep the two in step.
final _nicknameLetter = RegExp(
  r'[0-9A-Za-zÀ-ɏͰ-ϿЀ-ӿ฀-๿'
  r'぀-ヿ㄀-ㄯ㐀-䶿一-鿿'
  r'가-힯豈-﫿０-９Ａ-Ｚａ-ｚ]',
);
final _controlChar = RegExp(r'[\u0001-\u001F\u007F]');

/// Invisible and direction-changing characters (zero-width, bidi controls,
/// fillers, combining marks). The server's whitelist refuses them too; this
/// gives the same answer before the call.
final _invisibleChar = RegExp(
  r'[\u00AD\u0300-\u036F\u034F\u061C\u115F\u1160\u17B4\u17B5\u180B-\u180F'
  r'\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFEFF\uFFA0]',
);

/// Names nobody can take: the one a taken-down nickname turns into, the
/// brand, and anything that looks like staff (same list as the server's
/// `friend_reserved_names`). Compared without spaces or symbols, lower case,
/// full-width letters folded.
const _reservedInName = [
  '銀足',
  'silversole',
  '官方',
  '客服',
  '管理員',
  '管理者',
  '系統',
  '動域',
  'admin',
  'support',
];
const _reservedWholeName = ['粗哥'];

String _reservedKey(String name) {
  final folded = String.fromCharCodes(
    name.runes.map((r) => r >= 0xFF01 && r <= 0xFF5E ? r - 0xFEE0 : r),
  );
  return folded.replaceAll(RegExp(r'[\s　·・\-_.~～!！?？♥♡★☆]'), '').toLowerCase();
}

bool _isReservedNickname(String name) {
  final key = _reservedKey(name);
  return _reservedInName.any(key.contains) || _reservedWholeName.contains(key);
}

final _edgeSpace = RegExp(r'^[\s　]+|[\s　]+$');

/// [raw] trimmed the way the server trims it (spaces, including the
/// full-width one).
String trimNickname(String raw) => raw.replaceAll(_edgeSpace, '');

/// Null when [raw] is a usable nickname — the same check as the server's
/// `friends_clean_nickname()`: 2–8 characters after trimming, no control
/// characters, and at least one letter or digit from the whitelist.
FriendError? validateNickname(String raw) {
  final name = trimNickname(raw);
  final length = name.runes.length;
  if (length < kNicknameMinLength || length > kNicknameMaxLength) {
    return FriendError.nicknameInvalid;
  }
  if (_controlChar.hasMatch(name) ||
      _invisibleChar.hasMatch(name) ||
      !_nicknameLetter.hasMatch(name) ||
      _isReservedNickname(name)) {
    return FriendError.nicknameInvalid;
  }
  return null;
}

/// Where a friends call failed, so the same server code can be worded for
/// what the person was doing: a missing QR, centre, request or report target
/// is not 「找不到這個號碼」.
enum FriendErrorScope {
  /// Typing a friend code (and anything without a better wording).
  code,

  /// Scanning someone's QR, or adding them from it.
  qr,

  /// A centre's code or poster, or joining it.
  org,

  /// Adding someone from a centre's member list.
  orgMember,

  /// Answering or withdrawing a friend request.
  request,

  /// Reporting a photo or nickname.
  report,

  /// Picking one of the preset avatars.
  avatar,

  /// Uploading a photo.
  photo,
}

/// Translation key for [code] as seen while doing [scope].
String friendErrorKey(
  FriendError code, [
  FriendErrorScope scope = FriendErrorScope.code,
]) => switch ((code, scope)) {
  (FriendError.notFound, FriendErrorScope.qr) => 'friends_err_notFound_qr',
  (FriendError.notFound, FriendErrorScope.org) => 'friends_err_notFound_org',
  (FriendError.notFound, FriendErrorScope.orgMember) =>
    'friends_err_notFound_person',
  (FriendError.notFound, FriendErrorScope.request) =>
    'friends_err_notFound_request',
  (FriendError.notFound, FriendErrorScope.report) =>
    'friends_err_notFound_report',
  (FriendError.notFound, FriendErrorScope.avatar) =>
    'friends_err_notFound_avatar',
  // set_avatar_photo answers not_found when the file never landed.
  (FriendError.notFound, FriendErrorScope.photo) => 'friends_err_uploadFailed',
  (FriendError.limitReached, FriendErrorScope.photo) =>
    'friends_err_limitReached_photo',
  (FriendError.limitReached, FriendErrorScope.report) =>
    'friends_err_limitReached_report',
  _ => 'friends_err_${code.name}',
};

/// What an avatar file really is, read from its first bytes (a picked file's
/// name and the picker's mime type are not reliable). Null for anything the
/// avatars bucket does not take.
({String mimeType, String extension})? avatarImageType(List<int> head) {
  bool startsWith(List<int> magic, [int at = 0]) {
    if (head.length < at + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (head[at + i] != magic[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) {
    return (mimeType: 'image/jpeg', extension: 'jpg');
  }
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return (mimeType: 'image/png', extension: 'png');
  }
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return (mimeType: 'image/webp', extension: 'webp');
  }
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
