import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:silversole/core/active_aging/aa_repository.dart';
import 'package:silversole/core/error/error_logger.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// How the 銀足樂齡 mode is turned on, kept out of sight: nothing on any page
/// says it exists. At the bottom of 「我的」 sits the app version, as most
/// apps show it; tapping it [taps] times within [window] asks for the 8-digit
/// code the company gave the instructor or assistant. Anyone else just sees a
/// version number. The server is the lock (`aa_invite_redeem` limits wrong
/// tries); this only decides who is asked.
class VersionTag extends ConsumerStatefulWidget {
  const VersionTag({super.key, this.onUnlockTap, this.versionLoader});

  /// Called once the secret tap count is reached. Null: taps do nothing.
  final VoidCallback? onUnlockTap;

  /// Reads the version label; injected so tests need no platform channel.
  final Future<String?> Function()? versionLoader;

  static const int taps = 7;
  static const Duration window = Duration(seconds: 5);

  @override
  ConsumerState<VersionTag> createState() => _VersionTagState();
}

class _VersionTagState extends ConsumerState<VersionTag> {
  late final Future<String?> _version = (widget.versionLoader ?? _load)();
  int _count = 0;
  DateTime? _first;

  static Future<String?> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'v${info.version}';
    } catch (_) {
      return null;
    }
  }

  void _tap() {
    final now = clock.now();
    if (_first == null || now.difference(_first!) > VersionTag.window) {
      _first = now;
      _count = 0;
    }
    _count++;
    if (_count >= VersionTag.taps) {
      _count = 0;
      _first = null;
      widget.onUnlockTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: SizedBox(
        height: 40,
        child: Center(
          child: FutureBuilder<String?>(
            future: _version,
            builder: (context, snap) => Text(
              snap.data ?? '',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for the code and takes it. On success the role is re-read
/// (`aaActiveProvider`), which makes the 「銀足樂齡」 row appear.
Future<void> showAaCodeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AaCodeDialog(),
  );
}

class _AaCodeDialog extends ConsumerStatefulWidget {
  const _AaCodeDialog();

  @override
  ConsumerState<_AaCodeDialog> createState() => _AaCodeDialogState();
}

class _AaCodeDialogState extends ConsumerState<_AaCodeDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref.read(aaRepositoryProvider).redeem(_controller.text);
    if (!mounted) return;
    if (res['ok'] == true) {
      ref.invalidate(aaActiveProvider);
      Navigator.of(context).pop();
      showMessage('aa_code_done'.tr());
      return;
    }
    setState(() {
      _busy = false;
      _error = aaCodeErrorKey(res['reason']).tr();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('aa_code_title'.tr()),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 8,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'aa_code_hint'.tr(),
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text('aa_code_cancel'.tr()),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text('aa_code_confirm'.tr()),
        ),
      ],
    );
  }
}

/// The text key for what went wrong with a code (see [AaRepository.redeem]).
/// A wrong, used-up or stopped code all read the same on purpose.
String aaCodeErrorKey(Object? reason) => switch (reason) {
  'rate_limited' => 'aa_code_err_rate_limited',
  'forbidden' => 'aa_code_err_forbidden',
  'offline' => 'aa_code_err_offline',
  'signed_out' => 'aa_code_err_signed_out',
  _ => 'aa_code_err_invalid',
};
