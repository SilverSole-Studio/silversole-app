import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/friends/profile_page.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

/// Stands in front of the home page: a signed-in user with no nickname sees
/// [NicknameSetupPage] first, everyone else goes straight through to [child].
///
/// While the profile is still being read for the first time a plain spinner
/// shows rather than the home page, so the name step never flashes in over
/// something the user has already started reading. If the profile cannot be
/// read the user is let in (see [needsNicknameProvider]).
class NicknameGate extends ConsumerWidget {
  const NicknameGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value` keeps the last answer while a refresh is under way, so the
    // refresh that follows saving the name does not bring the spinner back.
    final needs = ref.watch(needsNicknameProvider);
    return switch (needs.value) {
      true => const NicknameSetupPage(),
      false => child,
      null when needs.hasError => child,
      null => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

/// 「取個名字」 — the first thing a new user does after signing in. A name is
/// already filled in; the dice swaps it for another suggestion, and one tap on
/// 「就用這個」 is enough. There is no skip: friends and the plaza need a name,
/// and a suggested one costs a single tap.
class NicknameSetupPage extends StatelessWidget {
  const NicknameSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'nickname_setup_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: const SafeArea(child: NicknameSetupView()),
    );
  }
}

/// The body of the name step: suggestion field with a dice, avatar grid and
/// the save button pinned at the bottom. Also shown on the friends page for
/// someone who somehow still has no name when they get there.
class NicknameSetupView extends ConsumerStatefulWidget {
  const NicknameSetupView({super.key});

  @override
  ConsumerState<NicknameSetupView> createState() => _NicknameSetupViewState();
}

class _NicknameSetupViewState extends ConsumerState<NicknameSetupView> {
  late final TextEditingController _name;
  late int _preset;
  bool _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(nicknameGeneratorProvider).next(),
    );
    // The profile the server made for a new account already has a picture.
    _preset = (ref.read(myFriendProfileProvider).value?.avatarPreset ?? 1)
        .clamp(1, kAvatarPresetCount);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _roll() {
    setState(() {
      _name.text = ref
          .read(nicknameGeneratorProvider)
          .next(not: trimNickname(_name.text));
      _nameError = null;
    });
  }

  Future<void> _save() async {
    final invalid = validateNickname(_name.text);
    setState(
      () => _nameError = invalid == null ? null : friendErrorKey(invalid).tr(),
    );
    if (invalid != null) return;
    setState(() => _saving = true);
    final saved = await runFriendAction<MyProfile>(
      ref,
      () => ref
          .read(friendsRepositoryProvider)
          .updateProfile(nickname: _name.text, avatarPreset: _preset),
      scope: FriendErrorScope.avatar,
    );
    if (!mounted) return;
    // On success the profile refresh makes the gate (or friends page) swap
    // this view out; the button stays off until then so a second tap cannot
    // send the name twice.
    if (saved == null) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.base),
            children: [
              FriendText('friends_setup_intro'.tr()),
              FriendSectionTitle('friends_nickname_label'.tr()),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      style: context.textTheme.headlineSmall,
                      maxLength: kNicknameMaxLength,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'friends_nickname_hint'.tr(),
                        counterText: '',
                        hintStyle: context.textTheme.titleLarge,
                        errorText: _nameError,
                        errorMaxLines: 2,
                        errorStyle: context.textTheme.titleLarge?.copyWith(
                          color: context.colorScheme.error,
                        ),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(AppSpacing.base),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _saving ? null : _roll,
                    tooltip: 'nickname_setup_reroll'.tr(),
                    iconSize: 32,
                    constraints: const BoxConstraints.tightFor(
                      width: kFriendButtonHeight,
                      height: kFriendButtonHeight,
                    ),
                    icon: const Icon(Icons.casino_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FriendText('nickname_setup_hint'.tr()),
              FriendSectionTitle('friends_avatar_label'.tr()),
              AvatarPresetGrid(
                selected: _preset,
                onPick: (p) => setState(() => _preset = p),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: FriendButton(
            label: 'nickname_setup_done'.tr(),
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );
  }
}
