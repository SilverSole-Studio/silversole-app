import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/gait/gait_panel_t2.dart';
import 'package:silversole/shared/widgets/gait/gait_raw_record_button.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';
import 'package:silversole/shared/widgets/pressure_readouts.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// Analytics, mascot theme: gait analysis over three time scales, the badge
/// wall, and the live pressure map under its own tab.
///
/// The pressure map is live BLE FSR data. The gait figures come from
/// [gaitViewSnapshotProvider]: the wearer's own walking once gait tracking is
/// on, the bundled sample until then. The gait layout lives in
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
                  mobility: ref.watch(mobilityCardProvider),
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

class _PressurePanel extends StatelessWidget {
  const _PressurePanel({required this.feet});

  final FootView feet;

  @override
  Widget build(BuildContext context) {
    return PressureDemoScope(
      builder: (context, reading, header) => MascotCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Center(
              child: FootPressureHeatmap(
                pressure: reading.right,
                leftPressure: reading.left,
                feet: feet,
              ),
            ),
            const SizedBox(height: 14),
            PressureReadouts(
              feet: feet,
              right: reading.right,
              left: reading.left,
              hasData: reading.hasData,
            ),
          ],
        ),
      ),
    );
  }
}
