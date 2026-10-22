import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/app.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/providers/friends_provider.dart';

/// The demo backend, with a first QR request that fails and a count of how
/// often the friend list is read.
class _FlakyRepo extends FakeFriendsRepository {
  int qrFailuresLeft = 1;
  int friendListReads = 0;

  @override
  Future<Result<QrToken>> createQrToken() async {
    if (qrFailuresLeft > 0) {
      qrFailuresLeft--;
      return const Result.error(FriendException(FriendError.offline));
    }
    return super.createQrToken();
  }

  @override
  Future<Result<List<Friend>>> getFriends() {
    friendListReads++;
    return super.getFriends();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount for the whole flow: EasyLocalization keeps global state.
  testWidgets('my QR recovers from a failed request; the list refreshes on '
      'resume', (tester) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FlakyRepo();
    await repo.updateProfile(nickname: '王阿姨');
    final router = GoRouter(
      initialLocation: '/friends/my-qr',
      routes: [friendsRoute(enabled: true)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendsRepositoryProvider.overrideWithValue(repo)],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('zh', 'TW'),
          child: Builder(
            builder: (context) => MaterialApp.router(
              scaffoldMessengerKey: App.scaffoldMessengerKey,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: appTheme(Brightness.light),
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The first request failed: say so and offer a retry, no endless spinner.
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('沒有網路，連上再來。'), findsOneWidget);
    await tester.tap(find.text('再試一次'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('再試一次'), findsNothing);

    // Back on the hub, coming back to the app re-reads the friend list (its
    // photo links last an hour).
    router.go('/friends');
    await tester.pumpAndSettle();
    final before = repo.friendListReads;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(repo.friendListReads, before + 1);

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
