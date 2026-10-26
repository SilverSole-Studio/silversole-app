import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/friends/fake_friends_repository.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/friends/enter_code_page.dart';
import 'package:silversole/shared/pages/friends/profile_page.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

/// `/friends` — the friends hub opened from the games-hub card.
///
/// First visit (no nickname yet) shows the profile setup instead. After that:
/// the three ways to add someone, pending requests, orgs, and the friend
/// list. Nothing on this page shows health data (spec §6).
///
/// Every other friends screen is pushed on top of this one, so it is the
/// one that watches for the app coming back to the foreground: photos are
/// one-hour signed URLs, and someone who left the app on the friends list
/// would otherwise come back to broken pictures.
class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        // The two lists that carry signed photo URLs. A refresh keeps the
        // old data on screen until the new one arrives.
        ref
          ..invalidate(friendsListProvider)
          ..invalidate(myFriendProfileProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myFriendProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('friends_title'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: FriendAsync(
          value: profile,
          builder: (me) => me.needsSetup
              ? const ProfileEditor(firstRun: true)
              : _FriendsHub(me: me),
        ),
      ),
    );
  }
}

class _FriendsHub extends ConsumerWidget {
  const _FriendsHub({required this.me});

  final MyProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsListProvider);
    final incoming = ref.watch(incomingRequestCountProvider);
    final orgs = ref.watch(myOrgsProvider).value ?? const [];

    return RefreshIndicator(
      onRefresh: () async => refreshFriendsData(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          0,
          AppSpacing.base,
          AppSpacing.xxl,
        ),
        children: [
          if (me.nicknameWasRemoved) _RemovedNotice.nickname(),
          if (me.photoWasRemoved) _RemovedNotice.photo(),
          _MeRow(me: me),
          const SizedBox(height: AppSpacing.base),
          const _AddButtons(),
          const SizedBox(height: AppSpacing.base),
          _NavRow(
            icon: Icons.mail_outline,
            label: 'friends_requests'.tr(),
            badge: incoming,
            onTap: () => context.push('/friends/requests'),
          ),
          _NavRow(
            icon: Icons.groups_outlined,
            label: 'friends_my_orgs'.tr(),
            detail: orgs.isEmpty
                ? 'friends_no_org'.tr()
                : orgs.map((o) => o.name).join('、'),
            onTap: () => context.push('/friends/orgs'),
          ),
          FriendSectionTitle(
            'friends_list_title'.tr(
              args: ['${friends.value?.length ?? 0}', '$kFriendLimit'],
            ),
          ),
          FriendAsync(
            value: friends,
            builder: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: FriendText('friends_list_empty'.tr(), center: true),
                  )
                : Column(
                    children: [for (final f in list) FriendRow(friend: f)],
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _NavRow(
            icon: Icons.block,
            label: 'friends_blocked_title'.tr(),
            onTap: () => context.push('/friends/blocked'),
          ),
          if (kDebugMode &&
              ref.watch(friendsRepositoryProvider) is FakeFriendsRepository)
            const _DemoHint(),
        ],
      ),
    );
  }
}

/// "This is how friends see you" + edit.
class _MeRow extends StatelessWidget {
  const _MeRow({required this.me});

  final MyProfile me;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/friends/profile'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            spacing: AppSpacing.base,
            children: [
              FriendAvatar.of(me.asSeenByFriends, size: 64),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      me.nickname ?? '',
                      style: context.textTheme.headlineSmall,
                    ),
                    Text(
                      'friends_my_code'.tr(args: [formatCode(me.friendCode)]),
                      style: context.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButtons extends StatelessWidget {
  const _AddButtons();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Icon(icon, size: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: context.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      spacing: AppSpacing.sm,
      children: [
        tile(
          Icons.qr_code_2,
          'friends_my_qr'.tr(),
          () => context.push('/friends/my-qr'),
        ),
        tile(
          Icons.qr_code_scanner,
          'friends_scan_qr'.tr(),
          () => context.push('/friends/scan'),
        ),
        tile(
          Icons.dialpad,
          'friends_enter_code'.tr(),
          () => context.push('/friends/code', extra: CodeMode.friend),
        ),
      ],
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kFriendRowHeight),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              Icon(icon, size: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.textTheme.titleLarge),
                    if (detail != null)
                      Text(
                        detail!,
                        style: context.textTheme.titleLarge?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (badge > 0)
                Badge(
                  label: Text('$badge'),
                  textStyle: context.textTheme.titleLarge,
                  largeSize: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// One friend in the list: avatar, name, and the way into their garden.
class FriendRow extends StatelessWidget {
  const FriendRow({super.key, required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    final p = friend.profile;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kFriendRowHeight),
      child: InkWell(
        onTap: () => context.push('/friends/person', extra: friend),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
              // No "visit garden" button: the garden redesign is a separate
              // branch, and until it lands there is no garden to visit.
              Icon(
                Icons.chevron_right,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemovedNotice extends ConsumerWidget {
  const _RemovedNotice._(this.isNickname);

  factory _RemovedNotice.nickname() => const _RemovedNotice._(true);

  factory _RemovedNotice.photo() => const _RemovedNotice._(false);

  final bool isNickname;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          spacing: AppSpacing.md,
          children: [
            FriendText(
              isNickname
                  ? 'friends_nickname_removed'.tr()
                  : 'friends_photo_removed'.tr(),
            ),
            FriendButton(
              label: isNickname
                  ? 'friends_pick_new_name'.tr()
                  : 'friends_got_it'.tr(),
              onPressed: () {
                if (isNickname) {
                  context.push('/friends/profile');
                } else {
                  runFriendAction(
                    ref,
                    ref.read(friendsRepositoryProvider).acknowledgeRemovals,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Debug builds on the demo data only: the codes that work against it.
class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Text(
        'Demo data — friend code '
        '${formatCode(FakeFriendsRepository.demoFriendCode)} (李伯伯), '
        'org code ${formatCode(FakeFriendsRepository.demoOrgCode)} '
        '(鶯歌日照中心). Showing your QR makes 李伯伯 "scan" it after 6 s.',
        style: context.textTheme.bodyMedium,
      ),
    );
  }
}
