import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/gait/gait_panel.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';
import 'package:silversole/shared/widgets/pressure_readouts.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// Analytics, classic theme.
///
/// Gait analysis over three time scales plus the live pressure map, using this
/// theme's own vocabulary: stock [SegmentedButton]s styled by the theme,
/// [SectionCard], and the blue accent for data.
///
/// Only the pressure map is real (live BLE FSR values); the gait figures are
/// mockup copy from [gaitSnapshot]. The gait layout itself lives in
/// [GaitAnalysisPanel], shared in shape with the mascot theme's version.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _showPressure = false;
  FootView _feet = FootView.both;
  GaitScale _scale = GaitScale.week;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'analytics_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            0,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.base,
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text('vitality_gait'.tr()),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('pressure_distribution'.tr()),
                  ),
                ],
                selected: {_showPressure},
                onSelectionChanged: (s) =>
                    setState(() => _showPressure = s.first),
              ),
              if (_showPressure) ...[
                SegmentedButton<FootView>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    for (final f in FootView.values)
                      ButtonSegment(
                        value: f,
                        label: Text(
                          f.labelKey.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  selected: {_feet},
                  onSelectionChanged: (s) => setState(() => _feet = s.first),
                ),
                _PressurePanel(feet: _feet),
              ] else ...[
                SegmentedButton<GaitScale>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    for (final scale in GaitScale.values)
                      ButtonSegment(
                        value: scale,
                        label: Text(
                          scale.labelKey.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  selected: {_scale},
                  onSelectionChanged: (s) => setState(() => _scale = s.first),
                ),
                GaitAnalysisPanel(scale: _scale),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pressure ──────────────────────────────────────────────────────────────

/// The live foot-pressure heat map — the one panel here backed by real data,
/// with an example menu that replays a canned motion instead.
class _PressurePanel extends StatelessWidget {
  const _PressurePanel({required this.feet});

  final FootView feet;

  @override
  Widget build(BuildContext context) {
    return PressureDemoScope(
      builder: (context, reading, header) => SectionCard(
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
            const SizedBox(height: AppSpacing.base),
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
