import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/friends/friends_repository.dart';

/// In-memory stand-in for the friends backend, seen from one signed-in user.
///
/// It plays the server's part of the spec (§3, §4, §6): consent on every
/// route, silent blocking, the rate limits and cooldowns, org visibility. The
/// UI runs on it until the Supabase RPCs exist, and its tests double as the
/// checklist those RPCs have to pass (spec §10).
///
/// Time comes from `package:clock`, so tests can move it with `withClock`.
class FakeFriendsRepository implements FriendsRepository {
  FakeFriendsRepository({
    this.meId = 'me',
    String myFriendCode = '27183145',
    this.latency = Duration.zero,
    this.simulateQrScan = false,
    Random? random,
  }) : _random = random ?? Random() {
    _users[meId] = _FakeUser(
      id: meId,
      nickname: null,
      avatarPreset: 1,
      friendCode: myFriendCode,
    );
  }

  /// Demo data: a handful of friends, two incoming requests, one org with a
  /// mixed member list, someone already blocked — and no nickname yet, so the
  /// first-run setup shows.
  factory FakeFriendsRepository.seeded({
    Duration latency = const Duration(milliseconds: 250),
    bool simulateQrScan = true,
  }) {
    final repo = FakeFriendsRepository(
      latency: latency,
      simulateQrScan: simulateQrScan,
    );
    final now = clock.now();
    repo
      ..addUser('u_chen', '陳伯伯', preset: 3, code: '31415926')
      ..addUser('u_lin', '林阿嬤', preset: 10, code: '41421356')
      ..addUser('u_mei', '小美', preset: 2, code: '16180339')
      ..addUser('u_hsiung', '阿雄', preset: 5, code: '57721566')
      ..addUser('u_chang', '張阿姨', preset: 7, code: '17320508')
      ..addUser('u_huang', '黃伯伯', preset: 9, code: '26457513')
      ..addUser('u_li', '李伯伯', preset: 4, code: demoFriendCode)
      ..addUser('u_wu', '吳奶奶', preset: 11, code: '30277563')
      ..addUser(
        'u_tsai',
        '蔡阿公',
        preset: 6,
        code: '44721359',
        showInOrgList: false,
      )
      ..addUser('u_kuo', '郭大哥', preset: 8, code: '24494897')
      ..addUser('u_spam', '好康報報', preset: 12, code: '98765432')
      ..addFriendship(
        'u_chen',
        since: now.subtract(const Duration(days: 20)),
        lastInteraction: now.subtract(const Duration(hours: 1)),
      )
      ..addFriendship(
        'u_mei',
        since: now.subtract(const Duration(days: 9)),
        lastInteraction: now.subtract(const Duration(days: 1)),
      )
      ..addFriendship('u_lin', since: now.subtract(const Duration(days: 30)))
      ..addFriendship('u_hsiung', since: now.subtract(const Duration(days: 3)))
      ..addIncomingRequest(
        'u_chang',
        FriendSource.code,
        at: now.subtract(const Duration(days: 1)),
      )
      ..addOrg('org_sanxia', '三峽示範據點', OrgKind.communityCenter, '52013140')
      ..addOrg('org_yingge', '鶯歌日照中心', OrgKind.dayCare, demoOrgCode)
      ..addOrgMember('org_sanxia', repo.meId)
      ..addOrgMember('org_sanxia', 'u_chen')
      ..addOrgMember('org_sanxia', 'u_huang')
      ..addOrgMember('org_sanxia', 'u_wu')
      ..addOrgMember('org_sanxia', 'u_tsai')
      ..addOrgMember('org_sanxia', 'u_kuo')
      ..addOrgMember('org_sanxia', 'u_spam')
      ..addOrgMember('org_yingge', 'u_lin')
      ..addOrgMember('org_yingge', 'u_wu')
      ..addIncomingRequest(
        'u_huang',
        FriendSource.org,
        orgId: 'org_sanxia',
        at: now.subtract(const Duration(hours: 3)),
      )
      ..addOutgoingRequest(
        'u_kuo',
        FriendSource.org,
        orgId: 'org_sanxia',
        at: now.subtract(const Duration(days: 2)),
      )
      ..addBlock(repo.meId, 'u_spam');
    return repo;
  }

