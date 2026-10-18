import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/friends/enter_code_page.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

/// `/friends/orgs` — the community centres / day-care centres I belong to
/// (at most 3), and how to join one (spec §3.3).
class OrgsPage extends ConsumerWidget {
  const OrgsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgs = ref.watch(myOrgsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'friends_my_orgs'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: FriendAsync(
          value: orgs,
          builder: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              0,
              AppSpacing.base,
              AppSpacing.xxl,
            ),
            children: [
              if (list.isEmpty) ...[
                const SizedBox(height: AppSpacing.base),
                FriendText('friends_orgs_empty'.tr()),
              ],
              for (final org in list) _OrgRow(org: org),
              FriendSectionTitle(
                'friends_join_org_title'.tr(args: ['$kOrgLimit']),
              ),
              if (list.length >= kOrgLimit)
                FriendText('friends_err_orgLimit'.tr())
              else ...[
                FriendText('friends_join_org_hint'.tr()),
                const SizedBox(height: AppSpacing.md),
                FriendButton(
                  label: 'friends_scan_poster'.tr(),
                  icon: Icons.qr_code_scanner,
                  onPressed: () => context.push('/friends/scan'),
                ),
                const SizedBox(height: AppSpacing.sm),
                FriendButton(
                  label: 'friends_enter_org_code'.tr(),
                  icon: Icons.dialpad,
                  secondary: true,
                  onPressed: () =>
                      context.push('/friends/code', extra: CodeMode.org),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgRow extends StatelessWidget {
  const _OrgRow({required this.org});

  final OrgSummary org;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: InkWell(
        onTap: () => context.push('/friends/org', extra: org),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kFriendRowHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              spacing: AppSpacing.md,
              children: [
                const Icon(Icons.groups, size: 36),
                Expanded(
                  child: Text(org.name, style: context.textTheme.titleLarge),
                ),
                const Icon(Icons.chevron_right, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `/friends/org` — everyone at one org who lets members see them, with a
/// one-tap "add" each. Mascot avatars and nicknames only (spec §3.3).
class OrgMembersPage extends ConsumerWidget {
  const OrgMembersPage({super.key, required this.org});

  final OrgSummary org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(orgMembersProvider(org.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(org.name, style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: FriendAsync(
          value: members,
          builder: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.sm,
              AppSpacing.base,
              AppSpacing.xxl,
            ),
            children: [
              FriendText('friends_org_members_hint'.tr()),
              const SizedBox(height: AppSpacing.md),
              if (list.isEmpty)
                FriendText('friends_org_members_empty'.tr(), center: true),
              for (final m in list) _MemberRow(member: m),
              const SizedBox(height: AppSpacing.xl),
              FriendButton(
                label: 'friends_leave_org'.tr(),
                destructive: true,
                onPressed: () async {
                  final ok = await confirmFriendAction(
                    context,
                    title: 'friends_leave_org'.tr(),
                    body: 'friends_leave_org_confirm'.tr(args: [org.name]),
                    confirmLabel: 'friends_leave_org'.tr(),
                    destructive: true,
                  );
                  if (!ok) return;
                  final left = await runFriendStep(
                    ref,
                    () => ref.read(friendsRepositoryProvider).leaveOrg(org.id),
                  );
                  if (left && context.mounted) context.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.member});

  final OrgMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = member.profile;
    final Widget trailing = switch (member.status) {
      OrgMemberStatus.friend => _Tag('friends_tag_friend'.tr()),
      OrgMemberStatus.pendingOut => _Tag('friends_tag_waiting'.tr()),
      OrgMemberStatus.pendingIn => SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: () => context.push('/friends/requests'),
          child: Text(
            'friends_tag_wants_you'.tr(),
            style: context.textTheme.titleLarge,
          ),
        ),
      ),
      OrgMemberStatus.none => SizedBox(
        height: 56,
        child: FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1, size: 26),
          onPressed: () => runFriendAction(
            ref,
            () => ref
                .read(friendsRepositoryProvider)
                .sendFriendRequest(FriendSource.org, p.userId),
            successText: 'friends_request_sent'.tr(args: [p.nickname]),
          ),
          label: Text('friends_add'.tr(), style: context.textTheme.titleLarge),
        ),
      ),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kFriendRowHeight),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          FriendAvatar.of(p),
          Expanded(
            child: Text(
              p.nickname,
              style: context.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: context.textTheme.titleLarge),
    );
  }
}
