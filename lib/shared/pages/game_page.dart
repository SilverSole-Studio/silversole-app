import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Entertainment hub ("娛樂"): a "遊戲" (games) tab and a "兌換" (redeem) tab.
/// Both bodies are placeholders for now — defaults to the games tab.
class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'entertainment'.tr(),
            style: context.textTheme.titleLarge,
          ),
          bottom: TabBar(
            labelStyle: context.textTheme.titleMedium,
            unselectedLabelStyle: context.textTheme.titleMedium,
            tabs: [
              Tab(text: 'game'.tr()),
              Tab(text: 'redeem'.tr()),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _placeholder(context, LucideIcons.gamepad2, 'game'.tr()),
              _placeholder(context, LucideIcons.gift, 'redeem'.tr()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon, String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [
          Icon(icon, size: 56, color: context.colorScheme.onSurfaceVariant),
          Text(label, style: context.textTheme.titleMedium),
          Text(
            'coming_soon'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
