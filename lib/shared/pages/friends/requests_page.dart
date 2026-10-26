import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';
import 'package:silversole/shared/widgets/friends/friend_safety.dart';

/// `/friends/requests` — who wants to add me, and who I am waiting on.
///
/// Declining is silent: the sender keeps seeing "waiting" until the request
/// expires after 7 days (spec §3.4).
class RequestsPage extends ConsumerWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'friends_requests'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: FriendAsync(
          value: requests,
          builder: (all) {
            final incoming = all.where((r) => r.incoming).toList();
            final outgoing = all.where((r) => !r.incoming).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                0,
                AppSpacing.base,
                AppSpacing.xxl,
              ),
              children: [
                FriendSectionTitle('friends_requests_incoming'.tr()),
                if (incoming.isEmpty)
                  FriendText('friends_requests_none'.tr())
                else
                  for (final r in incoming) _IncomingCard(request: r),
                FriendSectionTitle('friends_requests_outgoing'.tr()),
                if (outgoing.isEmpty)
                  FriendText('friends_requests_none'.tr())
                else
                  for (final r in outgoing) _OutgoingRow(request: r),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _sourceText(FriendRequest r) => switch (r.source) {
  FriendSource.qr => 'friends_via_qr'.tr(),
  FriendSource.code => 'friends_via_code'.tr(),
  FriendSource.org => 'friends_via_org'.tr(args: [r.orgName ?? '']),
};

class _IncomingCard extends ConsumerWidget {
  const _IncomingCard({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(friendsRepositoryProvider);
    final name = request.other.nickname;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          spacing: AppSpacing.md,
          children: [
            Row(
              spacing: AppSpacing.md,
              children: [
                FriendAvatar.of(request.other, size: 64),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: context.textTheme.headlineSmall),
                      FriendText(_sourceText(request)),
                    ],
                  ),
                ),
                // Report sits here; blocking is the "decline and block"
                // button below.
                FriendSafetyMenu(person: request.other, showBlock: false),
              ],
            ),
            FriendButton(
              label: 'friends_accept'.tr(),
              onPressed: () => runFriendAction(
                ref,
                () => repo.respondFriendRequest(
                  request.id,
                  FriendRequestAction.accept,
                ),
                successText: 'friends_now_friends'.tr(args: [name]),
                scope: FriendErrorScope.request,
              ),
            ),
            Row(
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: FriendButton(
                    label: 'friends_decline'.tr(),
                    secondary: true,
                    onPressed: () => runFriendAction(
                      ref,
                      () => repo.respondFriendRequest(
                        request.id,
                        FriendRequestAction.decline,
                      ),
                      scope: FriendErrorScope.request,
                    ),
                  ),
                ),
                Expanded(
                  child: FriendButton(
                    label: 'friends_decline_block'.tr(),
                    destructive: true,
                    onPressed: () async {
                      final ok = await confirmFriendAction(
                        context,
                        title: 'friends_block_title'.tr(args: [name]),
                        body: 'friends_block_confirm'.tr(),
                        confirmLabel: 'friends_block'.tr(),
                        destructive: true,
                      );
                      if (!ok) return;
                      await runFriendAction(
                        ref,
                        () => repo.respondFriendRequest(
                          request.id,
                          FriendRequestAction.declineAndBlock,
                        ),
                        scope: FriendErrorScope.request,
                      );
                    },
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

class _OutgoingRow extends ConsumerWidget {
  const _OutgoingRow({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = request.expiresAt.difference(DateTime.now()).inDays + 1;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kFriendRowHeight),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          FriendAvatar.of(request.other),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.other.nickname,
                  style: context.textTheme.titleLarge,
                ),
                FriendText('friends_waiting_days'.tr(args: ['$daysLeft'])),
              ],
            ),
          ),
          FriendSafetyMenu(person: request.other),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () => runFriendAction(
                ref,
                () => ref
                    .read(friendsRepositoryProvider)
                    .cancelFriendRequest(request.id),
                scope: FriendErrorScope.request,
              ),
              child: Text(
                'friends_cancel_request'.tr(),
                style: context.textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
