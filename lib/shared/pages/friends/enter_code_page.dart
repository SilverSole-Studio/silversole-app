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

/// `/friends/code` — type or paste an 8-digit friend code or org code with the
/// system number keyboard. The lookup runs as soon as the eighth digit is in
/// (spec §3.2, §3.3).
class EnterCodePage extends ConsumerStatefulWidget {
  const EnterCodePage({super.key, required this.mode});

  final CodeMode mode;

  @override
  ConsumerState<EnterCodePage> createState() => _EnterCodePageState();
}

class _EnterCodePageState extends ConsumerState<EnterCodePage> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  bool get _isOrg => widget.mode == CodeMode.org;

  String get _digits => _controller.text;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    setState(() => _error = null);
    if (_digits.length == kCodeLength && !_busy) {
      // The system keyboard would cover the sheet the lookup opens.
      FocusScope.of(context).unfocus();
      _lookup();
    }
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
          setState(() => _error = friendErrorText(error, FriendErrorScope.org));
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
              TextField(
                controller: _controller,
                autofocus: true,
                readOnly: _busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: const [CodeInputFormatter()],
                onChanged: _onChanged,
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium?.copyWith(
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(hintText: '0000 0000'),
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
