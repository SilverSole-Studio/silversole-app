import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/constants.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the privacy policy in the browser, in the app's language.
Future<void> openPrivacyPolicy(BuildContext context) async {
  final uri = Uri.parse(
    Constants.privacyPolicyUrl(context.locale.languageCode),
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) showErrorSnakeBar('privacy_policy_open_failed'.tr());
}

/// The small "Privacy policy" link under the sign-in and sign-up forms, so it
/// can be read before an account exists (guideline 5.1.1(i)).
class PrivacyPolicyLink extends StatelessWidget {
  const PrivacyPolicyLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => openPrivacyPolicy(context),
      child: Text('privacy_policy'.tr()),
    );
  }
}