  /// Codes that work in the seeded demo, shown on a debug-only hint.
  static const demoFriendCode = '22360679';
  static const demoOrgCode = '66881234';

  /// Who "scans" the QR shown by [createQrToken] in the demo.
  static const _demoScannerId = 'u_li';
  static const _demoScanDelay = Duration(seconds: 6);

  final String meId;
  final Duration latency;
  final bool simulateQrScan;
  final Random _random;

  final _users = <String, _FakeUser>{};
  final _friendships = <String, _Friendship>{};
  final _requests = <_Request>[];
  final _blocks = <(String, String)>{};
  final _orgs = <String, _Org>{};
  final _members = <String, Set<String>>{};
  final _declinedAt = <(String, String), DateTime>{};
  final _qrTokens = <String, _QrToken>{};
  final _previewedCodes = <String>{};

  /// Reports sent by me, for tests.
  final reports = <(String, ReportKind, ReportReason)>[];

  // Per-day counters for me (the server keeps these in friend_daily_limits).
  DateTime? _limitsDay;
  int _lookupsToday = 0;
  int _nicknameChangesToday = 0;
  int _reportsToday = 0;
  int _failedLookupStreak = 0;
  DateTime? _lookupsLockedUntil;
  int _requestSeq = 0;
  Timer? _demoScanTimer;

  _FakeUser get _me => _users[meId]!;

  // ── Seeding and admin hooks (tests and demo only) ──────────────────────

  void addUser(
    String id,
    String nickname, {
    required int preset,
    required String code,
    String? photoPath,
    bool showInOrgList = true,
  }) {
    _users[id] = _FakeUser(
      id: id,
      nickname: nickname,
      avatarPreset: preset,
      friendCode: code,
      photoPath: photoPath,
      showInOrgList: showInOrgList,
    );
  }

  void addFriendship(
    String other, {
    String? of,
    DateTime? since,
    DateTime? lastInteraction,
    FriendSource source = FriendSource.code,
  }) {
    final a = of ?? meId;
    _friendships[_pairKey(a, other)] = _Friendship(
      a,
      other,
      source,
      since ?? clock.now(),
      lastInteraction,
    );
  }

  void addIncomingRequest(
    String from,
    FriendSource source, {
    String? orgId,
    DateTime? at,
  }) => _addRequest(from, meId, source, orgId: orgId, at: at);

  void addOutgoingRequest(
    String to,
    FriendSource source, {
    String? orgId,
    DateTime? at,
  }) => _addRequest(meId, to, source, orgId: orgId, at: at);

  void addBlock(String blocker, String blocked) {
    _blocks.add((blocker, blocked));
    _friendships.remove(_pairKey(blocker, blocked));
    _requests.removeWhere(
      (r) => _isBetween(r, blocker, blocked) && r.isOpenFor(clock.now()),
    );
  }

  void addOrg(String id, String name, OrgKind kind, String joinCode) {
    _orgs[id] = _Org(id, name, kind, joinCode);
    _members.putIfAbsent(id, () => {});
  }

  void addOrgMember(String orgId, String userId) =>
      _members[orgId]!.add(userId);

  /// Someone else's QR token, as if they had opened "my QR".
  void addQrToken(String userId, String token, DateTime expiresAt) =>
      _qrTokens[token] = _QrToken(userId, expiresAt);

  /// [userId] quietly declines the request I sent them.
  void declineAs(String userId) {
    final r = _openRequest(from: meId, to: userId);
    if (r != null) _decline(r);
  }

  /// 動域 took down a reported nickname (spec §2.3).
  void adminRemoveNickname(String userId) {
    final u = _users[userId]!;
    u.nickname = kRemovedNicknamePlaceholder;
    u.nicknameWasRemoved = true;
  }

