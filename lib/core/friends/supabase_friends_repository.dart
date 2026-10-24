import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/friends/friends_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Private bucket for uploaded avatar photos (spec §7.3). Its SELECT policy
/// only lets a user sign their own folder and a friend's current photo.
const avatarsBucket = 'avatars';

/// How long a signed photo URL stays valid (spec §6: one hour).
const _signedUrlTtlSeconds = 3600;

/// The friends backend on Supabase: one method per RPC in
/// `supabase/migrations/20261019120000_friends.sql`.
///
/// The RPCs report failures either by raising the spec's error code as the
/// exception message (`not_found`, `limit_reached`, …) or, where a raise
/// would roll back the lookup counters, by returning `{"error": code}`. Both
/// become a [FriendException]. Anything that never reached the server is
/// [FriendError.offline].
///
/// Photos come back from the RPCs as storage paths; this class swaps them for
/// one-hour signed URLs before they reach the UI.
class SupabaseFriendsRepository implements FriendsRepository {
  SupabaseFriendsRepository(this._client);

  final SupabaseClient _client;

  // ── Profile ────────────────────────────────────────────────────────────

  @override
  Future<Result<MyProfile>> getMyProfile() =>
      _guard(() async => _myProfile(await _rpc('get_my_profile')));

  @override
  Future<Result<MyProfile>> updateProfile({
    String? nickname,
    int? avatarPreset,
    bool? showInOrgList,
  }) => _guard(() async {
    final invalid = nickname == null ? null : validateNickname(nickname);
    if (invalid != null) throw FriendException(invalid);
    return _myProfile(
      await _rpc('update_profile', {
        'p_nickname': nickname == null ? null : trimNickname(nickname),
        'p_avatar_preset': avatarPreset,
        'p_show_in_org_list': showInOrgList,
      }),
    );
  });

