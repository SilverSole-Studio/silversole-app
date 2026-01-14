import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/shared/providers/auth_provider.dart';
import 'package:silversole/shared/widgets/account_card.dart';
import 'package:silversole/shared/widgets/update_check_bottom_modal.dart';

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
    final user = ref.watch(authUserProvider);
    final email = user?.email ?? 'not_signed_in'.tr();
    final uuid = user?.uuid ?? '-';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              'silversole'.tr(),
              style: TextStyle(fontFamily: 'Oxanium', fontVariations: const [FontVariation('wght', 600)]),
            ),
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                spacing: 32,
                children: [
                  SizedBox(width: double.infinity, height: 100, child: accountCard(context, email, uuid)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      OutlinedButton(
                        onPressed: user == null ? goToLogin : null,
                        child: Text('sign_in'.tr(), style: Theme.of(context).textTheme.titleMedium),
                      ),
                      OutlinedButton(
                        onPressed: user != null ? signOut : null,
                        child: Text('sign_out'.tr(), style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 1000,
                    child: OutlinedButton(onPressed: comingSoon, child: Text('')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
