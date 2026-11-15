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
                  for (final r in incoming) IncomingRequestCard(request: r),
                FriendSectionTitle('friends_requests_outgoing'.tr()),
                if (outgoing.isEmpty)
                  FriendText('friends_requests_none'.tr())
                else
                  for (final r in outgoing) OutgoingRequestRow(request: r),
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
  FriendSource.link => 'friends_via_link'.tr(),
};

class IncomingRequestCard extends ConsumerWidget {
  const IncomingRequestCard({super.key, required this.request});

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
                // 檢舉與封鎖都收在這個選單裡，卡片上只留「同意」「不要」兩顆，長輩不會誤按封鎖。
                FriendSafetyMenu(person: request.other),
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
            FriendButton(
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
          ],
        ),
      ),
    );
  }
}

class OutgoingRequestRow extends ConsumerWidget {
  const OutgoingRequestRow({super.key, required this.request});

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
