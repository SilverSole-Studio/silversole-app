import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/error/result.dart';
import 'package:silversole/core/friends/friend_models.dart';
import 'package:silversole/core/friends/friend_rules.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/pages/friends/add_flows.dart';
import 'package:silversole/shared/providers/friends_provider.dart';
import 'package:silversole/shared/widgets/friends/friend_widgets.dart';

enum CodeMode { friend, org }

/// `/friends/code` — type an 8-digit friend code or org code on a big keypad.
/// The lookup runs as soon as the eighth digit is in (spec §3.2, §3.3).
class EnterCodePage extends ConsumerStatefulWidget {
  const EnterCodePage({super.key, required this.mode});

  final CodeMode mode;

  @override
  ConsumerState<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends ConsumerState<EnterCodePage> {
  String _digits = '';
  String? _error;
  bool _busy = false;

  bool get _isOrg => widget.mode == CodeMode.org;

  void _type(String d) {
    if (_busy || _digits.length >= kCodeLength) return;
    setState(() {
      _digits += d;
      _error = null;
    });
    if (_digits.length == kCodeLength) _lookup();
  }

  void _backspace() {
    if (_busy || _digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _error = null;
    });
  }

  Future<void> _lookup() async {
    setState(() => _busy = true);
    final repo = ref.read(friendsRepositoryProvider);
    final code = _digits;
    if (_isOrg) {
      final result = await repo.previewOrg(code);
      if (!mounted) return;
      setState(() => _busy = false);
      switch (result) {
        case Ok(:final value):
          await showJoinOrgSheet(context, ref, org: value, joinCode: code);
        case Error(:final error):
          setState(() => _error = friendErrorText(error));
      }
      return;
    }
    final result = await repo.previewByCode(code);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok(:final value):
        final sent = await showAddFriendSheet(
          context,
          ref,
          person: value,
          source: FriendSource.code,
          reference: code,
        );
        if (sent && mounted) Navigator.of(context).maybePop();
      case Error(:final error):
        setState(() => _error = friendErrorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isOrg ? 'friends_enter_org_code'.tr() : 'friends_enter_code'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            children: [
              FriendText(
                _isOrg
                    ? 'friends_enter_org_code_hint'.tr()
                    : 'friends_enter_code_hint'.tr(),
                center: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              CodeDigits(digits: _digits),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 56,
                child: _busy
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Text(
                        _error!,
                        style: context.textTheme.titleLarge?.copyWith(
                          color: context.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : null,
              ),
              const Spacer(),
              CodeKeypad(onDigit: _type, onBackspace: _backspace),
            ],
          ),
        ),
      ),
    );
  }
}
