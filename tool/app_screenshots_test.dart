// Renders the main app pages in both themes, light and dark, to PNG with real
// fonts. Not part of the test suite (it lives in tool/, which `flutter test`
// does not pick up by default); run it by hand:
//
//   python -I tool/make_cjk_fonts.py      (once; needs fontTools)
//   flutter test tool/app_screenshots_test.dart
//   python -I tool/app_overview.py        (tiles them into one overview PNG)
//
// Output: build/app_refresh_shots/<variant>_<NN>_<page>.png
//
// Variants: classic, classic-dark, mascot, mascot-dark. The map tab shows a
// plain placeholder where Google Maps would be (a platform view cannot be
// rendered in a test).
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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/core/utils/system_font_scale.dart';
import 'package:silversole/shared/models/app_settings.dart';
import 'package:silversole/shared/models/auth_model.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/foot_check_result_page.dart';
import 'package:silversole/shared/pages/friends/friends_routes.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/home_page.dart';
import 'package:silversole/shared/pages/map_page.dart';
import 'package:silversole/shared/pages/person_page.dart';
import 'package:silversole/shared/pages/sign_in_page.dart';
import 'package:silversole/shared/pages/subscription_page.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/pages/theme_two/map_page_t2.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/providers/last_foot_check_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/app_navigation_bar.dart';

const _outDir = 'build/app_refresh_shots';
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

const _cjk = 'HarnessCJK';

class _Variant {
  const _Variant(this.name, this.theme, {required this.mascot});
  final String name;
  final ThemeData Function() theme;
  final bool mascot;
}

final _variants = <_Variant>[
  _Variant('classic', () => appTheme(Brightness.light), mascot: false),
  _Variant('classic-dark', () => appTheme(Brightness.dark), mascot: false),
  _Variant('mascot', () => appThemeT2(), mascot: true),
  _Variant('mascot-dark', () => appThemeT2(), mascot: true),
];

