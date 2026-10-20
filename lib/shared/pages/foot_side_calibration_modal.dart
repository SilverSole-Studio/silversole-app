// lib/shared/pages/foot_side_calibration_modal.dart
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/ble/foot_side_calibration.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/ble_paired_device_model.dart';
import 'package:silversole/shared/models/foot_side.dart';
import 'package:silversole/shared/models/live_telemetry_state.dart';
import 'package:silversole/shared/providers/foot_side_calibration_provider.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/live_telemetry_notifier.dart';

/// How long to wait for a step before offering to pick the sides by hand. A
/// dead FSR must never trap the wearer in here.
const _calibrationTimeout = Duration(seconds: 15);

/// Reading mapped to a full bar: three sensors at the heat map's own scale.
const _fullScale = 4096 * 3;

/// Asks the wearer which sole is which, as soon as both feet are connected.
///
/// Wrapped around the whole app like `FallDemoOverlay` rather than pushed as a
/// route: the question is about the hardware, not about wherever the wearer
/// happens to be, and an overlay needs no navigator context.
///
/// Stays up until the sides are assigned or the wearer puts it off; "later"
/// comes back the next time a different pair of soles connects.
class FootSideCalibrationOverlay extends ConsumerStatefulWidget {
  const FootSideCalibrationOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FootSideCalibrationOverlay> createState() =>
      _FootSideCalibrationOverlayState();
}

class _FootSideCalibrationOverlayState
    extends ConsumerState<FootSideCalibrationOverlay> {
  /// The pair the wearer put off answering for.
  String? _dismissedPair;

  @override
  Widget build(BuildContext context) {
    final soles = ref.watch(connectedPairedSolesProvider);
    final needed = ref.watch(needsFootSideCalibrationProvider);
    final pair = soles.map((s) => s.identityKey).join('+');

    return Stack(
      children: [
        widget.child,
        if (needed && _dismissedPair != pair)
          _CalibrationPanel(
            // A different pair gets a fresh panel, and therefore fresh
            // baselines and subscriptions.
            key: ValueKey(pair),
            soles: soles,
            onDismiss: () => setState(() => _dismissedPair = pair),
          ),
      ],
    );
  }
}

class _CalibrationPanel extends ConsumerStatefulWidget {
  const _CalibrationPanel({
    super.key,
    required this.soles,
    required this.onDismiss,
  });

  /// The connected soles — two of them, by [needsFootSideCalibrationProvider].
  final List<BlePairedDevice> soles;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_CalibrationPanel> createState() => _CalibrationPanelState();
}

class _CalibrationPanelState extends ConsumerState<_CalibrationPanel> {
  final _calibrator = FootSideCalibrator();
  final _subs = <ProviderSubscription<LiveTelemetryState>>[];

  /// Latest pressure sum per sole, for the live bars.
  final _sums = <String, int>{};

