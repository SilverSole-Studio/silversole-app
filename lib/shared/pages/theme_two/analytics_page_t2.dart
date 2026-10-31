import 'dart:async';

import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/pressure_shares.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/gait/gait_panel_t2.dart';
import 'package:silversole/shared/widgets/gait/gait_raw_record_button.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';
import 'package:silversole/shared/widgets/pressure_readouts.dart';
import 'package:silversole/shared/widgets/pressure_share_bars.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Analytics, mascot theme: gait analysis over three time scales, the badge
/// wall, and the live pressure map under its own tab.
///
/// The pressure map is live BLE FSR data, with its load splits; the raw
/// readings and the sample menu are for developer mode only. The gait figures
/// come from [gaitViewSnapshotProvider]: the wearer's own walking once gait
/// tracking is on, the bundled sample until then. The gait layout lives in
/// [GaitAnalysisPanelT2], the same shape as the classic theme's version.
class AnalyticsPageT2 extends ConsumerStatefulWidget {
  const AnalyticsPageT2({super.key});

  @override
  ConsumerState<AnalyticsPageT2> createState() => _AnalyticsPageT2State();
}

class _AnalyticsPageT2State extends ConsumerState<AnalyticsPageT2> {
  bool _showPressure = false;
  FootView _feet = FootView.both;
  GaitScale _scale = GaitScale.week;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          // stretch, not start: cards whose content is narrower than the
          // screen (the "pending" card) would otherwise shrink-wrap and sit
          // half-width next to the full-width ones.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'analytics_title'.tr(),
                style: context.textTheme.headlineLarge,
              ),
              const SizedBox(height: 14),
              _Segmented(
                labels: ['vitality_gait'.tr(), 'pressure_distribution'.tr()],
                selected: _showPressure ? 1 : 0,
                onSelected: (i) => setState(() => _showPressure = i == 1),
              ),
              const SizedBox(height: 10),
              if (_showPressure) ...[
                _Segmented(
                  labels: [for (final f in FootView.values) f.labelKey.tr()],
                  selected: _feet.index,
                  onSelected: (i) => setState(() => _feet = FootView.values[i]),
                ),
                const SizedBox(height: 14),
                _PressurePanel(feet: _feet),
              ] else ...[
                _Segmented(
                  labels: [
                    for (final scale in GaitScale.values) scale.labelKey.tr(),
                  ],
                  selected: _scale.index,
                  onSelected: (i) =>
                      setState(() => _scale = GaitScale.values[i]),
                ),
                const SizedBox(height: 14),
                if (kDebugMode) ...[
                  const GaitRawRecordButton(),
                  const SizedBox(height: 14),
                ],
                GaitAnalysisPanelT2(
                  snapshot: ref.watch(gaitViewSnapshotProvider(_scale)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Segmented control ─────────────────────────────────────────────────────

/// Outlined stadium track with the active segment filled gold — this theme's
/// answer to SegmentedButton.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppPaletteT2.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppPaletteT2.ink,
          width: AppPaletteT2.outlineWidth,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: i == selected
                      ? BoxDecoration(
                          color: AppPaletteT2.gold,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppPaletteT2.ink, width: 2),
                        )
                      : null,
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: i == selected
                          ? AppPaletteT2.ink
                          : AppPaletteT2.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Pressure ──────────────────────────────────────────────────────────────

/// The live foot-pressure heat map and the forefoot-heel and inner-outer
/// splits under it, for everyone. The raw sensor readings and the example menu
/// (which replays a canned motion) show only in developer mode.
class _PressurePanel extends ConsumerStatefulWidget {
  const _PressurePanel({required this.feet});

  final FootView feet;

  @override
  ConsumerState<_PressurePanel> createState() => _PressurePanelState();
}

class _PressurePanelState extends ConsumerState<_PressurePanel> {
  final _tracker = PressureShareTracker();

  /// Fires once the newest sample has aged out of the window, so a foot that
  /// goes silent is redrawn blank instead of keeping its last numbers.
  Timer? _staleTimer;

  @override
  void dispose() {
    _staleTimer?.cancel();
    super.dispose();
  }

  void _armStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer(
      PressureShareWindow.span + const Duration(milliseconds: 300),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final devMode = ref.watch(
      settingsProvider.select((s) => s.firmwareDevMode),
    );
    final feet = widget.feet;
    return PressureDemoScope(
      showMenu: devMode,
      builder: (context, reading, header) {
        final accepted = _tracker.update(
          at: clock.now(),
          rightReading: reading.right,
          rightSource: reading.rightSource ?? reading.right,
          hasRight: reading.hasData,
          leftReading: reading.left,
          leftSource: reading.leftSource,
          isSample: reading.isSample,
        );
        if (accepted) _armStaleTimer();
        // A foot that has gone quiet is drawn blank rather than frozen on its
        // last frame. A playing sample clip is always fresh.
        final rightHeat = reading.isSample || _tracker.right.hasFresh
            ? reading.right
            : const <int>[0, 0, 0];
        final leftHeat =
            reading.left == null || reading.isSample || _tracker.left.hasFresh
            ? reading.left
            : const <int>[0, 0, 0];
        return MascotCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Center(
                child: FootPressureHeatmap(
                  pressure: rightHeat,
                  leftPressure: leftHeat,
                  feet: feet,
                ),
              ),
              const SizedBox(height: 14),
              PressureShareBars(
                feet: feet,
                right: _tracker.right.shares,
                left: _tracker.left.shares,
                rightConnected: reading.hasData,
                leftConnected: reading.left != null,
              ),
              if (devMode) ...[
                const SizedBox(height: 14),
                Text(
                  'pressure_raw_title'.tr(),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                PressureReadouts(
                  feet: feet,
                  right: reading.right,
                  left: reading.left,
                  hasData: reading.hasData,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