ThemeData _withCjk(ThemeData t) {
  TextTheme fix(TextTheme tt) => tt.apply(fontFamilyFallback: const [_cjk]);
  // Button themes carry their own text style (built before this fallback
  // existed), so each needs the fallback too or CJK labels render as boxes.
  ButtonStyle? fixButton(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStatePropertyAll(
      t.textTheme.labelLarge?.copyWith(fontFamilyFallback: const [_cjk]),
    ),
  );
  return t.copyWith(
    textTheme: fix(t.textTheme),
    primaryTextTheme: fix(t.primaryTextTheme),
    filledButtonTheme: FilledButtonThemeData(
      style: fixButton(t.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: fixButton(t.outlinedButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: fixButton(t.elevatedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: fixButton(t.textButtonTheme.style),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: fixButton(t.segmentedButtonTheme.style),
    ),
  );
}

class _SignedIn extends AuthUserNotifier {
  @override
  UserData? build() => const UserData(
    email: 'grandma.wang@example.com',
    uuid: '123e4567-e89b-12d3-a456-426614174000',
  );
}

class _Settings extends SettingsNotifier {
  _Settings(this.variant);
  final AppThemeVariant variant;

  @override
  AppSettings build() => AppSettings(
    themeVariant: variant,
    pairedDevicesList: const [
      BlePairedDevice(
        remoteId: 'r',
        name: 'SilverSole',
        deviceId: '00000000000000BB',
        isPreferred: true,
        lastBatteryPercent: 77,
      ),
    ],
  );
}

class _LastCheck extends LastFootCheckNotifier {
  @override
  FootCheckRecord? build() => FootCheckRecord(
    rating: FootCheckRating.veryGood,
    takenAt: DateTime.now(),
  );
}

/// A stand-in for the Google map.
Widget _fakeMap(BuildContext context) => ColoredBox(
  color: Theme.of(context).colorScheme.surfaceContainerHighest,
  child: Center(
    child: Icon(
      LucideIcons.mapPin,
      size: 48,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
);

/// A tab page with the bottom navigation under it.
Widget _tab(int index, Widget page) => Scaffold(
  body: page,
  bottomNavigationBar: appNavigationBar(
    selectedIndex: index,
    onDestinationSelected: (_) {},
    icons: kHomeNavIcons,
    labels: kHomeNavLabels,
  ),
);

class _Shot {
  const _Shot(this.name, this.build);
  final String name;
  final Widget Function(_Variant v) build;
}

final _shots = <_Shot>[
  _Shot(
    '01_today',
    (v) => _tab(0, v.mascot ? const HomeBodyT2() : const HomeBody()),
  ),
  _Shot(
    '02_map',
    (v) => _tab(
      1,
      v.mascot
          ? MapPageT2(mapBuilder: (c, s) => Builder(builder: _fakeMap))
          : MapPage(mapBuilder: (c, s) => Builder(builder: _fakeMap)),
    ),
  ),
  _Shot(
    '03_report',
    (v) => _tab(3, v.mascot ? const AnalyticsPageT2() : const AnalyticsPage()),
  ),
  _Shot('04_mine', (v) => _tab(4, const PersonPage())),
  _Shot(
    '05_check_result',
    (v) => FootCheckResultPage(
      report: FootCheckReport(
        balance: const FootLoadBalance(foreRatio: 0.40, medialRatio: 0.50),
        samples: 1234,
        collected: const Duration(seconds: 60),
      ),
    ),
  ),
  _Shot('06_sign_in', (v) => const SignInPage()),
  _Shot('07_subscription', (v) => const SubscriptionPage()),
];

GoRouter _single(Widget page) => GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => page)],
);

/// Lets timers, async providers and image decodes run. Decoding happens on
/// real threads, so the fake clock alone is not enough.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.runAsync(() async {
      for (final asset in [
        'assets/mascot-assets/happy.webp',
        'assets/mascot-assets/applaud.webp',
        'assets/mascot-assets/checking.webp',
        'assets/images/silversole_app_logo.png',
        'assets/images/silversole_full.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(Scaffold).first),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
  }
  await tester.pump(const Duration(milliseconds: 300));
}

final _boundaryKey = GlobalKey();

Future<void> _pump(WidgetTester tester, _Variant v, GoRouter router) async {
  tester.view
    ..physicalSize = _viewSize * _dpr
    ..devicePixelRatio = _dpr
    ..padding = const FakeViewPadding(top: _statusBar * _dpr)
    ..viewPadding = const FakeViewPadding(top: _statusBar * _dpr);
  final repo = FakeFriendsRepository.seeded(
    latency: Duration.zero,
    simulateQrScan: false,
  );
  await repo.updateProfile(nickname: '王阿姨', avatarPreset: 8);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        key: UniqueKey(),
        overrides: [
          friendsRepositoryProvider.overrideWithValue(repo),
          authUserProvider.overrideWith(_SignedIn.new),
          lastFootCheckProvider.overrideWith(_LastCheck.new),
          settingsProvider.overrideWith(
            () => _Settings(
              v.mascot ? AppThemeVariant.mascot : AppThemeVariant.classic,
            ),
          ),
        ],
        child: EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          path: 'assets/translations/strings.csv',
          assetLoader: _PreloadedCsvLoader(_csv),
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('zh', 'TW'),
          child: Builder(
            builder: (context) => MaterialApp.router(
              debugShowCheckedModeBanner: false,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: _withCjk(v.theme()),
              // The default text size, so the shots show what people get.
              builder: (context, child) => applySystemFontScale(
                context,
                child,
                textSize: AppTextSize.normal,
              ),
              routerConfig: router,
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
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
      testWidgets('pages', (tester) async {
        addTearDown(tester.view.reset);

        for (final shot in _shots) {
          await _pump(tester, v, _single(shot.build(v)));
          await _shot(tester, v, shot.name);
        }

        // Friends hub: a nested route, not a single page.
        await _pump(
          tester,
          v,
          GoRouter(
            initialLocation: '/friends',
            routes: [friendsRoute(enabled: true)],
          ),
        );
        await _shot(tester, v, '08_friends');

        // Drop the tree so periodic timers are cancelled.
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
