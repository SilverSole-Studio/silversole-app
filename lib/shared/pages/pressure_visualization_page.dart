import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';
import 'package:silversole/shared/widgets/pressure_demo_scope.dart';
import 'package:silversole/shared/widgets/pressure_readouts.dart';

class PressureVisualizationPage extends StatefulWidget {
  const PressureVisualizationPage({super.key});

  @override
  State<PressureVisualizationPage> createState() =>
      _PressureVisualizationPageState();
}

class _PressureVisualizationPageState extends State<PressureVisualizationPage> {
  FootView _feet = FootView.both;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'pressure_visualization'.tr(),
          style: context.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: PressureDemoScope(
            builder: (context, reading, header) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: FootPressureHeatmap(
                        pressure: reading.right,
                        leftPressure: reading.left,
                        feet: _feet,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
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
                const SizedBox(height: AppSpacing.base),
                PressureReadouts(
                  feet: _feet,
                  right: reading.right,
                  left: reading.left,
                  hasData: reading.hasData,
                ),
                const SizedBox(height: AppSpacing.base),
                const _PressureLegend(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PressureLegend extends StatelessWidget {
  const _PressureLegend();

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.labelSmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return Column(
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            // Representative jet stops, matching the heatmap colormap.
            gradient: const LinearGradient(colors: AppPalette.pressureJet),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('low'.tr(), style: style),
            Text('high'.tr(), style: style),
          ],
        ),
      ],
    );
  }
}
