import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Asks before deleting the account, saying plainly what goes and that it
/// cannot be undone. Resolves to true only on the destructive confirm.
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(LucideIcons.triangleAlert, color: context.colorScheme.error),
      title: Text('delete_account_title'.tr()),
      content: Text('delete_account_body'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.colorScheme.error,
            foregroundColor: context.colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('delete_account_confirm'.tr()),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The destructive "Delete account" row under the account settings. Tapping
/// it confirms first ([confirmDeleteAccount]) and only then calls
/// [onConfirmed]; while [busy] it shows progress and ignores taps.
///
/// [fill] and [side] match the settings rows around it (the mascot theme
/// outlines every row; the classic theme does not).
class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({
    super.key,
    required this.busy,
    required this.onConfirmed,
    this.fill,
    this.side,
  });

  final bool busy;
  final VoidCallback onConfirmed;
  final Color? fill;
  final BorderSide? side;

  @override
  Widget build(BuildContext context) {
    final error = context.colorScheme.error;
    return Material(
      color: fill ?? context.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.banner),
        side: side ?? BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          enabled: !busy,
          leading: busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Icon(LucideIcons.userX, color: error),
          title: Text(
            busy ? 'delete_account_deleting'.tr() : 'delete_account'.tr(),
            style: context.textTheme.bodyLarge?.copyWith(color: error),
          ),
          onTap: () async {
            if (await confirmDeleteAccount(context)) onConfirmed();
          },
        ),
      ),
    );
  }
}
