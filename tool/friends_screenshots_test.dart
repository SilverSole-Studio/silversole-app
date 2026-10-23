// Renders every friends screen in each theme variant to PNG, with real fonts
// and the seeded demo repository. Not part of the test suite (it lives in
// tool/, which `flutter test` does not pick up by default); run it by hand:
//
//   flutter test tool/friends_screenshots_test.dart
//
// Output: docs/screenshots/friends/<theme>_<NN>_<screen>.png
//
// Themes: `classic` (light), `classic-dark` (the classic theme's default in
// the app, since AppSettings.darkMode defaults to true), `mascot` (light only;
// the app pins mascot to light).
//
// Before the first run: `python -I tool/make_cjk_fonts.py` (static CJK weights).
//
// Not covered: the QR scanner (needs a camera).
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization_loader/easy_localization_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/app.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/theme/app_theme_t2.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/pages/friends/enter_code_page.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

const _outDir = 'docs/screenshots/friends';
const _viewSize = Size(412, 915);
const _dpr = 2.0;
const _statusBar = 28.0;

/// easy_localization's own CSV loader reads through rootBundle, which never
/// completes under the test's fake async clock. Parse the file up front.
class _PreloadedCsvLoader extends AssetLoader {
  _PreloadedCsvLoader(this.parser);
  final CSVParser parser;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      parser.getLanguageMap(locale.toString());
}

late CSVParser _csv;

Future<void> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) throw StateError('font file missing: $p');
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

/// CJK fallback family name registered in the harness only.
const _cjk = 'HarnessCJK';

class _Variant {
  const _Variant(this.name, this.theme);
  final String name;
  final ThemeData Function() theme;
}

final _variants = <_Variant>[
  _Variant('classic', () => appTheme(Brightness.light)),
  _Variant('classic-dark', () => appTheme(Brightness.dark)),
  _Variant('mascot', () => appThemeT2(Brightness.light)),
];

ThemeData _withCjk(ThemeData t) {
  TextTheme fix(TextTheme tt) => tt.apply(fontFamilyFallback: const [_cjk]);
  return t.copyWith(
    textTheme: fix(t.textTheme),
    primaryTextTheme: fix(t.primaryTextTheme),
  );
}

Future<T> _ok<T>(Future<Result<T>> r) async => switch (await r) {
  Ok(:final value) => value,
  Error(:final error) => throw error,
};

Future<FakeFriendsRepository> _repo({bool named = true}) async {
  final repo = FakeFriendsRepository.seeded(
    latency: Duration.zero,
    simulateQrScan: false,
  );
  if (named) await repo.updateProfile(nickname: '王阿姨', avatarPreset: 8);
  return repo;
}

/// Lets timers, async providers and image decodes run. Decoding happens on
/// real threads, so the fake clock alone is not enough.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() async {
      for (var n = 1; n <= 12; n++) {
        final id = n.toString().padLeft(2, '0');
        await precacheImage(
          AssetImage('assets/mascot-assets/avatars/av_$id.webp'),
          tester.element(find.byType(Scaffold).first),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
  }
  await tester.pump(const Duration(milliseconds: 300));
}

final _boundaryKey = GlobalKey();

