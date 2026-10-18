import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Every piece of text on screen is at least 18px, apart from the debug-only
/// demo hint (spec §5.3).
void expectReadableText(WidgetTester tester) {
  for (final p in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    final text = p.text.toPlainText();
    if (text.trim().isEmpty || text.startsWith('Demo data')) continue;
    double? smallest;
    p.text.visitChildren((span) {
      final size = span.style?.fontSize;
      if (size != null && (smallest == null || size < smallest!)) {
        smallest = size;
      }
      return true;
    });
    final size = smallest ?? p.text.style?.fontSize ?? 14;
    expect(size, greaterThanOrEqualTo(18), reason: '"$text" is ${size}px');
  }
}

/// Every button is at least 56px tall (spec §5.3).
void expectBigButtons(WidgetTester tester) {
  final buttons = find.byWidgetPredicate(
    (w) => w is FilledButton || w is OutlinedButton || w is TextButton,
  );
  for (final element in buttons.evaluate()) {
    final size = tester.getSize(find.byWidget(element.widget).first);
    expect(
      size.height,
      greaterThanOrEqualTo(56),
      reason: '${element.widget.runtimeType} is ${size.height}px tall',
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // One mount for the whole flow: EasyLocalization keeps global state.
  testWidgets('first run, accepting a request, adding by code', (tester) async {
    await EasyLocalization.ensureInitialized();
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeFriendsRepository.seeded(
      latency: Duration.zero,
      simulateQrScan: false,
    );
    final router = GoRouter(
      initialLocation: '/friends',
      routes: [friendsRoute],
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

    // First visit: pick a name before anything else.
    expect(find.text('先取一個稱呼'), findsOneWidget);
    expectReadableText(tester);
    expectBigButtons(tester);
    await tester.enterText(find.byType(TextField), '王阿姨');
    await tester.tap(find.text('好了，去加朋友'));
    await tester.pumpAndSettle();

    // The hub: four friends, two people waiting on me.
    expect(find.text('陳伯伯'), findsOneWidget);
    expect(find.text('朋友（4／100）'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // requests badge
    expectReadableText(tester);
    expectBigButtons(tester);
    expect(tester.takeException(), isNull);

    // Accept 張阿姨.
    await tester.tap(find.text('邀請'));
    await tester.pumpAndSettle();
    expect(find.text('張阿姨'), findsOneWidget);
    expectReadableText(tester);
    expectBigButtons(tester);
    await tester.tap(find.text('同意').first);
    await tester.pumpAndSettle();
    expect(repo.friendCount('me'), 5);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('朋友（5／100）'), findsOneWidget);

    // Add 李伯伯 by typing his code on the keypad.
    await tester.tap(find.text('輸入好友碼'));
    await tester.pumpAndSettle();
    expectReadableText(tester);
    expectBigButtons(tester);
    // The "now friends" snack bar would sit over the bottom keypad row.
    App.scaffoldMessengerKey.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();
    for (final d in FakeFriendsRepository.demoFriendCode.split('')) {
      await tester.tap(find.widgetWithText(OutlinedButton, d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('李伯伯'), findsOneWidget);
    await tester.tap(find.text('加他當朋友'));
    await tester.pumpAndSettle();
    final waiting = switch (await repo.getFriendRequests()) {
      Ok(:final value) => value.where((r) => !r.incoming),
      Error() => const <FriendRequest>[],
    };
    expect(waiting.map((r) => r.other.userId), contains('u_li'));
    expect(repo.areFriends('me', 'u_li'), isFalse); // waits for his yes

    // The org list: one tap to ask someone.
    await tester.tap(find.text('我的據點'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('三峽示範據點'));
    await tester.pumpAndSettle();
    expect(find.text('吳奶奶'), findsOneWidget);
    expect(find.text('蔡阿公'), findsNothing); // chose not to be listed
    expect(find.text('好康報報'), findsNothing); // blocked
    expectReadableText(tester);
    expectBigButtons(tester);
    expect(tester.takeException(), isNull);
  });
}
