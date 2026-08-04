import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/app_theme_variant.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/game_page.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/map_page.dart';
import 'package:silversole/shared/pages/person_page.dart';
import 'package:silversole/shared/pages/theme_two/home_body_t2.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/app_navigation_bar.dart';
import 'package:silversole/shared/widgets/update_check_bottom_modal.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showUpdateVersionDialog(context);
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
      const MapPage(),
      // const DevicesPage(),
      const AnalyticsPage(),
      const GamePage(),
      const PersonPage(),
    ];
    return Scaffold(
      bottomNavigationBar: appNavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (index) => setState(() => _page = index),
        icons: const [
          Icons.home,
          LucideIcons.map,
          // LucideIcons.monitorSmartphone,
          Icons.analytics,
          LucideIcons.gamepad2,
          Icons.settings,
        ],
        labels: const [
          'home',
          'map',
          // 'devices',
          'analytics',
          'entertainment',
          'settings',
        ],
      ),
      body: IndexedStack(index: _page, children: pages),
    );
  }
}
