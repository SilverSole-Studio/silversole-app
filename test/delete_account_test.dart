import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/auth/auth_service.dart';
import 'package:silversole/core/error/result.dart';

/// An [AuthService] whose three seams are scripted, recording whether it
/// signed out locally.
class _Harness {
  _Harness({required this.call, this.stillExists});

  final Future<int> Function() call;
  final bool? stillExists;
  int signOuts = 0;
  int existenceChecks = 0;

  late final service = AuthService(
    deleteAccountCall: call,
    accountStillExists: () async {
      existenceChecks++;
      return stillExists;
    },
    localSignOut: () async => signOuts++,
  );
}

String _message(Result<void> result) =>
    (result as Error<void>).error.toString();

void main() {
  test('a 200 deletes, then signs out locally', () async {
    final h = _Harness(call: () async => 200);
    final result = await h.service.deleteAccount();
    expect(result, isA<Ok<void>>());
    expect(h.signOuts, 1);
    expect(h.existenceChecks, 0);
  });

  test('401 and 404 mean the user is already gone: signed out, ok', () async {
    for (final status in [401, 404]) {
      final h = _Harness(call: () async => status);
      expect(await h.service.deleteAccount(), isA<Ok<void>>());
      expect(h.signOuts, 1, reason: 'status $status');
    }
  });

  test(
    'a server failure with the account still there keeps the session',
    () async {
      final h = _Harness(call: () async => 500, stillExists: true);
      final result = await h.service.deleteAccount();
      expect(result, isA<Error<void>>());
      expect(_message(result), contains('delete_account_failed'));
      expect(h.signOuts, 0);
    },
  );

  test(
    'a failure after the account was in fact deleted still signs out',
    () async {
      final h = _Harness(call: () async => 500, stillExists: false);
      expect(await h.service.deleteAccount(), isA<Ok<void>>());
      expect(h.signOuts, 1);
    },
  );

  test(
    'a lost response that cannot be checked signs out and says so',
    () async {
      final h = _Harness(
        call: () async => throw Exception('connection reset'),
        stillExists: null,
      );
      final result = await h.service.deleteAccount();
      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, isA<AccountDeletionUnconfirmed>());
    expect(_message(result), contains('delete_account_unconfirmed'));
      expect(
        h.signOuts,
        1,
        reason: 'no session may be left pointing at a maybe-deleted user',
      );
    },
  );

  test(
    'a lost request with the account still there keeps the session',
    () async {
      final h = _Harness(
        call: () async => throw Exception('offline'),
        stillExists: true,
      );
      final result = await h.service.deleteAccount();
      expect(_message(result), contains('delete_account_failed'));
      expect(h.signOuts, 0);
    },
  );

  test(
    'a local sign-out that throws does not turn success into failure',
    () async {
      final service = AuthService(
        deleteAccountCall: () async => 200,
        accountStillExists: () async => false,
        localSignOut: () async => throw Exception('storage locked'),
      );
      expect(await service.deleteAccount(), isA<Ok<void>>());
    },
  );
}
