import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';
import 'package:silversole/shared/widgets/friends/friend_safety.dart';

/// `/friends/person` — one friend: name, picture, and the ways to step back
/// (remove, block, report). Deliberately no health data here — no steps, streak,
/// game scores or foot pressure (spec §4.1).
class FriendDetailPage extends ConsumerWidget {
  const FriendDetailPage({super.key, required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = friend.profile;
    final repo = ref.read(friendsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xxl,
          ),
          children: [
            FriendPreview(
              profile: p,
              caption: 'friends_since'.tr(
                args: [
                  DateFormat.yMMMd(
                    context.locale.toString(),
                  ).format(friend.since),
                ],
              ),
            ),
            // No "visit garden": the garden is not built yet.
            const SizedBox(height: AppSpacing.xxl),
            FriendButton(
              label: 'friends_remove'.tr(),
              secondary: true,
              onPressed: () async {
                final ok = await confirmFriendAction(
                  context,
                  title: 'friends_remove_title'.tr(args: [p.nickname]),
                  body: 'friends_remove_confirm'.tr(),
                  confirmLabel: 'friends_remove'.tr(),
                  destructive: true,
                );
                if (!ok) return;
                final done = await runFriendStep(
                  ref,
                  () => repo.removeFriend(p.userId),
                  successText: 'friends_removed'.tr(args: [p.nickname]),
                );
                if (done && context.mounted) context.pop();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            FriendButton(
              label: 'friends_block'.tr(),
              destructive: true,
              onPressed: () async {
                final done = await blockFriendProfile(context, ref, p);
                if (done && context.mounted) context.pop();
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              spacing: AppSpacing.sm,
              children: [
                if (p.photoPath != null)
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(kFriendButtonHeight),
                      ),
                      onPressed: () =>
                          reportFriendProfile(context, ref, p, ReportKind.photo),
                      child: Text(
                        'friends_report_photo'.tr(),
                        style: context.textTheme.titleLarge,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(kFriendButtonHeight),
                    ),
                    onPressed: () =>
                        reportFriendProfile(context, ref, p, ReportKind.nickname),
                    child: Text(
                      'friends_report_name'.tr(),
                      style: context.textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `/friends/blocked` — people I blocked. Unblocking does not make them
/// friends again (spec §4.3).
class BlockedPage extends ConsumerWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'friends_blocked_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: FriendAsync(
          value: blocked,
          builder: (list) => ListView(
            padding: const EdgeInsets.all(AppSpacing.base),
            children: [
              FriendText('friends_blocked_hint'.tr()),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty)
                FriendText('friends_blocked_empty'.tr(), center: true),
              for (final p in list)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: kFriendRowHeight,
                  ),
                  child: Row(
                    spacing: AppSpacing.md,
                    children: [
                      FriendAvatar.of(p),
                      Expanded(
                        child: Text(
                          p.nickname,
                          style: context.textTheme.titleLarge,
                        ),
                      ),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () async {
                            final ok = await confirmFriendAction(
                              context,
                              title: 'friends_unblock'.tr(),
                              body: 'friends_unblock_confirm'.tr(
                                args: [p.nickname],
                              ),
                              confirmLabel: 'friends_unblock'.tr(),
                            );
                            if (!ok) return;
                            await runFriendAction(
                              ref,
                              () => ref
                                  .read(friendsRepositoryProvider)
                                  .unblockUser(p.userId),
                            );
                          },
                          child: Text(
                            'friends_unblock'.tr(),
                            style: context.textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
