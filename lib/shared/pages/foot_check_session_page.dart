import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/dialogs/basic_dialog.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';

/// Mock "one-minute foot-pressure check": a 60 s collection session with the
/// live pressure map underneath, ending on [FootCheckResultPage].
///
/// Nothing is recorded or uploaded — the session only runs its own clock and
/// reads the live telemetry providers, and the score it ends on is random.
///
/// Two separate ways out, because they mean different things: the back button
/// abandons the minute, while "end early" stops collecting and reports on what
/// it has. Both confirm first, and the system back gesture goes through the
/// same confirmation.
class FootCheckSessionPage extends ConsumerStatefulWidget {
  const FootCheckSessionPage({super.key});

  /// How long one check collects for.
  static const sessionLength = Duration(seconds: 60);

  /// Progress refresh. Fast enough that the bar creeps rather than stepping
  /// once a second.
  static const tick = Duration(milliseconds: 200);

  @override
  ConsumerState<FootCheckSessionPage> createState() =>
      _FootCheckSessionPageState();
}

class _FootCheckSessionPageState extends ConsumerState<FootCheckSessionPage> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  /// Everything the pressure half has shown, summed up for the report. The
  /// analysis therefore describes exactly what was on screen — including a
  /// sample clip, so a demo with no sole still produces real ratios.
  final _tally = FootPressureTally();

  /// The last reading counted, so a rebuild for any other reason (the clock
  /// ticking, new IMU) cannot count the same reading twice.
  List<int>? _counted;

  double get _progress =>
      (_elapsed.inMilliseconds /
              FootCheckSessionPage.sessionLength.inMilliseconds)
          .clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(FootCheckSessionPage.tick, (_) {
      setState(() => _elapsed += FootCheckSessionPage.tick);
      if (_elapsed >= FootCheckSessionPage.sessionLength) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Counts one reading from the pressure half. Called from `build`, which is
  /// safe because it notifies nothing and ignores a reading already seen.
  void _collect(List<int> pressure) {
    if (identical(pressure, _counted)) return;
    _counted = pressure;
    _tally.add(pressure);
  }

  /// Hands over to the report with whatever was collected.
  void _finish() {
    if (!mounted) return;
    _timer?.cancel();
    _timer = null;
    context.pushReplacement(
      '/foot-check-result',
      extra: FootCheckReport(
        balance: _tally.balance,
        samples: _tally.samples,
        collected: _elapsed,
      ),
    );
  }

  /// The back button throws the minute away, so it asks first.
  Future<void> _requestAbandon() async {
    await showConfirmLeaveDialog(
      context,
      title: 'foot_check_abandon_title'.tr(),
      text: 'foot_check_quit_content'.tr(),
      confirmText: 'foot_check_abandon_confirm'.tr(),
      confirmType: ConfirmType.delete,
      onConfirm: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  /// Ending early still reports — it just reports on a shorter minute.
  Future<void> _requestFinishEarly() async {
    await showConfirmLeaveDialog(
      context,
      title: 'foot_check_finish_early_title'.tr(),
      text: 'foot_check_finish_early_content'.tr(),
      confirmText: 'foot_check_quit_confirm'.tr(),
      onConfirm: _finish,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The back gesture must not slip past the confirmation either.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestAbandon());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => unawaited(_requestAbandon())),
          title: Text(
            'foot_check_session_title'.tr(),
            style: context.textTheme.titleLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => unawaited(_requestFinishEarly()),
              child: Text('foot_check_quit'.tr()),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: SafeArea(
          top: false,
          child: PressureDemoScope(
            builder: (context, reading, sampleMenu) {
              _collect(reading.right);
              return Column(
                children: [
                  _SessionHeader(elapsed: _elapsed, progress: _progress),
                  const Divider(height: 1),
                  Expanded(
                    child: _PressureHalf(reading: reading, menu: sampleMenu),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The clock and its bar, pinned to the top of the screen: the progress of the
/// minute is what this half is about. The page is for the wearer, so it shows
/// no sensor readouts (tilt, acceleration, sample counts) — only a hint while
/// no sole data has arrived yet.
class _SessionHeader extends ConsumerWidget {
  const _SessionHeader({required this.elapsed, required this.progress});

  final Duration elapsed;
  final double progress;

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(
      telemetryViewProvider.select((v) => v.recentImu.isEmpty),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.sm,
        AppSpacing.base,
        AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_clock(elapsed), style: context.textTheme.displayMedium),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '/ ${_clock(FootCheckSessionPage.sessionLength)}',
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            minHeight: 14,
            year2023: false, // ignore: deprecated_member_use
            borderRadius: AppRadius.subR,
            stopIndicatorRadius: 0,
            trackGap: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'foot_check_collecting'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.primary,
            ),
          ),
          if (waiting) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'foot_check_waiting'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom half: the live plantar pressure map, with the sample-clip menu so a
/// demo works with no sole connected. No raw FSR numbers — the page is for the
/// wearer.
class _PressureHalf extends StatelessWidget {
  const _PressureHalf({required this.reading, required this.menu});

  final PressureReading reading;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'foot_pressure_distribution'.tr(),
                  style: context.textTheme.titleMedium,
                ),
              ),
              menu,
            ],
          ),
          Expanded(
            child: reading.hasData
                // Right foot only: the sole reports one foot anyway and the
                // pair would squeeze each into half the width.
                ? FootPressureHeatmap(
                    pressure: reading.right,
                    feet: FootView.right,
                  )
                : Center(
                    child: Text(
                      'foot_check_waiting'.tr(),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
