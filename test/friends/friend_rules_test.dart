import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/friends/friend_rules.dart';

void main() {
  group('validateNickname matches the SQL whitelist', () {
    // The same cases as supabase/tests/friends_rpc_test.mjs.
    test('refused', () {
      for (final bad in [
        '王',
        '！！！',
        '一二三四五六七八九',
        '  ',
        '王\n阿姨',
        '★★',
        // Letters outside the server's whitelist (Arabic, Devanagari).
        'سلام',
        'नमस्ते',
      ]) {
        expect(validateNickname(bad), FriendError.nicknameInvalid, reason: bad);
      }
    });

    test('accepted', () {
      for (final good in ['小美', 'Amy', '陳伯伯88', 'ㄚ寶', 'さくら', '　王阿姨 ', 'Ａｍｙ']) {
        expect(validateNickname(good), isNull, reason: good);
      }
      expect(trimNickname('　王阿姨 '), '王阿姨');
    });
  });

  group(
    'validateNickname refuses names made to fool people (2026-10-26 audit)',
    () {
      // The same cases as the "audit 7" test in supabase/tests/friends_rpc_test.mjs.
      test('invisible, reversed and staff-looking names', () {
        for (final bad in [
          '阿\u200B美', // zero-width space
          '阿美\u202E', // right-to-left override
          '\u2066小明\u2069', // isolates
          '銀足朋友', // what a taken-down nickname turns into
          '銀足小幫手',
          'ＡＤＭＩＮ',
          'Admin',
          '客服小美',
          '系統通知',
          '粗哥',
          '\u3164\u3164', // Hangul filler, looks empty
          '阿美\u0301\u0301\u0301', // stacked combining marks
        ]) {
          expect(
            validateNickname(bad),
            FriendError.nicknameInvalid,
            reason: bad,
          );
        }
      });

      test('粗哥 inside a longer name is fine', () {
        expect(validateNickname('粗哥迷'), isNull);
      });
    },
  );

  test('the new server refusals have their own messages', () {
    expect(friendErrorKey(FriendError.sendLimit), 'friends_err_sendLimit');
    expect(friendErrorKey(FriendError.rateLimited), 'friends_err_rateLimited');
  });

  group('friendErrorKey', () {
    test('not found is worded for what the person was doing', () {
      expect(friendErrorKey(FriendError.notFound), 'friends_err_notFound');
      expect(
        friendErrorKey(FriendError.notFound, FriendErrorScope.qr),
        'friends_err_notFound_qr',
      );
      expect(
        friendErrorKey(FriendError.notFound, FriendErrorScope.org),
        'friends_err_notFound_org',
      );
      expect(
        friendErrorKey(FriendError.notFound, FriendErrorScope.request),
        'friends_err_notFound_request',
      );
      expect(
        friendErrorKey(FriendError.notFound, FriendErrorScope.report),
        'friends_err_notFound_report',
      );
      expect(
        friendErrorKey(FriendError.notFound, FriendErrorScope.avatar),
        'friends_err_notFound_avatar',
      );
    });

    test('the daily limits are told apart', () {
      expect(
        friendErrorKey(FriendError.limitReached),
        'friends_err_limitReached',
      );
      expect(
        friendErrorKey(FriendError.limitReached, FriendErrorScope.photo),
        'friends_err_limitReached_photo',
      );
      expect(
        friendErrorKey(FriendError.limitReached, FriendErrorScope.report),
        'friends_err_limitReached_report',
      );
      expect(
        friendErrorKey(FriendError.otherFriendLimit, FriendErrorScope.qr),
        'friends_err_otherFriendLimit',
      );
    });
  });

  group('avatarImageType', () {
    test('reads the file type from its first bytes', () {
      expect(avatarImageType([0xFF, 0xD8, 0xFF, 0xE0])?.mimeType, 'image/jpeg');
      expect(
        avatarImageType([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
        (mimeType: 'image/png', extension: 'png'),
      );
      expect(
        avatarImageType('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits)?.extension,
        'webp',
      );
    });

    test('anything else is refused', () {
      expect(avatarImageType('GIF89a'.codeUnits), isNull);
      expect(avatarImageType('RIFF\x00\x00\x00\x00WAVE'.codeUnits), isNull);
      expect(avatarImageType(const []), isNull);
    });
  });
}
