import 'package:clock/clock.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/pressure_shares.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/providers/gait_providers.dart';
import 'package:silversole/shared/providers/settings_provider.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/gait/gait_panel.dart';
import 'package:silversole/shared/widgets/gait/gait_raw_record_button.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';
import 'package:silversole/shared/widgets/pressure_readouts.dart';
import 'package:silversole/shared/widgets/pressure_share_bars.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// Analytics, classic theme.
///
/// Gait analysis over three time scales plus the live pressure map, using this
/// theme's own vocabulary: stock [SegmentedButton]s styled by the theme,
/// [SectionCard], and the blue accent for data.
///
/// The pressure map is live BLE FSR data, with its load splits; the raw
/// readings and the sample menu are for developer mode only. The gait figures
/// come from [gaitViewSnapshotProvider]: the wearer's own walking once gait
/// tracking is on, the bundled sample until then. The gait layout itself lives
/// in [GaitAnalysisPanel], shared in shape with the mascot theme's version.
class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
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
                if (kDebugMode) const GaitRawRecordButton(),
                GaitAnalysisPanel(
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

  @override
  void didUpdateWidget(_PressurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feet != widget.feet) _tracker.clear();
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
        _tracker.update(
          at: clock.now(),
          rightReading: reading.right,
          hasRight: reading.hasData,
          leftReading: reading.left,
          isSample: reading.isSample,
        );
        return SectionCard(
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
              PressureShareBars(
                feet: feet,
                right: _tracker.right.shares,
                left: _tracker.left.shares,
                rightConnected: reading.hasData,
                leftConnected: reading.left != null,
              ),
              if (devMode) ...[
                const SizedBox(height: AppSpacing.base),
                Text(
                  'pressure_raw_title'.tr(),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
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