  /// 動域 took down a reported photo; the third time bans uploads for 30 days.
  void adminRemovePhoto(String userId) {
    final u = _users[userId]!;
    u.photoPath = null;
    u.photoWasRemoved = true;
    u.photoRemovals++;
    if (u.photoRemovals >= kPhotoRemovalsBeforeBan) {
      u.photoUploadBannedUntil = clock.now().add(kPhotoUploadBan);
    }
  }

  /// Server-side only (spec §8.1) — not reachable from the app.
  bool areFriends(String a, String b) =>
      _friendships.containsKey(_pairKey(a, b)) && !_blockedEitherWay(a, b);

  int friendCount(String userId) => _friendships.values
      .where((f) => f.a == userId || f.b == userId)
      .where((f) => !_blockedEitherWay(f.a, f.b))
      .length;

  void dispose() => _demoScanTimer?.cancel();

  // ── Profile ────────────────────────────────────────────────────────────

  @override
  Future<Result<MyProfile>> getMyProfile() => _respond(() => _myProfile());

  @override
  Future<Result<MyProfile>> updateProfile({
    String? nickname,
    int? avatarPreset,
    bool? showInOrgList,
  }) => _respond(() {
    final me = _me;
    if (nickname != null) {
      final trimmed = nickname.trim();
      final invalid = validateNickname(trimmed);
      if (invalid != null) throw FriendException(invalid);
      if (trimmed != me.nickname) {
        // Choosing the first name, or replacing one 動域 took down, is free.
        final counts = me.nickname != null && !me.nicknameWasRemoved;
        if (counts) {
          _rollDay();
          if (_nicknameChangesToday >= kNicknameChangesPerDay) {
            throw const FriendException(FriendError.nicknameChangeLimit);
          }
          _nicknameChangesToday++;
        }
        me.nickname = trimmed;
        me.nicknameWasRemoved = false;
      }
    }
    if (avatarPreset != null) {
      if (avatarPreset < 1 || avatarPreset > kAvatarPresetCount) {
        throw const FriendException(FriendError.notFound);
      }
      me.avatarPreset = avatarPreset;
    }
    if (showInOrgList != null) me.showInOrgList = showInOrgList;
    return _myProfile();
  });

  @override
  Future<Result<MyProfile>> setAvatarPhoto(String localPath) => _respond(() {
    final bannedUntil = _me.photoUploadBannedUntil;
    if (bannedUntil != null && clock.now().isBefore(bannedUntil)) {
      throw const FriendException(FriendError.uploadBanned);
    }
    _me.photoPath = localPath;
    return _myProfile();
  });

  @override
  Future<Result<MyProfile>> clearAvatarPhoto() => _respond(() {
    _me.photoPath = null;
    return _myProfile();
  });

  @override
  Future<Result<void>> acknowledgeRemovals() => _respond(() {
    // The nickname notice stays until a new name is chosen.
    _me.photoWasRemoved = false;
  });

  @override
  Future<Result<MyProfile>> rotateFriendCode() => _respond(() {
    _me.friendCode = _newCode();
    return _myProfile();
  });

  // ── Friends ────────────────────────────────────────────────────────────

  @override
  Future<Result<List<Friend>>> getFriends() => _respond(() {
    final friends = [
      for (final f in _friendships.values)
        if ((f.a == meId || f.b == meId) && !_blockedEitherWay(f.a, f.b))
          Friend(
            profile: _profileOf(f.other(meId), withPhoto: true),
            relation: FriendRelation.friend,
            since: f.since,
            lastInteractionAt: f.lastInteraction,
          ),
    ]..sort(compareFriends);
    return friends;
  });

  @override
  Future<Result<void>> removeFriend(String userId) => _respond(() {
    _friendships.remove(_pairKey(meId, userId));
  });

  @override
  Future<Result<void>> blockUser(String userId) => _respond(() {
    addBlock(meId, userId);
  });

