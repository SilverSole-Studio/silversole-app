import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/app.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import '../helpers/translations.dart';

final _wangToken = 'a' * 32;
final _chenToken = 'c' * 32; // switched off
final _linToken = 'd' * 32; // her inbox is full
final _zhaoToken = 'e' * 32; // already a friend

Future<ShareLink?> _linkOf(FakeFriendsRepository repo) async =>
    switch (await repo.getShareLink()) {
      Ok(:final value) => value,
      Error() => null,
    };

Future<FakeFriendsRepository> _repo() async {
  final repo = FakeFriendsRepository()
    ..addUser('wang', '王阿姨', preset: 2, code: '31415926')
    ..addShareLink('wang', _wangToken)
    ..addUser('chen', '陳伯伯', preset: 3, code: '27182818')
    ..addShareLink('chen', _chenToken, disabled: true)
    ..addUser('lin', '林阿嬤', preset: 4, code: '16180339')
    ..addShareLink('lin', _linToken)
    ..addLinkRequestsReceived('lin', 10)
    ..addUser('zhao', '趙伯伯', preset: 5, code: '14142135')
    ..addShareLink('zhao', _zhaoToken)
    ..addFriendship('zhao');
  await repo.updateProfile(nickname: '我自己');
  return repo;
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required FakeFriendsRepository repo,
  required String location,
  List<String>? shared,
}) async {
  await EasyLocalization.ensureInitialized();
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('home')),
      friendsRoute(enabled: true),
      shareLinkRoute(enabled: true),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendsRepositoryProvider.overrideWithValue(repo),
        shareTextProvider.overrideWithValue((text, Rect? origin) async {
          shared?.add(text);
        }),
      ],
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
  await settleTranslations(tester);
  return router;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount for the whole flow: EasyLocalization keeps global state.
  testWidgets("sharing my link, turning it off, and opening other people's", (
    tester,
  ) async {
    final repo = await _repo();
    final shared = <String>[];
    final router = await _pump(
      tester,
      repo: repo,
      location: '/friends',
      shared: shared,
    );

    // ── my link ────────────────────────────────────────────────────────
    // No link yet: the button and the 7-day note.
    expect(find.text('傳連結給朋友'), findsOneWidget);
    expect(find.text('連結 7 天內有效。'), findsOneWidget);
    expect(find.text('停用連結'), findsNothing);

    await tester.tap(find.text('傳連結給朋友'));
    await tester.pumpAndSettle();

    final link = (await _linkOf(repo))!;
    expect(shared, hasLength(1));
    expect(
      shared.single,
      contains('https://dongyu.company/f/?t=${link.token}'),
    );
    // Now it says until when and offers to turn it off.
    expect(find.textContaining('連結有效到'), findsOneWidget);
    expect(find.text('停用連結'), findsOneWidget);

    // Sharing again hands out the same link.
    await tester.tap(find.text('傳連結給朋友'));
    await tester.pumpAndSettle();
    expect(shared.last, shared.first);

    await tester.tap(find.text('停用連結'));
    await tester.pumpAndSettle();
    expect(find.text('要停用連結嗎？'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('停用連結'),
      ),
    );
    await tester.pumpAndSettle();
    expect(await _linkOf(repo), isNull);
    expect(find.text('連結 7 天內有效。'), findsOneWidget);
    expect(find.text('停用連結'), findsNothing);

    // ── an address with no usable token: nothing is asked ──────────────
    router.go('/f/?t=abc');
    await tester.pumpAndSettle();
    expect(find.text('這個連結失效了，請對方重新傳一個。'), findsOneWidget);
    await tester.tap(find.text('回首頁'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    // ── a link that was switched off ───────────────────────────────────
    router.go('/f/?t=$_chenToken');
    await tester.pumpAndSettle();
    expect(find.text('這個連結失效了，請對方重新傳一個。'), findsOneWidget);
    expect(find.text('加他當朋友'), findsNothing);
    router.go('/');
    await tester.pumpAndSettle();

    // ── their inbox is full today ──────────────────────────────────────
    router.go('/f/?t=$_linToken');
    await tester.pumpAndSettle();
    expect(find.text('林阿嬤'), findsOneWidget);
    await tester.tap(find.text('加他當朋友'));
    await tester.pumpAndSettle();
    expect(find.text('對方今天收到的邀請太多了，明天再試。'), findsOneWidget);
    expect(repo.incomingCountFor('lin'), 0);
    await tester.tap(find.text('先不要'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    // ── already friends ────────────────────────────────────────────────
    router.go('/f/?t=$_zhaoToken');
    await tester.pumpAndSettle();
    expect(find.text('你和趙伯伯已經是朋友了'), findsOneWidget);
    expect(find.text('加他當朋友'), findsNothing);
    expect(find.textContaining('朋友（1／100）'), findsOneWidget);
    router.go('/');
    await tester.pumpAndSettle();

    // ── a good link: says who, sends only after the tap ────────────────
    router.go('/f/?t=$_wangToken');
    await tester.pumpAndSettle();
    expect(find.text('王阿姨'), findsOneWidget);
    expect(repo.incomingCountFor('wang'), 0);
    await tester.tap(find.text('先不要'));
    await tester.pumpAndSettle();
    expect(repo.incomingCountFor('wang'), 0);
    expect(find.text('home'), findsOneWidget);

    router.go('/f/?t=$_wangToken');
    await tester.pumpAndSettle();
    await tester.tap(find.text('加他當朋友'));
    await tester.pumpAndSettle();
    expect(repo.incomingCountFor('wang'), 1);
    expect(repo.areFriends('me', 'wang'), isFalse);
    // Lands on the friends page.
    expect(find.textContaining('朋友（1／100）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
