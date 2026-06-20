import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/providers/telemetry_process_providers/telemetry_view_provider.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';

class PressureVisualizationPage extends ConsumerWidget {
  const PressureVisualizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(telemetryViewProvider);
    final imu = state.recentImu;
    final hasData = imu.isNotEmpty;
    final pressure = hasData ? imu.last.pressure : const <int>[0, 0, 0];

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
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: FootPressureHeatmap(pressure: pressure),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              _SensorReadouts(pressure: pressure, hasData: hasData),
              const SizedBox(height: AppSpacing.base),
              const _PressureLegend(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorReadouts extends StatelessWidget {
  const _SensorReadouts({required this.pressure, required this.hasData});

  final List<int> pressure;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kSensorLabels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == kSensorLabels.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: _SensorCard(
                label: kSensorLabels[i],
                value: hasData && i < pressure.length ? '${pressure[i]}' : '--',
              ),
            ),
          ),
      ],
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.fieldR,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: context.textTheme.titleLarge),
        ],
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
