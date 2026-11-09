import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/friends/add_flows.dart';
import 'package:silversole/shared/pages/friends/nickname_setup_page.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

/// `/f` — what opens when someone taps a friend's link
/// (`https://dongyu.company/f/?t=<token>`, or the `silversole://` form of it
/// from the website's open-in-app button).
///
/// Shows who sent it (nickname and preset avatar only, even to a stranger),
/// and only an extra tap on 「加他當朋友」 sends the request — which they still
/// have to accept. A person without a nickname yet is asked for one first,
/// the same step as on the friends page. Nobody who is signed out gets here:
/// the router holds the link while they sign in ([PendingShareLink]).
class ShareLinkPage extends ConsumerWidget {
  const ShareLinkPage({super.key, required this.token});

  /// Null when the address had no usable token.
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myFriendProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('friends_title'.tr(), style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: FriendAsync(
          value: profile,
          builder: (me) => me.needsSetup
              ? const NicknameSetupView()
              : _OpenLink(token: token),
        ),
      ),
    );
  }
}

class _OpenLink extends ConsumerStatefulWidget {
  const _OpenLink({required this.token});

  final String? token;

  @override
  ConsumerState<_OpenLink> createState() => _OpenLinkState();
}

class _OpenLinkState extends ConsumerState<_OpenLink> {
  String? _error;

  /// The spinner shows while the link is looked up, and not behind the sheet
  /// that opens over this page afterwards.
  bool _looking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  /// Back to the home page, with the friends page on top when [toFriends].
  void _leave({required bool toFriends}) {
    if (!mounted) return;
    context.go('/');
    if (toFriends) context.push('/friends');
  }

  Future<void> _open() async {
    final token = widget.token;
    if (token == null) {
      setState(
        () => _error = friendErrorText(
          const FriendException(FriendError.notFound),
          FriendErrorScope.link,
        ),
      );
      return;
    }
    setState(() {
      _error = null;
      _looking = true;
    });
    final result = await ref
        .read(friendsRepositoryProvider)
        .previewByShareLink(token);
    if (!mounted) return;
    setState(() => _looking = false);
    switch (result) {
      case Ok(:final value):
        if (value.alreadyFriends) {
          showFriendMessage(
            'friends_already_friends'.tr(args: [value.profile.nickname]),
          );
          _leave(toFriends: true);
          return;
        }
        final sent = await showAddFriendSheet(
          context,
          ref,
          person: value.profile,
          source: FriendSource.link,
          reference: token,
        );
        _leave(toFriends: sent);
      case Error(:final error):
        setState(() => _error = friendErrorText(error, FriendErrorScope.link));
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error == null && !_looking) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.base,
          children: error == null
              ? [
                  const CircularProgressIndicator(),
                  FriendText('friends_link_loading'.tr(), center: true),
                ]
              : [
                  FriendText(error, center: true),
                  FriendButton(
                    label: 'friends_link_home'.tr(),
                    onPressed: () => _leave(toFriends: false),
                  ),
                ],
        ),
      ),
    );
  }
}