  @override
  Future<Result<void>> unblockUser(String userId) => _respond(() {
    // Unblocking does not bring the friendship back (spec §4.3).
    _blocks.remove((meId, userId));
  });

  @override
  Future<Result<List<FriendProfile>>> getBlocked() => _respond(
    () => [
      for (final (blocker, blocked) in _blocks)
        if (blocker == meId) _profileOf(blocked, withPhoto: false),
    ],
  );

  // ── Finding someone ────────────────────────────────────────────────────

  @override
  Future<Result<QrToken>> createQrToken() => _respond(() {
    final token = _newToken();
    final expiresAt = clock.now().add(kQrTokenTtl);
    _qrTokens[token] = _QrToken(meId, expiresAt);
    if (simulateQrScan) _scheduleDemoScan();
    return QrToken(token: token, expiresAt: expiresAt);
  });

  @override
  Future<Result<FriendProfile>> previewByQr(String token) =>
      _respond(() => _profileOf(_resolveQr(token), withPhoto: false));

  @override
  Future<Result<FriendProfile>> previewByCode(String code) => _respond(() {
    final userId = _lookup(() => _userIdByCode(code));
    _previewedCodes.add(code);
    return _profileOf(userId, withPhoto: false);
  });

  @override
  Future<Result<SendRequestOutcome>> sendFriendRequest(
    FriendSource source,
    String ref,
  ) => _respond(() {
    String? orgId;
    final target = switch (source) {
      FriendSource.qr => _resolveQr(ref),
      // A code goes through the lookup budget unless it was just previewed,
      // so sending cannot be used to guess codes for free.
      FriendSource.code =>
        _previewedCodes.contains(ref)
            ? _userIdByCode(ref)
            : _lookup(() => _userIdByCode(ref)),
      FriendSource.org => () {
        orgId = _sharedVisibleOrg(ref);
        return ref;
      }(),
    };
    if (target == meId || _blockedEitherWay(meId, target)) {
      throw const FriendException(FriendError.notFound);
    }
    if (_friendships.containsKey(_pairKey(meId, target))) {
      return SendRequestOutcome.alreadyFriends;
    }
    if (friendCount(meId) >= kFriendLimit) {
      throw const FriendException(FriendError.friendLimit);
    }

    final now = clock.now();
    final theirs = _openRequest(from: target, to: meId);
    if (theirs != null) {
      // They already asked me: asking back is the same as saying yes.
      _accept(theirs);
      return SendRequestOutcome.becameFriends;
    }
    // Already waiting — including a request they quietly declined, which
    // must keep looking like it is still waiting.
    if (_requests.any(
      (r) => r.from == meId && r.to == target && r.isOpenFor(now),
    )) {
      return SendRequestOutcome.sent;
    }
    final declined = _declinedAt[(meId, target)];
    if (declined != null && now.difference(declined) < kDeclineCooldown) {
      throw const FriendException(FriendError.cooldown);
    }
    final pendingOut = _requests
        .where((r) => r.from == meId && r.isOpenFor(now))
        .length;
    if (pendingOut >= kPendingOutLimit) {
      throw const FriendException(FriendError.pendingLimit);
    }
    _addRequest(meId, target, source, orgId: orgId);
    return SendRequestOutcome.sent;
  });

  // ── Requests ───────────────────────────────────────────────────────────

