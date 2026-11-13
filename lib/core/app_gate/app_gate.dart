import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:silversole/core/app_gate/app_gate_check.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Runs the whole gate and returns the decision for this device.
typedef AppGateRunner = Future<AppGateDecision> Function();

/// Opens the store page.
typedef StoreOpener = Future<void> Function(String url);

/// Minimum gap between two checks.
const Duration kAppGateRecheckGap = Duration(minutes: 1);

Future<AppGateDecision> defaultAppGateRunner() async {
  if (kIsWeb) return const AppGateDecision.allowed();
  final platform = Platform.isIOS
      ? 'ios'
      : Platform.isAndroid
          ? 'android'
          : '';
  try {
    final info = await PackageInfo.fromPlatform();
    return checkAppGate(
      currentVersion: info.version,
      platform: platform,
      fetch: (p) async {
        final res = await Supabase.instance.client
            .rpc('app_min_version', params: {'p_platform': p});
        return res is Map ? Map<String, dynamic>.from(res) : null;
      },
    );
  } catch (_) {
    return const AppGateDecision.allowed();
  }
}

Future<void> defaultStoreOpener(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Covers the whole app with an update screen when this version is too old.
/// Checks at startup and again on returning to foreground (at most once per
/// [kAppGateRecheckGap]).
class AppGate extends StatefulWidget {
  const AppGate({
    super.key,
    required this.child,
    this.runner = defaultAppGateRunner,
    this.openStore = defaultStoreOpener,
    this.now = DateTime.now,
  });

  final Widget child;
  final AppGateRunner runner;
  final StoreOpener openStore;
  final DateTime Function() now;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  AppGateDecision _decision = const AppGateDecision.allowed();
  DateTime? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last != null && widget.now().difference(last) < kAppGateRecheckGap) {
      return;
    }
    _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    _lastCheck = widget.now();
    try {
      final d = await widget.runner();
      if (mounted) setState(() => _decision = d);
    } catch (_) {
      // Fail open.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _decision.storeUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_decision.blocked && url != null)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              child: _UpdateRequiredScreen(
                onUpdate: () => widget.openStore(url),
              ),
            ),
          ),
      ],
    );
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen({required this.onUpdate});

  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'update_required_title'.tr(),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'update_required_body'.tr(),
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: onUpdate,
                  child: Text('update_required_button'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
