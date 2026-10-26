import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

// Report and block, shared by every screen that shows another person's
// nickname or photo (App Review 1.2: user-generated content needs a way to
// report it and to block its author wherever it appears).

/// Asks why, then reports [person]'s photo or nickname.
Future<void> reportFriendProfile(
  BuildContext context,
  WidgetRef ref,
  FriendProfile person,
  ReportKind kind,
) async {
  final reason = await showModalBottomSheet<ReportReason>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          0,
          AppSpacing.base,
          AppSpacing.xl,
        ),
        children: [
          FriendText(
            kind == ReportKind.photo
                ? 'friends_report_photo_why'.tr()
                : 'friends_report_name_why'.tr(),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final r in ReportReason.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FriendButton(
                label: 'friends_report_reason_${r.name}'.tr(),
                secondary: true,
                onPressed: () => Navigator.of(sheetContext).pop(r),
              ),
            ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  await runFriendAction(
    ref,
    () => ref
        .read(friendsRepositoryProvider)
        .reportProfile(person.userId, kind, reason),
    successText: 'friends_report_sent'.tr(),
    scope: FriendErrorScope.report,
  );
}

/// Confirms, then blocks [person]. True when the block went through.
Future<bool> blockFriendProfile(
  BuildContext context,
  WidgetRef ref,
  FriendProfile person,
) async {
  final ok = await confirmFriendAction(
    context,
    title: 'friends_block_title'.tr(args: [person.nickname]),
    body: 'friends_block_confirm'.tr(),
    confirmLabel: 'friends_block'.tr(),
    destructive: true,
  );
  if (!ok) return false;
  return runFriendStep(
    ref,
    () => ref.read(friendsRepositoryProvider).blockUser(person.userId),
    successText: 'friends_blocked'.tr(args: [person.nickname]),
  );
}

enum _SafetyAction { reportPhoto, reportName, block }

/// The ⋮ menu beside a stranger: report their photo (only when one is shown),
/// report their nickname, and — unless the screen already has its own block
/// button ([showBlock] false) — block them.
class FriendSafetyMenu extends ConsumerWidget {
  const FriendSafetyMenu({
    super.key,
    required this.person,
    this.showBlock = true,
    this.onBlocked,
  });

  final FriendProfile person;
  final bool showBlock;

  /// Runs after a successful block, e.g. to close the sheet showing [person].
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = context.textTheme.titleLarge;
    return PopupMenuButton<_SafetyAction>(
      tooltip: 'friends_more_actions'.tr(),
      icon: const Icon(Icons.more_vert, size: 28),
      position: PopupMenuPosition.under,
      onSelected: (action) async {
        switch (action) {
          case _SafetyAction.reportPhoto:
            await reportFriendProfile(context, ref, person, ReportKind.photo);
          case _SafetyAction.reportName:
            await reportFriendProfile(
              context,
              ref,
              person,
              ReportKind.nickname,
            );
          case _SafetyAction.block:
            if (await blockFriendProfile(context, ref, person)) {
              onBlocked?.call();
            }
        }
      },
      itemBuilder: (_) => [
        if (person.photoPath != null)
          PopupMenuItem(
            value: _SafetyAction.reportPhoto,
            child: Text('friends_report_photo'.tr(), style: style),
          ),
        PopupMenuItem(
          value: _SafetyAction.reportName,
          child: Text('friends_report_name'.tr(), style: style),
        ),
        if (showBlock)
          PopupMenuItem(
            value: _SafetyAction.block,
            child: Text(
              'friends_block'.tr(),
              style: style?.copyWith(color: context.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
