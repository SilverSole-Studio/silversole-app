import 'dart:math';

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
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/friends/nickname_generator.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/pages/friends/nickname_setup_page.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';
import '../helpers/translations.dart';
import 'friends_page_test.dart' show expectBigButtons, expectReadableText;

class _SignedIn extends AuthUserNotifier {
  @override
  UserData? build() => const UserData(email: 'wang@example.com', uuid: 'me');
}

class _SignedOut extends AuthUserNotifier {
  @override
  UserData? build() => null;
}

/// A backend that cannot be reached.
class _OfflineRepo extends FakeFriendsRepository {
  @override
  Future<Result<MyProfile>> getMyProfile() async =>
      Result.error(const FriendException(FriendError.offline));
}

/// One scenario: who is signed in, which backend the app talks to, and
/// whether friends are switched on.
class _Scenario {
  _Scenario({
    required this.repo,
    this.signedIn = true,
    this.friendsOn = true,
    int seed = 1,
  }) : generator = NicknameGenerator(Random(seed));

  final FakeFriendsRepository repo;
  final bool signedIn;
  final bool friendsOn;
  final NicknameGenerator generator;
}

const _home = 'HOME-SCREEN';

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

FakeFriendsRepository _newRepo() =>
    FakeFriendsRepository(latency: Duration.zero, simulateQrScan: false);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One EasyLocalization mount for the whole file (it keeps global state, a
  // second mount stays blank); each scenario swaps the ProviderScope and
  // router underneath it.
  testWidgets('the name step comes before the home screen', (tester) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final scenario = ValueNotifier<_Scenario>(_Scenario(repo: _newRepo()));

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
        path: 'assets/translations/strings.csv',
        assetLoader: CsvAssetLoader(),
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('zh', 'TW'),
        child: Builder(
          builder: (context) => ValueListenableBuilder<_Scenario>(
            valueListenable: scenario,
            builder: (_, s, _) => ProviderScope(
              key: ObjectKey(s),
              overrides: [
                friendsRepositoryProvider.overrideWithValue(s.repo),
                friendsEnabledProvider.overrideWithValue(s.friendsOn),
                nicknameGeneratorProvider.overrideWithValue(s.generator),
                authUserProvider.overrideWith(
                  s.signedIn ? _SignedIn.new : _SignedOut.new,
                ),
              ],
              child: MaterialApp.router(
                scaffoldMessengerKey: App.scaffoldMessengerKey,
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: appTheme(Brightness.light),
                routerConfig: GoRouter(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (_, _) => const NicknameGate(
                        child: Scaffold(body: Center(child: Text(_home))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleTranslations(tester);

    Future<void> start(_Scenario s) async {
      scenario.value = s;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    // No nickname yet: the name step comes first.
    final repo = _newRepo();
    await start(_Scenario(repo: repo));
    expect(find.text('取個名字'), findsOneWidget);
    expect(find.text(_home), findsNothing);
    expectReadableText(tester);
    expectBigButtons(tester);

    // A suggestion is already in the field and is a usable name.
    final first = _fieldText(tester);
    expect(first, isNotEmpty);
    expect(validateNickname(first), isNull);

    // The dice changes it every time, and every one is usable.
    final seen = <String>{first};
    var shown = first;
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.casino_outlined));
      await tester.pump();
      final now = _fieldText(tester);
      expect(now, isNot(shown));
      expect(validateNickname(now), isNull);
      shown = now;
      seen.add(now);
    }
    expect(seen.length, greaterThan(1));

    // Pick another picture (the fourth in the grid), then accept the name.
    await tester.tap(find.byType(FriendAvatar).at(3));
    await tester.pump();
    await tester.tap(find.text('就用這個'));
    await tester.pumpAndSettle();

    // Only now does the app open, and the name and picture were stored.
    expect(find.text(_home), findsOneWidget);
    expect(find.text('取個名字'), findsNothing);
    final saved = switch (await repo.getMyProfile()) {
      Ok(:final value) => value,
      Error() => fail('profile should load'),
    };
    expect(saved.nickname, shown);
    expect(saved.avatarPreset, 4);
    expect(tester.takeException(), isNull);

    // A name that breaks the rules is held back, with a reason.
    final repo2 = _newRepo();
    await start(_Scenario(repo: repo2));
    await tester.enterText(find.byType(TextField), '王');
    await tester.tap(find.text('就用這個'));
    await tester.pumpAndSettle();
    expect(find.text(_home), findsNothing);
    expect(find.text('取個名字'), findsOneWidget);
    expect(
      find.text(friendErrorKey(FriendError.nicknameInvalid).tr()),
      findsOneWidget,
    );
    final stillNone = switch (await repo2.getMyProfile()) {
      Ok(:final value) => value.nickname,
      Error() => 'error',
    };
    expect(stillNone, isNull);

    // Already has a name: straight to the home screen.
    final named = _newRepo();
    await named.updateProfile(nickname: '王阿姨');
    await start(_Scenario(repo: named));
    expect(find.text(_home), findsOneWidget);
    expect(find.text('取個名字'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    // A taken-down name already carries the placeholder, so the user is not
    // sent back through the first-login step (the friends page asks instead).
    final removed = _newRepo();
    await removed.updateProfile(nickname: '王阿姨');
    removed.adminRemoveNickname('me');
    await start(_Scenario(repo: removed));
    expect(find.text(_home), findsOneWidget);

    // Backend unreachable: let the user in rather than lock them out.
    await start(_Scenario(repo: _OfflineRepo()));
    expect(find.text(_home), findsOneWidget);
    expect(find.text('取個名字'), findsNothing);

    // Signed out, or friends switched off (a release before the backend is
    // live): the step never shows.
    await start(_Scenario(repo: _newRepo(), signedIn: false));
    expect(find.text(_home), findsOneWidget);
    await start(_Scenario(repo: _newRepo(), friendsOn: false));
    expect(find.text(_home), findsOneWidget);
    expect(find.text('取個名字'), findsNothing);
  });
}
