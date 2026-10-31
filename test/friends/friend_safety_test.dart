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
import 'package:silversole/shared/widgets/friends/friend_safety.dart';
import '../helpers/translations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount for every screen: EasyLocalization keeps global state, so a
  // second mount in the same file never leaves its loading state.
  testWidgets('strangers on the request and org lists can be reported and '
      'blocked', (tester) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(390, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeFriendsRepository.seeded(latency: Duration.zero);
    await repo.updateProfile(nickname: '王阿姨');
    final router = GoRouter(
      initialLocation: '/friends/requests',
      routes: [friendsRoute(enabled: true)],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendsRepositoryProvider.overrideWithValue(repo)],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: CsvAssetLoader(),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
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

    // Requests: two incoming and one outgoing, each with its own menu.
    expect(find.byType(FriendSafetyMenu), findsNWidgets(3));

    // An incoming request's menu reports; blocking stays on the card's own
    // "decline and block" button. No photo is shown, so no photo report.
    // (The cards' own buttons read "Block" too, so count them first.)
    final blockButtons = find.text('Block').evaluate().length;
    await tester.tap(find.byType(FriendSafetyMenu).first);
    await tester.pumpAndSettle();
    expect(find.text('Report name'), findsOneWidget);
    expect(find.text('Report photo'), findsNothing);
    expect(find.text('Block'), findsNWidgets(blockButtons));

    // Reporting asks why and sends it.
    await tester.tap(find.text('Report name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advertising'));
    await tester.pumpAndSettle();
    expect(repo.reports, hasLength(1));
    expect(repo.reports.single.$2, ReportKind.nickname);
    expect(repo.reports.single.$3, ReportReason.ads);

    // Org members: everyone listed (never me) has the full menu.
    final orgs = switch (await repo.getMyOrgs()) {
      Ok(:final value) => value,
      Error() => throw StateError('no orgs'),
    };
    router.push(
      '/friends/org',
      extra: orgs.firstWhere((o) => o.id == 'org_sanxia'),
    );
    await tester.pumpAndSettle();
    final menus = find.byType(FriendSafetyMenu);
    expect(menus, findsWidgets);
    final target = tester.widget<FriendSafetyMenu>(menus.first).person;
    expect(target.userId, isNot(repo.meId));

    await tester.tap(menus.first);
    await tester.pumpAndSettle();
    expect(find.text('Report name'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);

    // Blocking confirms first, then really blocks.
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Block'),
      ),
    );
    await tester.pumpAndSettle();
    final blocked = switch (await repo.getBlocked()) {
      Ok(:final value) => value,
      Error() => throw StateError('no block list'),
    };
    expect(blocked.map((p) => p.userId), contains(target.userId));

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
