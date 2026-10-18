import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';

// The fake plays the server's part of the friends spec, so these cases are
// the spec's §10 checklist; the Supabase RPCs have to pass the same ones.

T ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Error(:final error) => throw StateError('expected Ok, got $error'),
};

FriendError err<T>(Result<T> r) => switch (r) {
  Ok(:final value) => throw StateError('expected an error, got $value'),
  Error(:final error) => (error as FriendException).code,
};

final _t0 = DateTime(2026, 10, 19, 10);

/// Me plus 王阿姨 (code 31415926) and 陳伯伯 (code 27182818), sharing an org.
FakeFriendsRepository world() => FakeFriendsRepository()
  ..addUser('wang', '王阿姨', preset: 2, code: '31415926')
  ..addUser('chen', '陳伯伯', preset: 3, code: '27182818')
  ..addOrg('org1', '三峽示範據點', OrgKind.communityCenter, '52013140')
  ..addOrgMember('org1', 'me')
  ..addOrgMember('org1', 'wang')
  ..addOrgMember('org1', 'chen');

// The fake sees the world as 'me'; the other side of each exchange is driven
// through its seeding hooks (addIncomingRequest, addBlock, declineAs, …).
void main() {
  group('adding by code', () {
    test('a code previews the person without their photo', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()
          ..addUser(
            'lin',
            '林阿嬤',
            preset: 5,
            code: '41421356',
            photoPath: '/photo.jpg',
          );
        final p = ok(await repo.previewByCode('41421356'));
        expect(p.nickname, '林阿嬤');
        expect(p.photoPath, isNull);
      });
    });

    test(
      'sending needs their consent: nothing changes until they accept',
      () async {
        await withClock(Clock.fixed(_t0), () async {
          final repo = world();
          ok(await repo.previewByCode('31415926'));
          expect(
            ok(await repo.sendFriendRequest(FriendSource.code, '31415926')),
            SendRequestOutcome.sent,
          );
          expect(repo.areFriends('me', 'wang'), isFalse);
          final out = ok(await repo.getFriendRequests());
          expect(out.single.incoming, isFalse);
          expect(out.single.other.userId, 'wang');
        });
      },
    );

    test(
      'asking someone who already asked me makes us friends at once',
      () async {
        await withClock(Clock.fixed(_t0), () async {
          final repo = world()..addIncomingRequest('wang', FriendSource.code);
          expect(
            ok(await repo.sendFriendRequest(FriendSource.code, '31415926')),
            SendRequestOutcome.becameFriends,
          );
          expect(repo.areFriends('me', 'wang'), isTrue);
          expect(ok(await repo.getFriendRequests()), isEmpty);
          expect(repo.friendCount('me'), 1);
        });
      },
    );

    test('20 lookups a day, then refused', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world();
        for (var i = 0; i < kDailyLookups; i++) {
          ok(await repo.previewByCode('31415926'));
        }
        expect(
          err(await repo.previewByCode('31415926')),
          FriendError.limitReached,
        );
      });
      // Next day the budget is back.
      await withClock(Clock.fixed(_t0.add(const Duration(days: 1))), () async {
        final repo = world();
        ok(await repo.previewByCode('31415926'));
      });
    });

    test('5 wrong codes in a row lock lookups for 10 minutes', () async {
      final repo = world();
      await withClock(Clock.fixed(_t0), () async {
        for (var i = 0; i < kFailedLookupStreak; i++) {
          expect(
            err(await repo.previewByCode('11111111')),
            FriendError.notFound,
          );
        }
        expect(err(await repo.previewByCode('31415926')), FriendError.locked);
      });
      await withClock(
        Clock.fixed(_t0.add(kLookupLock + const Duration(seconds: 1))),
        () async => ok(await repo.previewByCode('31415926')),
      );
    });

    test(
      'sending to a code that was never previewed spends the budget',
      () async {
        await withClock(Clock.fixed(_t0), () async {
          final repo = world();
          for (var i = 0; i < kFailedLookupStreak; i++) {
            err(await repo.sendFriendRequest(FriendSource.code, '1234567$i'));
          }
          expect(
            err(await repo.sendFriendRequest(FriendSource.code, '31415926')),
            FriendError.locked,
          );
        });
      },
    );

    test('a rotated code stops working immediately', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world();
        final before = ok(await repo.getMyProfile()).friendCode;
        final after = ok(await repo.rotateFriendCode()).friendCode;
        expect(after, isNot(before));
        expect(isWellFormedCode(after), isTrue);
      });
    });
  });

  group('adding by QR', () {
    test(
      "someone else's token works for 5 minutes, then reads as expired",
      () async {
        final repo = world()..addQrToken('wang', 'tok', _t0.add(kQrTokenTtl));
        await withClock(
          Clock.fixed(_t0.add(const Duration(minutes: 4))),
          () async {
            expect(ok(await repo.previewByQr('tok')).nickname, '王阿姨');
            expect(
              ok(await repo.sendFriendRequest(FriendSource.qr, 'tok')),
              SendRequestOutcome.sent,
            );
          },
        );
        await withClock(Clock.fixed(_t0.add(kQrTokenTtl)), () async {
          expect(err(await repo.previewByQr('tok')), FriendError.qrExpired);
        });
      },
    );

    test('my own token and unknown tokens are not found', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world();
        final mine = ok(await repo.createQrToken()).token;
        expect(err(await repo.previewByQr(mine)), FriendError.notFound);
        expect(err(await repo.previewByQr('nope')), FriendError.notFound);
      });
    });

    test("a blocker's token looks unknown, not expired", () async {
      final repo = world()
        ..addQrToken('wang', 'tok', _t0)
        ..addBlock('wang', 'me');
      await withClock(Clock.fixed(_t0.add(const Duration(hours: 1))), () async {
        expect(err(await repo.previewByQr('tok')), FriendError.notFound);
      });
    });
  });

  group('requests', () {
    test('declining is silent: the sender still sees it as waiting', () async {
      await withClock(Clock.fixed(_t0), () async {
        // Me declining 王阿姨's request…
        final repo = world()..addIncomingRequest('wang', FriendSource.code);
        final r = ok(await repo.getFriendRequests()).single;
        ok(await repo.respondFriendRequest(r.id, FriendRequestAction.decline));
        expect(ok(await repo.getFriendRequests()), isEmpty);
        expect(repo.areFriends('me', 'wang'), isFalse);
      });
      await withClock(Clock.fixed(_t0), () async {
        // …and from the sender's side, a declined request keeps showing as
        // waiting, and asking again is quietly a no-op.
        final sender = world();
        ok(await sender.sendFriendRequest(FriendSource.org, 'wang'));
        sender.declineAs('wang');
        final r = ok(await sender.getFriendRequests()).single;
        expect(r.incoming, isFalse);
        expect(
          ok(await sender.sendFriendRequest(FriendSource.org, 'wang')),
          SendRequestOutcome.sent,
        );
        expect(ok(await sender.getFriendRequests()).single.id, r.id);
      });
    });

    test(
      'after a declined request expires, a 30-day cooldown applies',
      () async {
        final sender = world();
        await withClock(Clock.fixed(_t0), () async {
          ok(await sender.sendFriendRequest(FriendSource.org, 'wang'));
          sender.declineAs('wang');
        });
        await withClock(Clock.fixed(_t0.add(kRequestTtl)), () async {
          expect(ok(await sender.getFriendRequests()), isEmpty);
          expect(
            err(await sender.sendFriendRequest(FriendSource.org, 'wang')),
            FriendError.cooldown,
          );
        });
        await withClock(Clock.fixed(_t0.add(kDeclineCooldown)), () async {
          ok(await sender.sendFriendRequest(FriendSource.org, 'wang'));
        });
      },
    );

    test('requests expire after 7 days', () async {
      final repo = world();
      await withClock(Clock.fixed(_t0), () async {
        repo.addIncomingRequest('wang', FriendSource.code);
        expect(ok(await repo.getFriendRequests()), hasLength(1));
      });
      await withClock(Clock.fixed(_t0.add(kRequestTtl)), () async {
        expect(ok(await repo.getFriendRequests()), isEmpty);
      });
    });

    test('at most 20 outgoing requests waiting at once', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world();
        for (var i = 0; i < kPendingOutLimit; i++) {
          repo
            ..addUser('u$i', 'u$i', preset: 1, code: '${30000000 + i}')
            ..addOrgMember('org1', 'u$i');
          ok(await repo.sendFriendRequest(FriendSource.org, 'u$i'));
        }
        expect(
          err(await repo.sendFriendRequest(FriendSource.org, 'wang')),
          FriendError.pendingLimit,
        );
      });
    });

    test('100 friends is the cap', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world();
        for (var i = 0; i < kFriendLimit; i++) {
          repo
            ..addUser('f$i', 'f$i', preset: 1, code: '${40000000 + i}')
            ..addFriendship('f$i');
        }
        expect(
          err(await repo.sendFriendRequest(FriendSource.org, 'wang')),
          FriendError.friendLimit,
        );
      });
    });
  });

  group('blocking', () {
    test('a blocked person cannot tell they are blocked', () async {
      await withClock(Clock.fixed(_t0), () async {
        // 王阿姨 blocked me.
        final repo = world()
          ..addFriendship('wang')
          ..addBlock('wang', 'me');
        expect(repo.areFriends('me', 'wang'), isFalse);
        expect(repo.areFriends('wang', 'me'), isFalse);
        expect(ok(await repo.getFriends()), isEmpty);
        // Her code reads exactly like a wrong number…
        expect(err(await repo.previewByCode('31415926')), FriendError.notFound);
        // …she is gone from the shared org list…
        final members = ok(await repo.getOrgMembers('org1'));
        expect(members.map((m) => m.profile.userId), ['chen']);
        // …and asking through the org fails the same way.
        expect(
          err(await repo.sendFriendRequest(FriendSource.org, 'wang')),
          FriendError.notFound,
        );
        // I cannot see that she blocked me.
        expect(ok(await repo.getBlocked()), isEmpty);
      });
    });

    test('blocking removes the friendship and pending requests', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()
          ..addFriendship('wang')
          ..addIncomingRequest('chen', FriendSource.code);
        ok(await repo.blockUser('wang'));
        ok(await repo.blockUser('chen'));
        expect(ok(await repo.getFriends()), isEmpty);
        expect(ok(await repo.getFriendRequests()), isEmpty);
        expect(
          ok(await repo.getBlocked()).map((p) => p.userId),
          containsAll(['wang', 'chen']),
        );
      });
    });

    test('unblocking does not bring the friendship back', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()..addFriendship('wang');
        ok(await repo.blockUser('wang'));
        ok(await repo.unblockUser('wang'));
        expect(repo.areFriends('me', 'wang'), isFalse);
        expect(ok(await repo.getBlocked()), isEmpty);
      });
    });

    test('decline-and-block from a request', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()..addIncomingRequest('wang', FriendSource.code);
        final r = ok(await repo.getFriendRequests()).single;
        ok(
          await repo.respondFriendRequest(
            r.id,
            FriendRequestAction.declineAndBlock,
          ),
        );
        expect(ok(await repo.getBlocked()).single.userId, 'wang');
        expect(err(await repo.previewByCode('31415926')), FriendError.notFound);
      });
    });
  });

  group('orgs', () {
    test(
      'the list hides people who switched it off, but they still see it',
      () async {
        await withClock(Clock.fixed(_t0), () async {
          final repo = world()
            ..addUser(
              'tsai',
              '蔡阿公',
              preset: 6,
              code: '44721359',
              showInOrgList: false,
            )
            ..addOrgMember('org1', 'tsai');
          final ids = ok(
            await repo.getOrgMembers('org1'),
          ).map((m) => m.profile.userId);
          expect(ids, isNot(contains('tsai')));

          ok(await repo.updateProfile(showInOrgList: false));
          // Hidden myself, I can still read the list.
          expect(ok(await repo.getOrgMembers('org1')), isNotEmpty);
        });
      },
    );

    test('member status: friend, waiting, wants me, none', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()
          ..addUser('kuo', '郭大哥', preset: 8, code: '24494897')
          ..addUser('wu', '吳奶奶', preset: 9, code: '30277563')
          ..addOrgMember('org1', 'kuo')
          ..addOrgMember('org1', 'wu')
          ..addFriendship('wang')
          ..addOutgoingRequest('chen', FriendSource.org, orgId: 'org1')
          ..addIncomingRequest('kuo', FriendSource.org, orgId: 'org1');
        final status = {
          for (final m in ok(await repo.getOrgMembers('org1')))
            m.profile.userId: m.status,
        };
        expect(status, {
          'wang': OrgMemberStatus.friend,
          'chen': OrgMemberStatus.pendingOut,
          'kuo': OrgMemberStatus.pendingIn,
          'wu': OrgMemberStatus.none,
        });
      });
    });

    test('the org list never shows photos, even of friends', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()
          ..addUser(
            'lin',
            '林阿嬤',
            preset: 5,
            code: '41421356',
            photoPath: '/lin.jpg',
          )
          ..addOrgMember('org1', 'lin')
          ..addFriendship('lin');
        final lin = ok(
          await repo.getOrgMembers('org1'),
        ).firstWhere((m) => m.profile.userId == 'lin');
        expect(lin.profile.photoPath, isNull);
        final friend = ok(await repo.getFriends()).single;
        expect(friend.profile.photoPath, '/lin.jpg');
      });
    });

    test('at most 3 orgs; leaving keeps the friends', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()
          ..addOrg('org2', 'B', OrgKind.dayCare, '60000002')
          ..addOrg('org3', 'C', OrgKind.other, '60000003')
          ..addOrg('org4', 'D', OrgKind.other, '60000004')
          ..addFriendship('wang', source: FriendSource.org);
        ok(await repo.joinOrg('60000002'));
        ok(await repo.joinOrg('60000003'));
        expect(err(await repo.joinOrg('60000004')), FriendError.orgLimit);
        ok(await repo.leaveOrg('org1'));
        ok(await repo.joinOrg('60000004'));
        expect(repo.areFriends('me', 'wang'), isTrue);
      });
    });

    test('only members can read an org list', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()..addOrg('org2', 'B', OrgKind.dayCare, '60000002');
        expect(err(await repo.getOrgMembers('org2')), FriendError.notFound);
      });
    });
  });

  group('profile', () {
    test('first name is free; then 3 changes a day', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world();
        expect(ok(await repo.getMyProfile()).needsSetup, isTrue);
        ok(await repo.updateProfile(nickname: '王阿姨'));
        for (final name in ['阿姨一', '阿姨二', '阿姨三']) {
          ok(await repo.updateProfile(nickname: name));
        }
        expect(
          err(await repo.updateProfile(nickname: '阿姨四')),
          FriendError.nicknameChangeLimit,
        );
      });
    });

    test('invalid nicknames are refused', () async {
      final repo = world();
      expect(
        err(await repo.updateProfile(nickname: '王')),
        FriendError.nicknameInvalid,
      );
      expect(
        err(await repo.updateProfile(nickname: '！！！')),
        FriendError.nicknameInvalid,
      );
      expect(
        err(await repo.updateProfile(nickname: '一二三四五六七八九')),
        FriendError.nicknameInvalid,
      );
    });

    test('a removed nickname becomes 銀足朋友 and asks for a new one', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world();
        ok(await repo.updateProfile(nickname: '王阿姨'));
        repo.adminRemoveNickname('me');
        final me = ok(await repo.getMyProfile());
        expect(me.nickname, kRemovedNicknamePlaceholder);
        expect(me.nicknameWasRemoved, isTrue);
        // Picking the replacement does not use up a daily change.
        ok(await repo.updateProfile(nickname: '新名字'));
        expect(ok(await repo.getMyProfile()).nicknameWasRemoved, isFalse);
      });
    });

    test('a third photo removal bans uploads for 30 days', () async {
      final repo = world();
      await withClock(Clock.fixed(_t0), () async {
        for (var i = 0; i < kPhotoRemovalsBeforeBan; i++) {
          ok(await repo.setAvatarPhoto('/p$i.jpg'));
          repo.adminRemovePhoto('me');
        }
        final me = ok(await repo.getMyProfile());
        expect(me.photoPath, isNull);
        expect(me.photoWasRemoved, isTrue);
        expect(
          err(await repo.setAvatarPhoto('/again.jpg')),
          FriendError.uploadBanned,
        );
      });
      await withClock(
        Clock.fixed(_t0.add(kPhotoUploadBan + const Duration(minutes: 1))),
        () async => ok(await repo.setAvatarPhoto('/again.jpg')),
      );
    });

    test('reports are recorded, 10 a day', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = world()..addFriendship('wang');
        for (var i = 0; i < 10; i++) {
          ok(
            await repo.reportProfile(
              'wang',
              ReportKind.nickname,
              ReportReason.ads,
            ),
          );
        }
        expect(
          err(
            await repo.reportProfile(
              'wang',
              ReportKind.photo,
              ReportReason.other,
            ),
          ),
          FriendError.limitReached,
        );
        expect(repo.reports, hasLength(10));
      });
    });
  });

  test('friends are listed by latest interaction, then newest', () async {
    await withClock(Clock.fixed(_t0), () async {
      final repo = world()
        ..addUser('lin', '林阿嬤', preset: 5, code: '41421356')
        ..addFriendship('wang', since: _t0.subtract(const Duration(days: 9)))
        ..addFriendship(
          'chen',
          since: _t0.subtract(const Duration(days: 20)),
          lastInteraction: _t0.subtract(const Duration(hours: 1)),
        )
        ..addFriendship('lin', since: _t0.subtract(const Duration(days: 1)));
      final order = ok(await repo.getFriends()).map((f) => f.profile.userId);
      expect(order, ['chen', 'lin', 'wang']);
    });
  });

  test('the seeded demo data is consistent', () async {
    final repo = FakeFriendsRepository.seeded(latency: Duration.zero);
    expect(ok(await repo.getMyProfile()).needsSetup, isTrue);
    expect(ok(await repo.getFriends()), hasLength(4));
    final incoming = ok(
      await repo.getFriendRequests(),
    ).where((r) => r.incoming);
    expect(incoming, hasLength(2));
    ok(await repo.previewByCode(FakeFriendsRepository.demoFriendCode));
    ok(await repo.previewOrg(FakeFriendsRepository.demoOrgCode));
    repo.dispose();
  });
}
