import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/core/utils/play_in_app_update.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/map_page.dart';
import 'package:silversole/shared/pages/person_page.dart';
import 'package:silversole/shared/pages/plaza_tab_page.dart';
import 'package:silversole/shared/pages/theme_two/analytics_page_t2.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/pages/theme_two/map_page_t2.dart';
import 'package:silversole/shared/providers/home_tab_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/app_navigation_bar.dart';
import 'package:silversole/shared/widgets/update_check_bottom_modal.dart';

/// The five bottom-navigation tabs, in order: 今天／地圖／遊戲／報告／我的.
/// One icon family (Lucide line icons) for all five; the selected tab is shown
/// by the theme's filled indicator.
const List<IconData> kHomeNavIcons = [
  LucideIcons.calendarCheck,
  LucideIcons.map,
  LucideIcons.gamepad2,
  LucideIcons.chartColumn,
  LucideIcons.circleUser,
];

/// Translation keys of [kHomeNavIcons]' labels.
const List<String> kHomeNavLabels = [
  'nav_today',
  'nav_map',
  'nav_game',
  'nav_report',
  'nav_mine',
];

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // A Play install updates through Play only — Play policy forbids
      // pointing it at another download. Sideloaded APKs (GitHub Releases)
      // cannot use Play updates, so they keep the GitHub prompt.
      // iOS updates through TestFlight / the App Store.
      final route = updateRoute(
        defaultTargetPlatform,
        installedFromPlay: await PlayInAppUpdate.isInstalledFromPlay(),
      );
      if (!mounted) return;
      switch (route) {
        case UpdateRoute.play:
          await PlayInAppUpdate.checkForUpdate();
        case UpdateRoute.github:
          showUpdateVersionDialog(context);
        case UpdateRoute.none:
          break;
      }
    });
  }

  void goToLogin() => context.push('/sign-in');

  @override
  Widget build(BuildContext context) {
    // Each theme owns its own home implementation; the rest of the tabs are
    // shared until they get a mascot version too.
    final isMascot =
        ref.watch(settingsProvider).themeVariant == AppThemeVariant.mascot;
    final pages = [
      isMascot ? const HomeBodyT2() : const HomeBody(),
      isMascot ? const MapPageT2() : const MapPage(),
      // const DevicesPage(),
      // 遊戲分頁直接開 H5 粗哥廣場（取代卡片清單）
      const PlazaTabPage(),
      isMascot ? const AnalyticsPageT2() : const AnalyticsPage(),
      const PersonPage(),
    ];
    final page = ref.watch(homeTabProvider);
    // The games tab (town and games alike) has no bar, so a stray tap does not
    // switch tabs; the town menu's 「回 App」 and the back button in the town
    // come back through [homeTabProvider].
    final hideBar = pages[page] is PlazaTabPage;
    return Scaffold(
      bottomNavigationBar: hideBar
          ? null
          : appNavigationBar(
              selectedIndex: page,
              onDestinationSelected: ref.read(homeTabProvider.notifier).select,
              icons: kHomeNavIcons,
              labels: kHomeNavLabels,
            ),
      // One tab in the tree at a time. IndexedStack kept every tab mounted,
      // which left the map's Android platform view laid out off-screen;
      // swapping page types under it on a theme switch corrupted the render
      // tree (RenderAndroidView calling localToGlobal on an unlaid-out box,
      // then removeRenderObjectChild asserting on a stale child). Per-tab
      // scroll position is not preserved as a result — page content is
      // rebuilt from the same providers, so nothing is lost but the offset.
      body: pages[page],
    );
  }
}
