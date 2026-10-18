import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

/// Last step of every "add" route: show who was found and send the request.
/// Returns true when a request went out (or the two became friends).
Future<bool> showAddFriendSheet(
  BuildContext context,
  WidgetRef ref, {
  required FriendProfile person,
  required FriendSource source,
  required String reference,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          0,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.base,
          children: [
            FriendPreview(profile: person),
            FriendButton(
              label: 'friends_add_this_person'.tr(),
              icon: Icons.person_add_alt_1,
              onPressed: () async {
                final outcome = await runFriendAction(
                  ref,
                  () => ref
                      .read(friendsRepositoryProvider)
                      .sendFriendRequest(source, reference),
                );
                if (outcome == null) return;
                showFriendMessage(switch (outcome) {
                  SendRequestOutcome.sent => 'friends_request_sent'.tr(
                    args: [person.nickname],
                  ),
                  SendRequestOutcome.becameFriends => 'friends_now_friends'.tr(
                    args: [person.nickname],
                  ),
                  SendRequestOutcome.alreadyFriends =>
                    'friends_already_friends'.tr(args: [person.nickname]),
                });
                if (sheetContext.mounted) Navigator.of(sheetContext).pop(true);
              },
            ),
            FriendButton(
              label: 'friends_not_now'.tr(),
              secondary: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return sent ?? false;
}

/// Confirms joining an org found by its code or poster QR, then opens its
/// member list.
Future<void> showJoinOrgSheet(
  BuildContext context,
  WidgetRef ref, {
  required OrgSummary org,
  required String joinCode,
}) async {
  final joined = await showModalBottomSheet<OrgSummary>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          0,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.base,
          children: [
            const Icon(Icons.groups, size: 72),
            FriendText(
              'friends_join_org_question'.tr(args: [org.name]),
              center: true,
            ),
            FriendButton(
              label: 'friends_join_org'.tr(),
              onPressed: () async {
                final result = await runFriendAction(
                  ref,
                  () => ref.read(friendsRepositoryProvider).joinOrg(joinCode),
                );
                if (result != null && sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(result);
                }
              },
            ),
            FriendButton(
              label: 'friends_not_now'.tr(),
              secondary: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
  if (joined != null && context.mounted) {
    context.pushReplacement('/friends/org', extra: joined);
  }
}
