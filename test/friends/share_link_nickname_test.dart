import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/app.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import '../helpers/translations.dart';

/// Someone who opens a friend's link before they have a nickname picks one
/// first (the same step as on the friends page), then sees who sent it.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no nickname yet: asked for one, then the link opens', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final token = 'a' * 32;
    final repo = FakeFriendsRepository()
      ..addUser('wang', '王阿姨', preset: 2, code: '31415926')
      ..addShareLink('wang', token);
    final router = GoRouter(
      initialLocation: '/f/?t=$token',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        friendsRoute(enabled: true),
        shareLinkRoute(enabled: true),
      ],
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
    await settleTranslations(tester);

    expect(find.text('就用這個'), findsOneWidget);
    expect(find.text('加他當朋友'), findsNothing);
    await tester.tap(find.text('就用這個'));
    await tester.pumpAndSettle();
    expect(find.text('王阿姨'), findsOneWidget);
    expect(find.text('加他當朋友'), findsOneWidget);
    expect(repo.incomingCountFor('wang'), 0);
    expect(tester.takeException(), isNull);
  });
}
