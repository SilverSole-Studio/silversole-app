import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// A short, large explanation with one big button — for a state the person
/// has to fix outside the app (Bluetooth off, permission refused, no sole).
/// Text is kept to a title and one line so it reads at any text size.
class SettingsHint extends StatelessWidget {
  const SettingsHint({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 56, color: context.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.base),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              textStyle: context.textTheme.titleLarge,
            ),
            onPressed: onPressed,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

/// Shows [SettingsHint] in a dialog, with a "cancel" way out.
Future<void> showSettingsHintDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  required VoidCallback onOpenSettings,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsHint(
              icon: icon,
              title: title,
              body: body,
              buttonLabel: 'open_settings'.tr(),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onOpenSettings();
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('cancel'.tr()),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    ),
  );
}
