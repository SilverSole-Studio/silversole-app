import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Apple's own button (black in light mode, white in dark, per Apple's
/// guidelines), sized and shaped like the Google button beneath it.
Widget appleSignInButton(
  BuildContext context, {
  required VoidCallback onPressed,
}) {
  return SignInWithAppleButton(
    onPressed: onPressed,
    text: 'sign_in_with_apple'.tr(),
    height: 48,
    style: context.colorScheme.brightness == Brightness.dark
        ? SignInWithAppleButtonStyle.white
        : SignInWithAppleButtonStyle.black,
    borderRadius: const BorderRadius.all(Radius.circular(24)),
    iconAlignment: SignInWithAppleIconAlignment.left,
  );
}
