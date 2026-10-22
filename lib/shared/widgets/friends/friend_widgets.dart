import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/app.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/friends_provider.dart';

// Shared pieces of the friends screens. Sizes follow the friends spec §5.3:
// text at least 18px (the `titleLarge` slot, 20px in both themes), buttons at
// least 56px tall (64 here), list rows at least 72px.

const kFriendButtonHeight = 64.0;
const kFriendRowHeight = 76.0;

/// A person's avatar: their photo when the viewer may see it, otherwise the
/// preset mascot on a tinted disc.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.preset,
    this.photoPath,
    this.size = 56,
  });

  FriendAvatar.of(FriendProfile p, {Key? key, double size = 56})
    : this(
        key: key,
        preset: p.avatarPreset,
        photoPath: p.photoPath,
        size: size,
      );

  final int preset;
  final String? photoPath;
  final double size;

  static String presetAsset(int preset) =>
      'assets/mascot-assets/avatars/av_${preset.toString().padLeft(2, '0')}.webp';

  @override
  Widget build(BuildContext context) {
    final tints = [
      context.colorScheme.primaryContainer,
      context.colorScheme.secondaryContainer,
      context.colorScheme.tertiaryContainer,
      context.colorScheme.surfaceContainerHighest,
    ];
    final photo = photoPath;
    // A friend's photo is a signed URL from Supabase; the demo data uses
    // files on the device.
    final ImageProvider image = switch (photo) {
      null => AssetImage(presetAsset(preset.clamp(1, kAvatarPresetCount))),
      _ when photo.startsWith('http') => NetworkImage(photo),
      _ => FileImage(File(photo)),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tints[(preset - 1) % tints.length],
        border: Border.all(color: context.colorScheme.outline, width: 2),
        image: DecorationImage(
          image: image,
          fit: BoxFit.cover,
          onError: (_, _) {},
        ),
      ),
    );
  }
}

/// Full-width primary or secondary button, 64px tall with 20px text.
class FriendButton extends StatelessWidget {
  const FriendButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.colorScheme.error : null;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        if (icon != null) Icon(icon, size: 28, color: color),
        Flexible(
          child: Text(
            label,
            style: context.textTheme.titleLarge?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
    const minSize = Size.fromHeight(kFriendButtonHeight);
    if (secondary || destructive) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: minSize),
        onPressed: onPressed,
        child: child,
      );
    }
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: minSize),
      onPressed: onPressed,
      child: child,
    );
  }
}

/// Big avatar and name, used wherever someone is about to be added.
class FriendPreview extends StatelessWidget {
  const FriendPreview({super.key, required this.profile, this.caption});

  final FriendProfile profile;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpacing.md,
      children: [
        FriendAvatar.of(profile, size: 120),
        Text(profile.nickname, style: context.textTheme.headlineMedium),
        if (caption != null)
          Text(
            caption!,
            style: context.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

/// Section heading inside the friends screens.
class FriendSectionTitle extends StatelessWidget {
  const FriendSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text, style: context.textTheme.titleLarge?.bold),
    );
  }
}

/// Plain sentence in the friends screens (never below 18px).
class FriendText extends StatelessWidget {
  const FriendText(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      textAlign: center ? TextAlign.center : null,
    );
  }
}

/// Spinner / error / content for a friends [AsyncValue].
class FriendAsync<T> extends StatelessWidget {
  const FriendAsync({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => builder(value),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: FriendText(friendErrorText(error), center: true),
      ),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

String friendErrorText(Object error) => error is FriendException
    ? error.messageKey.tr()
    : 'friends_err_offline'.tr();

void showFriendMessage(String text) {
  App.scaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 18)),
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Runs a friends call: on success refreshes every friends list and returns
/// the value; on failure shows the error in words and returns null.
Future<T?> runFriendAction<T>(
  WidgetRef ref,
  Future<Result<T>> Function() call, {
  String? successText,
}) async {
  final result = await call();
  switch (result) {
    case Ok(:final value):
      refreshFriendsData(ref);
      if (successText != null) showFriendMessage(successText);
      return value;
    case Error(:final error):
      showFriendMessage(friendErrorText(error));
      return null;
  }
}

/// [runFriendAction] for calls without a value: true when it went through.
Future<bool> runFriendStep(
  WidgetRef ref,
  Future<Result<void>> Function() call, {
  String? successText,
}) async {
  final result = await call();
  switch (result) {
    case Ok():
      refreshFriendsData(ref);
      if (successText != null) showFriendMessage(successText);
      return true;
    case Error(:final error):
      showFriendMessage(friendErrorText(error));
      return false;
  }
}

/// Yes/no dialog for anything that cannot be undone with one tap.
Future<bool> confirmFriendAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title, style: context.textTheme.headlineSmall),
      content: FriendText(body),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: AppSpacing.sm,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FriendButton(
            label: confirmLabel,
            destructive: destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FriendButton(
            label: 'friends_cancel'.tr(),
            secondary: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// The eight code digits as two groups of four boxes (`3815 2704`).
class CodeDigits extends StatelessWidget {
  const CodeDigits({super.key, required this.digits});

  final String digits;

  @override
  Widget build(BuildContext context) {
    Widget box(int i) {
      final filled = i < digits.length;
      return Container(
        width: 34,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: i == digits.length
                ? context.colorScheme.primary
                : context.colorScheme.outline,
            width: i == digits.length ? 3 : 1.5,
          ),
        ),
        child: Text(
          filled ? digits[i] : '',
          style: context.textTheme.headlineMedium,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 4,
      children: [
        for (var i = 0; i < 4; i++) box(i),
        const SizedBox(width: AppSpacing.md),
        for (var i = 4; i < kCodeLength; i++) box(i),
      ],
    );
  }
}

/// Big digit keypad (each key at least 64px), used instead of the system
/// keyboard for friend and org codes.
class CodeKeypad extends StatelessWidget {
  const CodeKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {IconData? icon}) {
      return Expanded(
        child: SizedBox(
          height: 68,
          child: OutlinedButton(
            onPressed: onTap,
            child: icon != null
                ? Icon(icon, size: 30, semanticLabel: label)
                : Text(label, style: context.textTheme.headlineMedium),
          ),
        ),
      );
    }

    Widget row(List<String> digits) => Row(
      spacing: AppSpacing.sm,
      children: [for (final d in digits) key(d, () => onDigit(d))],
    );

    return Column(
      spacing: AppSpacing.sm,
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          spacing: AppSpacing.sm,
          children: [
            const Expanded(child: SizedBox()),
            key('0', () => onDigit('0')),
            key(
              'friends_backspace'.tr(),
              onBackspace,
              icon: Icons.backspace_outlined,
            ),
          ],
        ),
      ],
    );
  }
}
