import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/fall_tilt_detector.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/fall_demo_provider.dart';

/// `AppTokens.alert` is theme-independent (DESIGN.md's `state/alert`), so one
/// fixed contrast color is correct in both light and dark.
const _onAlert = Colors.white;

/// How often the sole buzzes while a fall judgement is building up.
const _pulseInterval = Duration(milliseconds: 500);

/// The red full-screen fall warning for demos.
///
/// While the tilt is being held the phone pulses every [_pulseInterval] so the
/// judgement can be felt coming, then buzzes once when it fires. Haptics go
/// through [HapticFeedback], which needs no permission but does follow the
/// system's touch-vibration setting.
///
/// The panel **latches**: once it is up, only its button takes it away. The
/// wearer standing back up deliberately does not dismiss it — that is the whole
/// point of a fall alarm.
///
/// Wrapped around the whole app so it covers every page in either theme.
/// Temporary — see [FallTiltDetector]. It only draws and buzzes: no
/// notification, no history, no upload.
class FallDemoOverlay extends ConsumerStatefulWidget {
  const FallDemoOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FallDemoOverlay> createState() => _FallDemoOverlayState();
}

class _FallDemoOverlayState extends ConsumerState<FallDemoOverlay> {
  /// The judgement the panel is reporting, or null when no panel is up. Keeps
  /// counting while the sole stays down, then freezes at the moment the wearer
  /// got back up, so the readout shows how long they were down for.
  FallTilt? _latched;

  /// Set by the button so the panel does not latch straight back while the sole
  /// is still lying there. Cleared once the judgement clears.
  bool _suppressed = false;

  Timer? _pulseTimer;

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  void _onTilt(FallTilt? _, FallTilt next) {
    // Building up: pulse until it either fires or the sole comes back down.
    if (next.progress > 0 && !next.fallen) {
      _pulseTimer ??= Timer.periodic(
        _pulseInterval,
        (_) => unawaited(HapticFeedback.lightImpact()),
      );
    } else {
      _pulseTimer?.cancel();
      _pulseTimer = null;
    }

    if (!next.fallen) {
      // Upright again: re-arm for the next run. The panel itself stays put.
      _suppressed = false;
      return;
    }
    if (_suppressed) return;
    if (_latched == null) unawaited(HapticFeedback.heavyImpact());
    setState(() => _latched = next);
  }

  void _dismiss() => setState(() {
    _latched = null;
    _suppressed = true;
  });

  @override
  Widget build(BuildContext context) {
    ref.listen(fallDemoProvider, _onTilt);
    final latched = _latched;

    return Stack(
      children: [
        widget.child,
        if (latched != null)
          Positioned.fill(
            child: _FallPanel(tilt: latched, onDismiss: _dismiss),
          ),
      ],
    );
  }
}

class _FallPanel extends StatelessWidget {
  const _FallPanel({required this.tilt, required this.onDismiss});

  final FallTilt tilt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tokens.alert,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.lg,
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 56,
                backgroundColor: _onAlert.withValues(alpha: 0.2),
                child: const Icon(
                  LucideIcons.triangleAlert,
                  size: 56,
                  color: _onAlert,
                ),
              ),
              Text(
                'fall_detected_demo'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.displaySmall.bold?.copyWith(
                  color: _onAlert,
                ),
              ),
              Text(
                'fall_demo_readout'.tr(
                  args: [
                    tilt.tiltDegrees.toStringAsFixed(0),
                    (tilt.held.inMilliseconds / 1000).toStringAsFixed(1),
                  ],
                ),
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium?.copyWith(
                  color: _onAlert.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onDismiss,
                style: FilledButton.styleFrom(
                  backgroundColor: _onAlert,
                  foregroundColor: context.tokens.alert,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text('fall_demo_dismiss'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
