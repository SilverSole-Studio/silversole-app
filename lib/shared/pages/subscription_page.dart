import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/app_spacing.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/core/diamonds/diamond_repository.dart';
import 'package:silversole/shared/providers/diamonds_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/subscription_provider.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// The subscription plan page (user 2026-11-01: NT$149 a month, unlocks the
/// real-goods tab of the game's 兌換站). No billing yet: the subscribe button
/// says "coming soon", and an admin opens a subscription by hand on the
/// server. Whether it is open comes from the server ([subscriptionActiveProvider]);
/// debug builds / developer mode also get a test switch that pretends to be
/// subscribed. Shows the diamond balance (2026-11-02): earned only by moving
/// 15 minutes a day with the insole, +10 a day, up to 300 a month.
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  @override
  void initState() {
    super.initState();
    // Ask the server again: the subscription may have been opened since.
    Future.microtask(() {
      if (mounted) ref.read(diamondsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(subscriptionActiveProvider);
    final diamonds = ref.watch(diamondsProvider.select((s) => s.balance));
    final fake = ref.watch(fakeSubscriptionProvider);
    final devMode = ref.watch(
      settingsProvider.select((s) => s.firmwareDevMode),
    );
    final perks = [
      ('subscription_perk_real_goods', LucideIcons.gift),
      ('subscription_perk_more', LucideIcons.sparkles),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('subscription'.tr(), style: context.textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Text(
                  'subscription_plan_name'.tr(),
                  style: context.textTheme.titleLarge,
                ),
                Text(
                  'subscription_price'.tr(args: ['$kSubscriptionMonthlyPrice']),
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (active)
                  Chip(
                    avatar: const Icon(LucideIcons.badgeCheck, size: 18),
                    label: Text('subscription_active'.tr()),
                  ),
              ],
            ),
          ),
          if (diamonds != null && (active || diamonds.balance > 0)) ...[
            const SizedBox(height: AppSpacing.base),
            _DiamondCard(balance: diamonds),
          ],
          const SizedBox(height: AppSpacing.base),
          SectionCard(
            title: 'subscription_perks_title'.tr(),
            child: Column(
              children: [
                for (final (key, icon) in perks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icon, color: context.colorScheme.primary),
                    title: Text(key.tr()),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          FilledButton(
            // No billing yet.
            onPressed: null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(
              active
                  ? 'subscription_active'.tr()
                  : 'subscription_coming_soon'.tr(),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'subscription_notes'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (kDebugMode || devMode) ...[
            const SizedBox(height: AppSpacing.xxl),
            SwitchListTile(
              key: const Key('fake_subscription_switch'),
              title: Text('subscription_test_switch'.tr()),
              value: fake,
              onChanged: (v) =>
                  ref.read(fakeSubscriptionProvider.notifier).setFake(v),
            ),
          ],
        ],
      ),
    );
  }
}

/// The diamond balance and this month's progress.
class _DiamondCard extends StatelessWidget {
  const _DiamondCard({required this.balance});

  final DiamondBalance balance;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'diamonds'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              Icon(LucideIcons.gem, color: context.colorScheme.primary),
              Text(
                '${balance.balance}',
                key: const Key('diamond_balance'),
                style: context.textTheme.headlineMedium?.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            'diamonds_month'.tr(args: ['${balance.month}', '${balance.cap}']),
            key: const Key('diamond_month'),
            style: context.textTheme.bodyLarge,
          ),
          Text('diamonds_how'.tr(), style: context.textTheme.bodyMedium),
          Text(
            'diamonds_kept'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
