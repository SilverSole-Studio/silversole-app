import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/settings_row.dart';

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
class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({
    super.key,
    required this.busy,
    required this.onConfirmed,
  });

  final bool busy;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      icon: LucideIcons.userX,
      title: busy ? 'delete_account_deleting'.tr() : 'delete_account'.tr(),
      danger: true,
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : null,
      onTap: busy
          ? null
          : () async {
              if (await confirmDeleteAccount(context)) onConfirmed();
            },
    );
  }
}
