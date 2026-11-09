import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/routing/router.dart';
import 'package:silversole/shared/providers/friends_provider.dart';

// The fake plays the server's part, so these are the same cases as
// supabase/tests/friend_share_link_test.mjs.

T ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Error(:final error) => throw StateError('expected Ok, got $error'),
};

FriendError err<T>(Result<T> r) => switch (r) {
  Ok(:final value) => throw StateError('expected an error, got $value'),
  Error(:final error) => (error as FriendException).code,
};

final _t0 = DateTime(2026, 11, 9, 10);
final _wangToken = 'a' * 32;

/// Me (with a nickname) plus 王阿姨, who has a share link.
FakeFriendsRepository world() {
  final repo = FakeFriendsRepository()
    ..addUser('wang', '王阿姨', preset: 2, code: '31415926')
    ..addUser('chen', '陳伯伯', preset: 3, code: '27182818')
    ..addShareLink('wang', _wangToken);
  return repo;
}

Future<FakeFriendsRepository> named(FakeFriendsRepository repo) async {
  ok(await repo.updateProfile(nickname: '我自己'));
  return repo;
}

void main() {
  group('the link address', () {
    test('is https://dongyu.company/f/?t=<token>', () {
      expect(
        shareLinkUri(_wangToken).toString(),
        'https://dongyu.company/f/?t=$_wangToken',
      );
    });

    test('is read back from the https link and the app-scheme link', () {
      for (final text in [
        'https://dongyu.company/f/?t=$_wangToken',
        'https://dongyu.company/f?t=$_wangToken',
        'silversole://dongyu.company/f/?t=$_wangToken',
        '/f/?t=$_wangToken',
        '/f/$_wangToken',
        'https://dongyu.company/f/?t=${_wangToken.toUpperCase()}',
        'https://dongyu.company/f/?t=$_wangToken&utm_source=line',
      ]) {
        expect(parseShareLinkToken(Uri.parse(text)), _wangToken, reason: text);
      }
    });

    test('is not read from anything else', () {
      for (final text in [
        '/',
        '/friends',
        '/f',
        '/f/',
        '/f/?t=',
        '/f/?t=abc',
        '/f/?t=${'g' * 32}',
        '/f/?t=${'a' * 33}',
        '/f/abc',
        '/g/?t=$_wangToken',
        '/friends?t=$_wangToken',
        '/f/x/y?t=$_wangToken'.replaceFirst('?t=$_wangToken', ''),
      ]) {
        expect(parseShareLinkToken(Uri.parse(text)), isNull, reason: text);
      }
    });
  });

  group('making and turning off my link', () {
    test('there is no link until I make one', () async {
      final repo = await named(world());
      expect(ok(await repo.getShareLink()), isNull);
    });

    test('a link lasts 7 days and asking again gives the same one', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = await named(world());
        final a = ok(await repo.createShareLink());
        expect(a.token, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(a.expiresAt, _t0.add(kShareLinkTtl));
        final b = ok(await repo.createShareLink());
        expect(b.token, a.token);
        expect(ok(await repo.getShareLink())!.token, a.token);
      });
    });

    test('after 7 days it is gone and a new one is a new token', () async {
      final repo = await named(world());
      late ShareLink first;
      await withClock(Clock.fixed(_t0), () async {
        first = ok(await repo.createShareLink());
      });
      await withClock(
        Clock.fixed(_t0.add(kShareLinkTtl + const Duration(seconds: 1))),
        () async {
          expect(ok(await repo.getShareLink()), isNull);
          final second = ok(await repo.createShareLink());
          expect(second.token, isNot(first.token));
        },
      );
    });

    test('turning it off ends it at once and a new one can be made', () async {
      final repo = await named(world());
      final first = ok(await repo.createShareLink());
      ok(await repo.disableShareLink());
      expect(ok(await repo.getShareLink()), isNull);
      ok(await repo.disableShareLink()); // again: no error
      final second = ok(await repo.createShareLink());
      expect(second.token, isNot(first.token));
    });

    test('someone without a nickname cannot make one', () async {
      final repo = world();
      expect(err(await repo.createShareLink()), FriendError.nicknameInvalid);
    });
  });

  group('opening someone else\'s link', () {
    test('shows their nickname and preset avatar, not the photo', () async {
      final repo = await named(world());
      final shared = ok(await repo.previewByShareLink(_wangToken));
      expect(shared.profile.nickname, '王阿姨');
      expect(shared.profile.avatarPreset, 2);
      expect(shared.profile.photoPath, isNull);
      expect(shared.alreadyFriends, isFalse);
    });

    test(
      'an unknown token, my own link and a blocked person are not found',
      () async {
        final repo = await named(world());
        expect(
          err(await repo.previewByShareLink('b' * 32)),
          FriendError.notFound,
        );
        final mine = ok(await repo.createShareLink());
        expect(
          err(await repo.previewByShareLink(mine.token)),
          FriendError.notFound,
        );
        ok(await repo.blockUser('wang'));
        expect(
          err(await repo.previewByShareLink(_wangToken)),
          FriendError.notFound,
        );
        expect(
          err(await repo.sendFriendRequest(FriendSource.link, _wangToken)),
          FriendError.notFound,
        );
      },
    );

    test('a link turned off or older than 7 days reads as expired', () async {
      final repo = await named(world())
        ..addShareLink('chen', 'c' * 32, disabled: true);
      expect(
        err(await repo.previewByShareLink('c' * 32)),
        FriendError.linkExpired,
      );
      expect(
        err(await repo.sendFriendRequest(FriendSource.link, 'c' * 32)),
        FriendError.linkExpired,
      );
      await withClock(
        Clock.fixed(
          DateTime.now().add(kShareLinkTtl + const Duration(days: 1)),
        ),
        () async {
          expect(
            err(await repo.previewByShareLink(_wangToken)),
            FriendError.linkExpired,
          );
        },
      );
    });

    test('nothing is sent by opening it; sending needs their answer', () async {
      final repo = await named(world());
      ok(await repo.previewByShareLink(_wangToken));
      expect(repo.incomingCountFor('wang'), 0);
      final outcome = ok(
        await repo.sendFriendRequest(FriendSource.link, _wangToken),
      );
      expect(outcome, SendRequestOutcome.sent);
      expect(repo.areFriends('me', 'wang'), isFalse);
      expect(repo.incomingCountFor('wang'), 1);
      final out = ok(await repo.getFriendRequests());
      expect(out.single.source, FriendSource.link);
    });

    test('already friends: preview says so', () async {
      final repo = await named(world())
        ..addFriendship('wang');
      expect(
        ok(await repo.previewByShareLink(_wangToken)).alreadyFriends,
        isTrue,
      );
      expect(
        ok(await repo.sendFriendRequest(FriendSource.link, _wangToken)),
        SendRequestOutcome.alreadyFriends,
      );
    });
  });

  group('ten a day', () {
    test(
      'the 10th request through links is taken, the 11th is refused',
      () async {
        await withClock(Clock.fixed(_t0), () async {
          final repo = await named(world())
            ..addLinkRequestsReceived('wang', kShareLinkInboxLimit - 1);
          expect(
            ok(await repo.sendFriendRequest(FriendSource.link, _wangToken)),
            SendRequestOutcome.sent,
          );
          // Someone else's link is a different count.
          repo.addShareLink('chen', 'c' * 32);
          expect(
            ok(await repo.sendFriendRequest(FriendSource.link, 'c' * 32)),
            SendRequestOutcome.sent,
          );
        });
      },
    );

    test('a full inbox refuses, and a new link does not reset it', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = await named(world())
          ..addLinkRequestsReceived('wang', kShareLinkInboxLimit);
        expect(
          err(await repo.sendFriendRequest(FriendSource.link, _wangToken)),
          FriendError.linkLimit,
        );
        repo.addShareLink('wang', 'e' * 32); // she made a new link
        expect(
          err(await repo.sendFriendRequest(FriendSource.link, 'e' * 32)),
          FriendError.linkLimit,
        );
        // Other routes to her are not affected.
        expect(
          ok(await repo.sendFriendRequest(FriendSource.code, '31415926')),
          SendRequestOutcome.sent,
        );
      });
    });

    test('the next day it starts over', () async {
      final repo = await named(world())
        ..addLinkRequestsReceived('wang', kShareLinkInboxLimit);
      await withClock(Clock.fixed(_t0), () async {
        expect(
          err(await repo.sendFriendRequest(FriendSource.link, _wangToken)),
          FriendError.linkLimit,
        );
      });
      await withClock(Clock.fixed(_t0.add(const Duration(days: 1))), () async {
        expect(
          ok(await repo.sendFriendRequest(FriendSource.link, _wangToken)),
          SendRequestOutcome.sent,
        );
      });
    });

    test('sending twice through the same link takes one place', () async {
      await withClock(Clock.fixed(_t0), () async {
        final repo = await named(world())
          ..addLinkRequestsReceived('wang', kShareLinkInboxLimit - 1);
        ok(await repo.sendFriendRequest(FriendSource.link, _wangToken));
        expect(
          ok(await repo.sendFriendRequest(FriendSource.link, _wangToken)),
          SendRequestOutcome.sent,
        );
      });
    });
  });

  group('the router holds a link through sign-in', () {
    final uri = Uri.parse('/f/?t=$_wangToken');

    test('signed out: sign in first, the link is kept', () {
      final pending = PendingShareLink();
      expect(
        appRedirect(
          isGuest: true,
          friendsOn: true,
          uri: uri,
          matchedLocation: '/f',
          pendingShareLink: pending,
          skipAuthGate: false,
        ),
        '/sign-in',
      );
      // Signed in and landed on the home page: the link opens.
      expect(
        appRedirect(
          isGuest: false,
          friendsOn: true,
          uri: Uri.parse('/'),
          matchedLocation: '/',
          pendingShareLink: pending,
          skipAuthGate: false,
        ),
        '/f/?t=$_wangToken',
      );
      // Only once.
      expect(
        appRedirect(
          isGuest: false,
          friendsOn: true,
          uri: Uri.parse('/'),
          matchedLocation: '/',
          pendingShareLink: pending,
          skipAuthGate: false,
        ),
        isNull,
      );
    });

    test('signed in: the link opens as it is', () {
      expect(
        appRedirect(
          isGuest: false,
          friendsOn: true,
          uri: uri,
          matchedLocation: '/f',
          pendingShareLink: PendingShareLink(),
          skipAuthGate: false,
        ),
        isNull,
      );
    });

    test('with friends off nothing is held', () {
      final pending = PendingShareLink();
      expect(
        appRedirect(
          isGuest: true,
          friendsOn: false,
          uri: uri,
          matchedLocation: '/f',
          pendingShareLink: pending,
          skipAuthGate: false,
        ),
        '/sign-in',
      );
      expect(pending.take(), isNull);
    });
  });
}
