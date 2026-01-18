import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/pages/home_body.dart';
import 'package:silversole/shared/pages/person_page.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
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

  Future<void> signOut() async {
    // Check is signed in
    final user = ref.read(authUserProvider);
    if (user == null) return;

    // Sign out
    final authService = ref.read(authServiceProvider);
    final res = await authService.supabaseSignOut();
    switch (res) {
      case Ok<void>():
        ref.read(authUserProvider.notifier).setUser(null);
        showMessage('sign_out_success'.tr());
      case Error<void>():
        showErrorSnakeBar(res.error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const HomeBody(), const PersonPage()];
    return Scaffold(
      bottomNavigationBar: appNavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (index) => setState(() => _page = index),
      ),
      body: IndexedStack(index: _page, children: pages),
    );
  }
}