  @override
  Future<Result<List<FriendRequest>>> getFriendRequests() => _respond(() {
    final now = clock.now();
    return [
      for (final r in _requests)
        if (r.to == meId && r.status == _Status.pending && r.isOpenFor(now))
          _toRequest(r, incoming: true)
        // A declined request still shows as waiting to its sender until it
        // expires — declining is never announced (spec §3.4).
        else if (r.from == meId && r.isOpenFor(now))
          _toRequest(r, incoming: false),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<Result<void>> respondFriendRequest(
    String requestId,
    FriendRequestAction action,
  ) => _respond(() {
    final r = _requests.firstWhere(
      (r) => r.id == requestId && r.to == meId && r.status == _Status.pending,
      orElse: () => throw const FriendException(FriendError.notFound),
    );
    if (!r.isOpenFor(clock.now())) {
      throw const FriendException(FriendError.notFound);
    }
    switch (action) {
      case FriendRequestAction.accept:
        if (friendCount(meId) >= kFriendLimit) {
          throw const FriendException(FriendError.friendLimit);
        }
        _accept(r);
      case FriendRequestAction.decline:
        _decline(r);
      case FriendRequestAction.declineAndBlock:
        _decline(r);
        addBlock(meId, r.from);
    }
  });

  @override
  Future<Result<void>> cancelFriendRequest(String requestId) => _respond(() {
    final r = _requests.firstWhere(
      (r) => r.id == requestId && r.from == meId,
      orElse: () => throw const FriendException(FriendError.notFound),
    );
    r.status = _Status.cancelled;
  });

  // ── Orgs ───────────────────────────────────────────────────────────────

  @override
  Future<Result<OrgSummary>> previewOrg(String joinCode) =>
      _respond(() => _lookup(() => _orgByCode(joinCode)).summary);

  @override
  Future<Result<OrgSummary>> joinOrg(String joinCode) => _respond(() {
    final org = _orgByCode(joinCode);
    final mine = _members.entries.where((e) => e.value.contains(meId));
    if (!_members[org.id]!.contains(meId) && mine.length >= kOrgLimit) {
      throw const FriendException(FriendError.orgLimit);
    }
    _members[org.id]!.add(meId);
    return org.summary;
  });

  @override
  Future<Result<void>> leaveOrg(String orgId) => _respond(() {
    _members[orgId]?.remove(meId);
  });

  @override
  Future<Result<List<OrgSummary>>> getMyOrgs() => _respond(
    () => [
      for (final org in _orgs.values)
        if (org.isActive && _members[org.id]!.contains(meId)) org.summary,
    ],
  );

  @override
  Future<Result<List<OrgMember>>> getOrgMembers(String orgId) => _respond(() {
    final org = _orgs[orgId];
    if (org == null || !org.isActive || !_members[orgId]!.contains(meId)) {
      throw const FriendException(FriendError.notFound);
    }
    final now = clock.now();
    return [
      for (final id in _members[orgId]!)
        if (id != meId &&
            _users[id]!.showInOrgList &&
            !_blockedEitherWay(meId, id))
          OrgMember(
            // The org list never shows photos, even of friends (spec §3.3).
            profile: _profileOf(id, withPhoto: false),
            status: _friendships.containsKey(_pairKey(meId, id))
                ? OrgMemberStatus.friend
                : _requests.any(
                    (r) => r.from == meId && r.to == id && r.isOpenFor(now),
                  )
                ? OrgMemberStatus.pendingOut
                : _openRequest(from: id, to: meId) != null
                ? OrgMemberStatus.pendingIn
                : OrgMemberStatus.none,
          ),
    ];
  });

  // ── Reports ────────────────────────────────────────────────────────────

  @override
  Future<Result<void>> reportProfile(
    String userId,
    ReportKind kind,
    ReportReason reason,
  ) => _respond(() {
    _rollDay();
    if (_reportsToday >= 10) {
      throw const FriendException(FriendError.limitReached);
    }
    _reportsToday++;
    reports.add((userId, kind, reason));
  });

  // ── Internals ──────────────────────────────────────────────────────────

  Future<Result<T>> _respond<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    try {
      return Result.ok(body());
    } on FriendException catch (e) {
      return Result.error(e);
    }
  }

  MyProfile _myProfile() {
    final me = _me;
    return MyProfile(
      userId: me.id,
      nickname: me.nickname,
      avatarPreset: me.avatarPreset,
      photoPath: me.photoPath,
      friendCode: me.friendCode,
      showInOrgList: me.showInOrgList,
      photoUploadBannedUntil: me.photoUploadBannedUntil,
      nicknameWasRemoved: me.nicknameWasRemoved,
      photoWasRemoved: me.photoWasRemoved,
    );
  }

  FriendProfile _profileOf(String userId, {required bool withPhoto}) {
    final u = _users[userId]!;
    return FriendProfile(
      userId: u.id,
      nickname: u.nickname ?? kRemovedNicknamePlaceholder,
      avatarPreset: u.avatarPreset,
      photoPath: withPhoto ? u.photoPath : null,
    );
  }

  FriendRequest _toRequest(_Request r, {required bool incoming}) =>
      FriendRequest(
        id: r.id,
        other: _profileOf(incoming ? r.from : r.to, withPhoto: false),
        incoming: incoming,
        source: r.source,
        orgName: r.orgId == null ? null : _orgs[r.orgId]?.name,
        createdAt: r.createdAt,
        expiresAt: r.expiresAt,
      );

  bool _blockedEitherWay(String a, String b) =>
      _blocks.contains((a, b)) || _blocks.contains((b, a));

  static String _pairKey(String a, String b) =>
      a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

  static bool _isBetween(_Request r, String a, String b) =>
      (r.from == a && r.to == b) || (r.from == b && r.to == a);

  _Request? _openRequest({required String from, required String to}) {
    final now = clock.now();
    for (final r in _requests) {
      if (r.from == from &&
          r.to == to &&
          r.status == _Status.pending &&
          r.isOpenFor(now)) {
        return r;
      }
    }
    return null;
  }

  void _addRequest(
    String from,
    String to,
    FriendSource source, {
    String? orgId,
    DateTime? at,
  }) {
    final createdAt = at ?? clock.now();
    _requests.add(
      _Request(
        id: 'req_${++_requestSeq}',
        from: from,
        to: to,
        source: source,
        orgId: orgId,
        createdAt: createdAt,
        expiresAt: createdAt.add(kRequestTtl),
      ),
    );
  }

  void _accept(_Request r) {
    r.status = _Status.accepted;
    // Any request the other way is settled by the same friendship.
    final reverse = _openRequest(from: r.to, to: r.from);
    reverse?.status = _Status.accepted;
    _friendships[_pairKey(r.from, r.to)] = _Friendship(
      r.from,
      r.to,
      r.source,
      clock.now(),
      null,
    );
  }

  void _decline(_Request r) {
    r.status = _Status.declined;
    _declinedAt[(r.from, r.to)] = clock.now();
  }

  String _resolveQr(String token) {
    final t = _qrTokens[token];
    if (t == null || _blockedEitherWay(meId, t.userId) || t.userId == meId) {
      throw const FriendException(FriendError.notFound);
    }
    if (!clock.now().isBefore(t.expiresAt)) {
      throw const FriendException(FriendError.qrExpired);
    }
    return t.userId;
  }

  String _userIdByCode(String code) {
    if (!isWellFormedCode(code)) {
      throw const FriendException(FriendError.notFound);
    }
    for (final u in _users.values) {
      if (u.friendCode == code && u.id != meId) {
        // A blocked pair looks exactly like a wrong number (spec §4.3).
        if (_blockedEitherWay(meId, u.id)) break;
        return u.id;
      }
    }
    throw const FriendException(FriendError.notFound);
  }

  _Org _orgByCode(String code) {
    for (final org in _orgs.values) {
      if (org.isActive && org.joinCode == code) return org;
    }
    throw const FriendException(FriendError.notFound);
  }

  /// The org through which I may ask [userId]: one we are both in and where
  /// they let members see them.
  String _sharedVisibleOrg(String userId) {
    final user = _users[userId];
    if (user == null || !user.showInOrgList) {
      throw const FriendException(FriendError.notFound);
    }
    for (final entry in _members.entries) {
      if (_orgs[entry.key]!.isActive &&
          entry.value.contains(meId) &&
          entry.value.contains(userId)) {
        return entry.key;
      }
    }
    throw const FriendException(FriendError.notFound);
  }

  /// Runs a friend-code or org-code lookup under the shared daily budget and
  /// the 5-misses lock (spec §3.2).
  T _lookup<T>(T Function() find) {
    _rollDay();
    final now = clock.now();
    final lockedUntil = _lookupsLockedUntil;
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      throw const FriendException(FriendError.locked);
    }
    if (_lookupsToday >= kDailyLookups) {
      throw const FriendException(FriendError.limitReached);
    }
    _lookupsToday++;
    try {
      final found = find();
      _failedLookupStreak = 0;
      return found;
    } on FriendException {
      _failedLookupStreak++;
      if (_failedLookupStreak >= kFailedLookupStreak) {
        _failedLookupStreak = 0;
        _lookupsLockedUntil = now.add(kLookupLock);
      }
      rethrow;
    }
  }

  void _rollDay() {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_limitsDay != today) {
      _limitsDay = today;
      _lookupsToday = 0;
      _nicknameChangesToday = 0;
      _reportsToday = 0;
    }
  }

