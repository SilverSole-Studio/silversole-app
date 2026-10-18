import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

/// `/friends/profile` — change the name and picture friends see.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'friends_profile_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: const SafeArea(child: ProfileEditor(firstRun: false)),
    );
  }
}

/// Nickname, avatar and org-list visibility. On the first visit to the
/// friends page it is shown in place of the hub (spec §2.1).
class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({super.key, required this.firstRun});

  final bool firstRun;

  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  final _name = TextEditingController();
  int _preset = 1;
  bool _loaded = false;
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _loadFrom(MyProfile me) {
    if (_loaded) return;
    _loaded = true;
    _preset = me.avatarPreset;
    // A taken-down name is not offered back as the starting text.
    _name.text = me.nicknameWasRemoved ? '' : (me.nickname ?? '');
  }

  Future<void> _save() async {
    final invalid = validateNickname(_name.text);
    setState(
      () => _nameError = invalid == null
          ? null
          : 'friends_err_nicknameInvalid'.tr(),
    );
    if (invalid != null) return;
    setState(() => _saving = true);
    final saved = await runFriendAction(
      ref,
      () => ref
          .read(friendsRepositoryProvider)
          .updateProfile(nickname: _name.text, avatarPreset: _preset),
      successText: widget.firstRun ? null : 'friends_profile_saved'.tr(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null && !widget.firstRun) Navigator.of(context).maybePop();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    // TODO(friends): crop to a square before upload once a cropper is picked
    // (spec §2.2); until then the avatar is centre-cropped on display.
    await runFriendAction(
      ref,
      () => ref.read(friendsRepositoryProvider).setAvatarPhoto(file.path),
      successText: 'friends_photo_saved'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myFriendProfileProvider);
    return FriendAsync(
      value: profile,
      builder: (me) {
        _loadFrom(me);
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            if (widget.firstRun) ...[
              Text(
                'friends_setup_title'.tr(),
                style: context.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              FriendText('friends_setup_intro'.tr()),
            ],
            FriendSectionTitle('friends_nickname_label'.tr()),
            TextField(
              controller: _name,
              style: context.textTheme.headlineSmall,
              maxLength: kNicknameMaxLength,
              decoration: InputDecoration(
                hintText: 'friends_nickname_hint'.tr(),
                // The note below already says 2–8; the small counter is not
                // readable at 13px.
                counterText: '',
                hintStyle: context.textTheme.titleLarge,
                errorText: _nameError,
                errorStyle: const TextStyle(fontSize: 18),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(AppSpacing.base),
              ),
            ),
            FriendText('friends_nickname_note'.tr()),
            FriendSectionTitle('friends_avatar_label'.tr()),
            _PresetGrid(
              selected: _preset,
              onPick: (p) => setState(() => _preset = p),
            ),
            if (!widget.firstRun) ...[
              FriendSectionTitle('friends_photo_label'.tr()),
              if (me.photoPath != null)
                Center(
                  child: FriendAvatar(
                    preset: me.avatarPreset,
                    photoPath: me.photoPath,
                    size: 120,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              FriendText('friends_photo_note'.tr()),
              const SizedBox(height: AppSpacing.md),
              _PhotoButtons(
                me: me,
                onPick: _pickPhoto,
                onClear: () => runFriendAction(
                  ref,
                  ref.read(friendsRepositoryProvider).clearAvatarPhoto,
                ),
              ),
              FriendSectionTitle('friends_org_visibility_title'.tr()),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: FriendText('friends_org_visibility'.tr()),
                value: me.showInOrgList,
                onChanged: (v) => runFriendAction(
                  ref,
                  () => ref
                      .read(friendsRepositoryProvider)
                      .updateProfile(showInOrgList: v),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FriendButton(
              label: widget.firstRun
                  ? 'friends_setup_done'.tr()
                  : 'friends_save'.tr(),
              onPressed: _saving ? null : _save,
            ),
          ],
        );
      },
    );
  }
}

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({required this.selected, required this.onPick});

  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      children: [
        for (var p = 1; p <= kAvatarPresetCount; p++)
          Semantics(
            selected: p == selected,
            button: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onPick(p),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p == selected
                        ? context.colorScheme.primary
                        : Colors.transparent,
                    width: 4,
                  ),
                ),
                child: FittedBox(child: FriendAvatar(preset: p, size: 72)),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoButtons extends StatelessWidget {
  const _PhotoButtons({
    required this.me,
    required this.onPick,
    required this.onClear,
  });

  final MyProfile me;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bannedUntil = me.photoUploadBannedUntil;
    if (bannedUntil != null && DateTime.now().isBefore(bannedUntil)) {
      return FriendText('friends_err_uploadBanned'.tr());
    }
    return Column(
      spacing: AppSpacing.sm,
      children: [
        FriendButton(
          label: 'friends_photo_from_album'.tr(),
          icon: Icons.photo_library_outlined,
          secondary: true,
          onPressed: () => onPick(ImageSource.gallery),
        ),
        FriendButton(
          label: 'friends_photo_take'.tr(),
          icon: Icons.photo_camera_outlined,
          secondary: true,
          onPressed: () => onPick(ImageSource.camera),
        ),
        if (me.photoPath != null)
          FriendButton(
            label: 'friends_photo_clear'.tr(),
            secondary: true,
            onPressed: onClear,
          ),
      ],
    );
  }
}
