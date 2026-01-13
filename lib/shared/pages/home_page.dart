import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/shared/widgets/update_check_bottom_modal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showUpdateVersionDialog(context);
    });
  }

  void goToLogin() => context.push('/sign-in');

  @override
  Widget build(BuildContext context) {
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
          SliverToBoxAdapter(
            child: Column(
              spacing: 32,
              children: [
                OutlinedButton(
                  onPressed: goToLogin,
                  child: Text('sign_in'.tr(), style: Theme.of(context).textTheme.titleMedium),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 1000,
                  child: OutlinedButton(onPressed: comingSoon, child: Text('')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