  Timer? _timeout;
  var _ambiguous = false;
  var _timedOut = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    // listenManual rather than ref.listen in build: one subscription per sole
    // key, created once. The panel's ValueKey means a different pair rebuilds
    // this State from scratch instead of swapping keys underneath it.
    for (final sole in widget.soles) {
      final soleKey = sole.identityKey;
      _subs.add(
        ref.listenManual(liveTelemetryProvider(soleKey), (_, next) {
          final sample = next.recentImu.lastOrNull;
          final at = next.updatedAt;
          if (sample == null || at == null) return;
          _feed(soleKey, sample.pressure.fold<int>(0, (a, b) => a + b), at);
        }),
      );
    }
    _armTimeout();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    for (final sub in _subs) {
      sub.close();
    }
    super.dispose();
  }

  void _armTimeout() {
    _timeout?.cancel();
    _timeout = Timer(_calibrationTimeout, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  void _feed(String soleKey, int sum, DateTime at) {
    if (_saving || !mounted) return;
    setState(() => _sums[soleKey] = sum);
    final decision = _calibrator.add(soleKey, sum, at);
    if (decision == null) return;
    if (decision.ambiguous) {
      setState(() => _ambiguous = true);
      _restart(keepAmbiguous: true);
      return;
    }
    unawaited(_assign(decision.leftKey!));
  }

  /// Measures again from scratch — the "try again" button, and what an
  /// ambiguous step does on its own. An ambiguous restart keeps its message up;
  /// a manual one clears it, and either frees a stranded save so Retry is a
  /// real way out.
  void _restart({bool keepAmbiguous = false}) {
    _calibrator.reset();
    _sums.clear();
    _armTimeout();
    setState(() {
      _timedOut = false;
      _saving = false;
      if (!keepAmbiguous) _ambiguous = false;
    });
  }

  /// Writes both sides at once: the sole that was stepped on is the left foot,
  /// so the other one is the right. The panel disappears on its own when
  /// [needsFootSideCalibrationProvider] goes false.
  Future<void> _assign(String leftKey) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final settings = ref.read(settingsProvider.notifier);
      await settings.setFootSide(leftKey, FootSide.left);
      for (final sole in widget.soles) {
        if (sole.identityKey == leftKey) continue;
        await settings.setFootSide(sole.identityKey, FootSide.right);
      }
    } catch (e) {
      // Left unassigned, so the panel stays and the wearer can step again or
      // pick by hand instead of facing a panel that ignores everything.
      debugPrint('foot side assignment failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _label(BlePairedDevice sole) =>
      sole.shortId == null ? sole.name : '••••${sole.shortId}';

  /// Whether this looks like a correction rather than a first calibration.
  ///
  /// A first-time pair arrives with **two** soles unassigned; clearing one
  /// side to redo a wrong answer leaves exactly **one**. That is enough to
  /// tell the two apart without keeping any extra state — and it matters,
  /// because a wearer who got here by mis-stepping may well mis-step again,
  /// so the by-hand buttons are the reliable way out and should not be behind
  /// the 15 s wait.
  bool get _redoing =>
      widget.soles.where((s) => s.footSide == null).length == 1;

  @override
  Widget build(BuildContext context) {
    final message = _timedOut
        ? 'foot_side_calibration_timeout'.tr()
        : _ambiguous
        ? 'foot_side_calibration_ambiguous'.tr()
        : 'foot_side_calibration_hint'.tr();

    // The overlay is not a route, so Android's back key would otherwise pop
    // whatever sits *behind* it and leave the panel on top of a screen the
    // wearer did not ask for. Spec §8.2 names the back key as an exit
    // alongside "later", so it takes the same way out.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onDismiss();
      },
      child: Material(
        color: context.colorScheme.scrim.withValues(alpha: 0.72),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.base,
                    children: [
                      Text(
                        'foot_side_calibration_title'.tr(),
                        style: context.textTheme.titleLarge,
                      ),
                      Text(message, style: context.textTheme.bodyMedium),
                      if (!_timedOut)
                        Text(
                          'foot_side_calibration_prompt'.tr(),
                          style: context.textTheme.headlineSmall,
                        ),
                      for (final sole in widget.soles)
                        _SolePressureRow(
                          label: _label(sole),
                          value: ((_sums[sole.identityKey] ?? 0) / _fullScale)
                              .clamp(0.0, 1.0),
                          // Behind the timeout on a first calibration, so the
                          // usual path stays "step on it" — but offered at
                          // once when this is a correction.
                          onPickLeft: _timedOut || _redoing
                              ? () => unawaited(_assign(sole.identityKey))
                              : null,
                        ),
                      Row(
                        spacing: AppSpacing.sm,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onDismiss,
                              child: Text('foot_side_later'.tr()),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: _restart,
                              child: Text('foot_side_retry'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One sole's live pressure, plus the by-hand escape — offered once the wait
/// times out, or straight away when a side is being corrected.
class _SolePressureRow extends StatelessWidget {
  const _SolePressureRow({
    required this.label,
    required this.value,
    required this.onPickLeft,
  });

  final String label;
  final double value;
  final VoidCallback? onPickLeft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.textTheme.labelLarge)),
            if (onPickLeft != null)
              TextButton(
                onPressed: onPickLeft,
                child: Text('foot_side_this_is_left'.tr()),
              ),
          ],
        ),
        LinearProgressIndicator(
          year2023: false, // ignore: deprecated_member_use
          value: value,
          minHeight: 10,
          borderRadius: BorderRadius.circular(999),
          stopIndicatorRadius: 0,
          trackGap: 4,
          backgroundColor: context.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(context.tokens.dataOrange),
        ),
      ],
    );
  }
}