  String _newCode() {
    final taken = {
      for (final u in _users.values) u.friendCode,
      for (final o in _orgs.values) o.joinCode,
    };
    while (true) {
      final code =
          '${1 + _random.nextInt(9)}'
          '${_random.nextInt(10000000).toString().padLeft(7, '0')}';
      if (!taken.contains(code)) return code;
    }
  }

  String _newToken() =>
      List.generate(16, (_) => _random.nextInt(256).toRadixString(16)).join();

  void _scheduleDemoScan() {
    _demoScanTimer?.cancel();
    _demoScanTimer = Timer(_demoScanDelay, () {
      final id = _demoScannerId;
      if (!_users.containsKey(id) ||
          _friendships.containsKey(_pairKey(meId, id)) ||
          _blockedEitherWay(meId, id) ||
          _requests.any(
            (r) => _isBetween(r, meId, id) && r.isOpenFor(clock.now()),
          )) {
        return;
      }
      _addRequest(id, meId, FriendSource.qr);
    });
  }
}

class _FakeUser {
  _FakeUser({
    required this.id,
    required this.nickname,
    required this.avatarPreset,
    required this.friendCode,
    this.photoPath,
    this.showInOrgList = true,
  });

  final String id;
  String? nickname;
  int avatarPreset;
  String friendCode;
  String? photoPath;
  bool showInOrgList;
  bool nicknameWasRemoved = false;
  bool photoWasRemoved = false;
  int photoRemovals = 0;
  DateTime? photoUploadBannedUntil;
}

