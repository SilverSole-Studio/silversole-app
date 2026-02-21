import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

enum ConfirmType { primary, delete }

Future<void> showBasicDialog(
  BuildContext context, {
  required String title,
  required String text,
  String? buttonText,
  VoidCallback? onDismiss,
  VoidCallback? onClick,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(buttonText ?? 'confirm'.tr()))],
    ),
  );

  if (result == true) {
    onClick?.call();
  } else {
    onDismiss?.call();
  }
}

Future<void> showContentDialog(
  BuildContext context, {
  required String title,
  Widget? content,
  String? dismissText,
  String? confirmText,
  ConfirmType confirmType = ConfirmType.primary,
  VoidCallback? onDismiss,
  VoidCallback? onClick,
}) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(dismissText ?? 'cancel'.tr())),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmText ?? 'confirm'.tr(),
            style: TextStyle(color: confirmType == ConfirmType.primary ? cs.primary : cs.error),
          ),
        ),
      ],
    ),
  );

  if (result == true) {
    onClick?.call();
  } else {
    onDismiss?.call();
  }
}

Future<void> showConfirmLeaveDialog(
  BuildContext context, {
  Icon? icon,
  required String title,
  required String text,
  String? confirmText,
  ConfirmType confirmType = ConfirmType.primary,
  String? dismissText,
  VoidCallback? onDismiss,
  required VoidCallback onConfirm,
}) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: icon,
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(dismissText ?? 'cancel'.tr())),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            confirmText ?? 'confirm'.tr(),
            style: TextStyle(color: confirmType == ConfirmType.primary ? cs.primary : cs.error),
          ),
        ),
      ],
    ),
  );
  result == true ? onConfirm() : onDismiss?.call();
}

Future<void> showOptionsDialog(
  BuildContext context, {
  required String title,
  required Map<String, String> optionsMap,
  String? selectedKey,
  required void Function(String) onChanged,
}) async {
  if (optionsMap.isEmpty) {
    await showBasicDialog(context, title: title, text: '');
    return;
  }

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<String>(
          groupValue: selectedKey,
          onChanged: (value) {
            Navigator.of(dialogContext).pop(value);
          },
          child: Column(
            children: [
              for (final entry in optionsMap.entries) RadioListTile(title: Text(entry.value), value: entry.key),
            ],
          ),
        ),
      ],
    ),
  );

  if (result == null || result == selectedKey) return;
  onChanged(result);
}