  @override
  Future<Result<MyProfile>> setAvatarPhoto(String localPath) => _guard(
    () async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const FriendException(FriendError.unknown);
      final file = File(localPath);
      // The picker may hand back a PNG or WebP as it found it; send what
      // the file really is.
      final type = avatarImageType(await _head(file));
      if (type == null) throw const FriendException(FriendError.uploadFailed);
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.${type.extension}';
      try {
        await _client.storage
            .from(avatarsBucket)
            .upload(
              path,
              file,
              fileOptions: FileOptions(contentType: type.mimeType),
            );
      } on StorageException catch (e) {
        debugPrint('[friends] avatar upload: ${e.statusCode} ${e.message}');
        throw FriendException(await _uploadError(e));
      }
      return _myProfile(await _rpc('set_avatar_photo', {'p_path': path}));
    },
  );

  @override
  Future<Result<MyProfile>> clearAvatarPhoto() =>
      _guard(() async => _myProfile(await _rpc('clear_avatar_photo')));

  @override
  Future<Result<void>> acknowledgeRemovals() =>
      _guard(() => _rpc('acknowledge_removals'));

  @override
  Future<Result<MyProfile>> rotateFriendCode() =>
      _guard(() async => _myProfile(await _rpc('rotate_friend_code')));

  // ── Friends ────────────────────────────────────────────────────────────

  @override
  Future<Result<List<Friend>>> getFriends() => _guard(() async {
    final rows = _list(await _rpc('get_friends'));
    final urls = await _signPhotos(rows);
    return [
      for (final r in rows)
        Friend(
          profile: _profile(r, photoUrls: urls),
          relation: FriendRelation.friend,
          since: _time(r['since'])!,
          lastInteractionAt: _time(r['last_interaction_at']),
        ),
    ];
  });

  @override
  Future<Result<void>> removeFriend(String userId) =>
      _guard(() => _rpc('remove_friend', {'p_other': userId}));

  @override
  Future<Result<void>> blockUser(String userId) =>
      _guard(() => _rpc('block_user', {'p_other': userId}));

  @override
  Future<Result<void>> unblockUser(String userId) =>
      _guard(() => _rpc('unblock_user', {'p_other': userId}));

  @override
  Future<Result<List<FriendProfile>>> getBlocked() => _guard(
    () async => _list(await _rpc('get_blocked')).map(_profile).toList(),
  );

  // ── Finding someone ────────────────────────────────────────────────────

  @override
  Future<Result<QrToken>> createQrToken() => _guard(() async {
    final r = _map(await _rpc('create_qr_token'));
    return QrToken(
      token: r['token'] as String,
      expiresAt: _time(r['expires_at'])!,
    );
  });

  @override
  Future<Result<FriendProfile>> previewByQr(String token) => _guard(
    () async => _profile(_map(await _rpc('preview_by_qr', {'p_token': token}))),
  );

  @override
  Future<Result<FriendProfile>> previewByCode(String code) => _guard(
    () async => _profile(_map(await _rpc('preview_by_code', {'p_code': code}))),
  );

  @override
  Future<Result<SendRequestOutcome>> sendFriendRequest(
    FriendSource source,
    String ref,
  ) => _guard(() async {
    final r = _map(
      await _rpc('send_friend_request', {
        'p_source': source.name,
        'p_ref': ref,
      }),
    );
    return switch (r['result']) {
      'became_friends' => SendRequestOutcome.becameFriends,
      'already_friends' => SendRequestOutcome.alreadyFriends,
      _ => SendRequestOutcome.sent,
    };
  });

  // ── Requests ───────────────────────────────────────────────────────────

  @override
  Future<Result<List<FriendRequest>>> getFriendRequests() => _guard(
    () async => [
      for (final r in _list(await _rpc('get_friend_requests')))
        FriendRequest(
          id: r['id'] as String,
          other: _profile(_map(r['other'])),
          incoming: r['incoming'] as bool,
          source: _source(r['source']),
          orgName: r['org_name'] as String?,
          createdAt: _time(r['created_at'])!,
          expiresAt: _time(r['expires_at'])!,
        ),
    ],
  );

  @override
  Future<Result<void>> respondFriendRequest(
    String requestId,
    FriendRequestAction action,
  ) => _guard(
    () => _rpc('respond_friend_request', {
      'p_id': requestId,
      'p_action': switch (action) {
        FriendRequestAction.accept => 'accept',
        FriendRequestAction.decline => 'decline',
        FriendRequestAction.declineAndBlock => 'decline_and_block',
      },
    }),
  );

  @override
  Future<Result<void>> cancelFriendRequest(String requestId) =>
      _guard(() => _rpc('cancel_friend_request', {'p_id': requestId}));

  // ── Orgs ───────────────────────────────────────────────────────────────

  @override
  Future<Result<OrgSummary>> previewOrg(String joinCode) => _guard(
    () async => _org(_map(await _rpc('preview_org', {'p_code': joinCode}))),
  );

  @override
  Future<Result<OrgSummary>> joinOrg(String joinCode) => _guard(
    () async => _org(_map(await _rpc('join_org', {'p_code': joinCode}))),
  );

  @override
  Future<Result<void>> leaveOrg(String orgId) =>
      _guard(() => _rpc('leave_org', {'p_org_id': orgId}));

  @override
  Future<Result<List<OrgSummary>>> getMyOrgs() =>
      _guard(() async => _list(await _rpc('get_my_orgs')).map(_org).toList());

  @override
  Future<Result<List<OrgMember>>> getOrgMembers(String orgId) => _guard(
    () async => [
      for (final r in _list(await _rpc('get_org_members', {'p_org_id': orgId})))
        OrgMember(
          profile: _profile(r),
          status: switch (r['status']) {
            'friend' => OrgMemberStatus.friend,
            'pending_out' => OrgMemberStatus.pendingOut,
            'pending_in' => OrgMemberStatus.pendingIn,
            _ => OrgMemberStatus.none,
          },
        ),
    ],
  );

  // ── Reports ────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> reportProfile(
    String userId,
    ReportKind kind,
    ReportReason reason,
  ) => _guard(
    () => _rpc('report_profile', {
      'p_target': userId,
      'p_kind': kind.name,
      'p_reason': reason.name,
    }),
  );

  // ── Internals ──────────────────────────────────────────────────────────

  /// Server error codes (spec §8.3) → [FriendError].
  static const _errors = {
    'not_found': FriendError.notFound,
    'qr_expired': FriendError.qrExpired,
    'limit_reached': FriendError.limitReached,
    'cooldown': FriendError.cooldown,
    'friend_limit': FriendError.friendLimit,
    'other_friend_limit': FriendError.otherFriendLimit,
    'org_limit': FriendError.orgLimit,
    'pending_limit': FriendError.pendingLimit,
    'locked': FriendError.locked,
    'nickname_invalid': FriendError.nicknameInvalid,
    'nickname_change_limit': FriendError.nicknameChangeLimit,
    'upload_banned': FriendError.uploadBanned,
  };

  /// The upload policy (403) refuses a banned user and a sixth photo in a
  /// day; the profile tells those two apart. Anything else — too big, a
  /// type the bucket does not take, a server hiccup — is a failed upload.
  Future<FriendError> _uploadError(StorageException e) async {
    if (e.statusCode != '403') return FriendError.uploadFailed;
    final me = await _myProfile(await _rpc('get_my_profile'));
    final bannedUntil = me.photoUploadBannedUntil;
    final banned = bannedUntil != null && DateTime.now().isBefore(bannedUntil);
    return banned ? FriendError.uploadBanned : FriendError.limitReached;
  }

  static Future<List<int>> _head(File file) async {
    final bytes = <int>[];
    await for (final chunk in file.openRead(0, 16)) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  /// Calls [fn] and returns its JSON, turning a returned `{"error": code}`
  /// into a [FriendException].
  Future<dynamic> _rpc(String fn, [Map<String, dynamic>? params]) async {
    final data = await _client.rpc(fn, params: params);
    if (data is Map && data['error'] is String) {
      throw FriendException(_errors[data['error']] ?? FriendError.unknown);
    }
    return data;
  }

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Result.ok(await body());
    } on FriendException catch (e) {
      return Result.error(e);
    } on PostgrestException catch (e) {
      final code = _errors[e.message];
      if (code == null) debugPrint('[friends] ${e.code}: ${e.message}');
      return Result.error(FriendException(code ?? FriendError.unknown));
    } catch (e) {
      // Everything else never got an answer from the server.
      debugPrint('[friends] $e');
      return const Result.error(FriendException(FriendError.offline));
    }
  }

  /// Signed URLs for the photo paths in [rows], keyed by path. A photo that
  /// cannot be signed (just removed, or no longer a friend) is left out and
  /// shows the mascot instead.
  Future<Map<String, String>> _signPhotos(
    List<Map<String, dynamic>> rows,
  ) async {
    final paths = [
      for (final r in rows)
        if (r['avatar_path'] case final String path) path,
    ];
    if (paths.isEmpty) return const {};
    try {
      final signed = await _client.storage
          .from(avatarsBucket)
          .createSignedUrls(paths, _signedUrlTtlSeconds);
      return signedPhotoUrls(signed);
    } on StorageException catch (e) {
      debugPrint('[friends] sign photos: ${e.statusCode} ${e.message}');
      return const {};
    }
  }

  /// Path → URL for the photos storage agreed to sign. One it refused (just
  /// removed, or no longer a friend's) comes back with an empty path or a
  /// URL ending in `null`; it is left out, so the preset mascot shows.
  @visibleForTesting
  static Map<String, String> signedPhotoUrls(List<SignedUrl> signed) => {
    for (final s in signed)
      if (s.path.isNotEmpty && !s.signedUrl.endsWith('null'))
        s.path: s.signedUrl,
  };

  Future<MyProfile> _myProfile(dynamic data) async {
    final r = _map(data);
    final path = r['avatar_path'] as String?;
    final urls = path == null
        ? const <String, String>{}
        : await _signPhotos([r]);
    return MyProfile(
      userId: r['user_id'] as String,
      nickname: r['nickname'] as String?,
      avatarPreset: r['avatar_preset'] as int,
      photoPath: path == null ? null : urls[path],
      friendCode: r['friend_code'] as String,
      showInOrgList: r['show_in_org_list'] as bool,
      photoUploadBannedUntil: _time(r['avatar_upload_banned_until']),
      nicknameWasRemoved: r['nickname_removed'] as bool? ?? false,
      photoWasRemoved: r['avatar_removed'] as bool? ?? false,
    );
  }

  /// Someone else as the RPC returned them. Only `get_friends` carries an
  /// `avatar_path`, and only then is [photoUrls] passed.
  static FriendProfile _profile(
    Map<String, dynamic> r, {
    Map<String, String> photoUrls = const {},
  }) => FriendProfile(
    userId: r['user_id'] as String,
    nickname: r['nickname'] as String? ?? kRemovedNicknamePlaceholder,
    avatarPreset: r['avatar_preset'] as int,
    photoPath: photoUrls[r['avatar_path']],
  );

  static OrgSummary _org(Map<String, dynamic> r) => OrgSummary(
    id: r['id'] as String,
    name: r['name'] as String,
    kind: switch (r['kind']) {
      'community_center' => OrgKind.communityCenter,
      'day_care' => OrgKind.dayCare,
      _ => OrgKind.other,
    },
  );

  static FriendSource _source(Object? raw) => FriendSource.values.firstWhere(
    (s) => s.name == raw,
    orElse: () => FriendSource.code,
  );

  static Map<String, dynamic> _map(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  static List<Map<String, dynamic>> _list(dynamic data) => [
    for (final row in (data as List? ?? const [])) _map(row),
  ];

  static DateTime? _time(Object? raw) =>
      raw is String ? DateTime.parse(raw).toLocal() : null;
}