Future<GoRouter> _pump(
  WidgetTester tester,
  _Variant variant,
  FakeFriendsRepository repo,
) async {
  tester.view
    ..physicalSize = _viewSize * _dpr
    ..devicePixelRatio = _dpr
    ..padding = const FakeViewPadding(top: _statusBar * _dpr)
    ..viewPadding = const FakeViewPadding(top: _statusBar * _dpr);
  final router = GoRouter(
    initialLocation: '/friends',
    routes: [friendsRoute(enabled: true)],
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        key: UniqueKey(),
        overrides: [friendsRepositoryProvider.overrideWithValue(repo)],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: _PreloadedCsvLoader(_csv),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('zh', 'TW'),
          child: Builder(
            builder: (context) => MaterialApp.router(
              debugShowCheckedModeBanner: false,
              scaffoldMessengerKey: App.scaffoldMessengerKey,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: _withCjk(variant.theme()),
              routerConfig: router,
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return router;
}

Future<void> _shot(WidgetTester tester, _Variant v, String name) async {
  await _settle(tester);
  final bytes = await tester.runAsync(() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final file = File('$_outDir/${v.name}_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('wrote ${file.path} (${(bytes.length / 1024).round()} KB)');
}

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(
      find.descendant(
        of: find.byType(CodeKeypad),
        matching: find.widgetWithText(OutlinedButton, d),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _csv = CSVParser(
      File('assets/translations/strings.csv').readAsStringSync(),
    );

    final flutterRoot =
        Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/Admin/flutter';
    final pubCache =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['LOCALAPPDATA']}/Pub/Cache';
    final lucide = Directory('$pubCache/hosted/pub.dev')
        .listSync()
        .whereType<Directory>()
        .firstWhere((d) => d.path.contains('lucide_icons_flutter-'));

    await _loadFamily('Google Sans', [
      'assets/fonts/GoogleSans-VariableFont.ttf',
    ]);
    await _loadFamily('DM Sans', [
      'assets/mascot-assets/fonts/DMSans-Regular.ttf',
      'assets/mascot-assets/fonts/DMSans-Medium.ttf',
      'assets/mascot-assets/fonts/DMSans-Bold.ttf',
    ]);
    // Static weights cut by tool/make_cjk_fonts.py; the raw variable font
    // would render everything in its default Thin weight.
    const staticDir = 'build/friends_screenshot_fonts';
    await _loadFamily(
      _cjk,
      Directory(staticDir).existsSync()
          ? [
              for (final w in [400, 500, 700]) '$staticDir/NotoSansTC-$w.ttf',
            ]
          : ['C:/Windows/Fonts/NotoSansTC-VF.ttf'],
    );
    await _loadFamily('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
    await _loadFamily('packages/lucide_icons_flutter/Lucide', [
      '${lucide.path}/assets/lucide.ttf',
    ]);
  });

  for (final v in _variants) {
    group(v.name, () {
      testWidgets('screens', (tester) async {
        addTearDown(tester.view.reset);

        // 01 hub with the pending-request badge, then scrolled to the list.
        {
          final repo = await _repo();
          await _pump(tester, v, repo);
          await _shot(tester, v, '01_hub');
          await tester.drag(find.byType(ListView).first, const Offset(0, -420));
          await _settle(tester);
          await _shot(tester, v, '02_hub_list');
        }

        // 03 first-run profile (no nickname yet).
        {
          final repo = await _repo(named: false);
          await _pump(tester, v, repo);
          await _shot(tester, v, '03_profile_first_run');
        }

        // 04 my QR.
        {
          final repo = await _repo();
          final router = await _pump(tester, v, repo);
          unawaited(router.push('/friends/my-qr'));
          await _settle(tester);
          await _shot(tester, v, '04_my_qr');
        }

        // 05 enter friend code with four digits, 06 preview sheet after all.
        {
          final repo = await _repo();
          final router = await _pump(tester, v, repo);
          unawaited(router.push('/friends/code', extra: CodeMode.friend));
          await _settle(tester);
          await _tapDigits(tester, '2236');
          await _shot(tester, v, '05_enter_code');

          await _tapDigits(
            tester,
            FakeFriendsRepository.demoFriendCode.substring(4),
          );
          await _settle(tester);
          await _shot(tester, v, '06_add_friend_sheet');
        }

        // 07 org code keypad -> join-org sheet.
        {
          final repo = await _repo();
          final router = await _pump(tester, v, repo);
          unawaited(router.push('/friends/code', extra: CodeMode.org));
          await _settle(tester);
          await _tapDigits(tester, FakeFriendsRepository.demoOrgCode);
          await _settle(tester);
          await _shot(tester, v, '07_join_org_sheet');
        }

        // 08 requests (incoming + outgoing).
        {
          final repo = await _repo();
          final router = await _pump(tester, v, repo);
          unawaited(router.push('/friends/requests'));
          await _settle(tester);
          await _shot(tester, v, '08_requests');
        }

        // 09 orgs list, 10 org members.
        {
          final repo = await _repo();
          final router = await _pump(tester, v, repo);
          unawaited(router.push('/friends/orgs'));
          await _settle(tester);
          await _shot(tester, v, '09_orgs');

          final orgs = await tester.runAsync(() => _ok(repo.getMyOrgs()));
          unawaited(router.push('/friends/org', extra: orgs!.first));
          await _settle(tester);
          await _shot(tester, v, '10_org_members');
        }

        // 11 friend detail, 12 report sheet.
        {
          final repo = await _repo();
          final router = await _pump(tester, v, repo);
          final friends = await tester.runAsync(() => _ok(repo.getFriends()));
          unawaited(router.push('/friends/person', extra: friends!.first));
          await _settle(tester);
          await _shot(tester, v, '11_friend_detail');

          await tester.tap(find.text('friends_report_name'.tr()));
          await _settle(tester);
          await _shot(tester, v, '12_report_sheet');
        }

        // 13 blocked list.
        {
          final repo = await _repo();
          final router = await _pump(tester, v, repo);
          unawaited(router.push('/friends/blocked'));
          await _settle(tester);
          await _shot(tester, v, '13_blocked');
        }

        // Drop the tree so the QR page's periodic timer is cancelled.
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