class _Friendship {
  _Friendship(this.a, this.b, this.source, this.since, this.lastInteraction);

  final String a;
  final String b;
  final FriendSource source;
  final DateTime since;
  DateTime? lastInteraction;

  String other(String me) => a == me ? b : a;
}

enum _Status { pending, accepted, declined, cancelled }

class _Request {
  _Request({
    required this.id,
    required this.from,
    required this.to,
    required this.source,
    required this.createdAt,
    required this.expiresAt,
    this.orgId,
  });

  final String id;
  final String from;
  final String to;
  final FriendSource source;
  final String? orgId;
  final DateTime createdAt;
  final DateTime expiresAt;
  _Status status = _Status.pending;

  /// Still waiting as far as the sender can tell: pending or quietly
  /// declined, and not yet expired.
  bool isOpenFor(DateTime now) =>
      (status == _Status.pending || status == _Status.declined) &&
      now.isBefore(expiresAt);
}

class _Org {
  _Org(this.id, this.name, this.kind, this.joinCode);

  final String id;
  final String name;
  final OrgKind kind;
  final String joinCode;
  bool isActive = true;

  OrgSummary get summary => OrgSummary(id: id, name: name, kind: kind);
}

class _QrToken {
  _QrToken(this.userId, this.expiresAt);

  final String userId;
  final DateTime expiresAt;
}
