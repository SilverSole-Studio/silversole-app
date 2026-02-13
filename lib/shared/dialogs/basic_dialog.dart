import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum ConfirmType {
  primary,
  delete,
}

Future<void> showBasicDialog(
    BuildContext context, {
      required String title,
      required String text,
      String buttonText = "Confirm",
      VoidCallback? onDismiss,
      VoidCallback? onClick,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => context.pop(true),
          child: Text(buttonText),
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

Future<void> showContentDialog(
    BuildContext context, {
      required String title,
      Widget? content,
      String buttonText = "Confirm",
      VoidCallback? onDismiss,
      VoidCallback? onClick,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => context.pop(true),
          child: Text(buttonText),
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
      String confirmText = "Confirm",
      ConfirmType confirmType = ConfirmType.primary,
      String dismissText = "Cancel",
      required VoidCallback onDismiss,
      required VoidCallback onClick,
    }) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      icon: icon,
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: Text(dismissText),
        ),
        TextButton(
          onPressed: () => context.pop(true),
          child: Text(
            confirmText,
            style: TextStyle(
              color: confirmType == ConfirmType.primary ? cs.primary : cs.error,
            ),
          ),
        ),
      ],
    ),
  );

  if (result == true) {
    onClick();
  } else {
    onDismiss();
  }
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
    builder: (_) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<String>(
          groupValue: selectedKey,
          onChanged: (value) {
            Navigator.pop(context, value);
          },
          child: Column(
            children: [
              for (final entry in optionsMap.entries)
                RadioListTile(title: Text(entry.value), value: entry.key),
            ],
          ),
        ),
      ],
    ),
  );

  if (result == null || result == selectedKey) return;
  onChanged(result);
}