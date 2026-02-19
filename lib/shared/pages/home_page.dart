import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/shared/pages/analytics_page.dart';
import 'package:silversole/shared/pages/devices_page.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/person_page.dart';
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
    final pages = [const HomeBody(), const DevicesPage(), const AnalyticsPage(), const PersonPage()];
    return Scaffold(
      bottomNavigationBar: appNavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (index) => setState(() => _page = index),
      ),
      body: IndexedStack(index: _page, children: pages),
    );
  }
}
