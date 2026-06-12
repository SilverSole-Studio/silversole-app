import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FootPressureHeatmap(pressure: pressure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SensorReadouts(pressure: pressure, hasData: hasData),
              const SizedBox(height: 16),
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
                right: i == kSensorLabels.length - 1 ? 0 : 8,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'Oxanium',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PressureLegend extends StatelessWidget {
  const _PressureLegend();

  // Representative jet stops, matching the heatmap colormap.
  static const _jetColors = [
    Color(0xFF00007F),
    Color(0xFF0000FF),
    Color(0xFF00FFFF),
    Color(0xFF00FF00),
    Color(0xFFFFFF00),
    Color(0xFFFF7F00),
    Color(0xFFFF0000),
  ];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.grey);
    return Column(
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(colors: _jetColors),
          ),
        ),
        const SizedBox(height: 4),
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
