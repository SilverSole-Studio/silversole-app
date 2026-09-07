import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';

/// The raw sensor values under the heat map: one row per foot on show, three
/// columns per row — 大拇趾球 / 小拇趾 / 腳跟, in [kSensorLabels] order.
///
/// A foot with no source reads `--` rather than 0, so an unwired left foot is
/// never mistaken for one measuring nothing.
class PressureReadouts extends StatelessWidget {
  const PressureReadouts({
    super.key,
    required this.feet,
    required this.right,
    this.left,
    this.hasData = true,
  });

  final FootView feet;
  final List<int> right;
  final List<int>? left;

  /// False when nothing is feeding the right foot either.
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (feet.showsLeft)
        _FootRow(
          // Labelled only when both feet are on show; on its own the tab above
          // already says which foot this is.
          label: feet == FootView.both ? 'left_foot'.tr() : null,
          pressure: left,
        ),
      if (feet.showsRight)
        _FootRow(
          label: feet == FootView.both ? 'right_foot'.tr() : null,
          pressure: hasData ? right : null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          rows[i],
        ],
      ],
    );
  }
}

class _FootRow extends StatelessWidget {
  const _FootRow({required this.label, required this.pressure});

  final String? label;

  /// Null means this foot has no source at all.
  final List<int>? pressure;

  @override
  Widget build(BuildContext context) {
    final reading = pressure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Row(
          children: [
            for (var i = 0; i < kSensorLabels.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == kSensorLabels.length - 1 ? 0 : AppSpacing.sm,
                  ),
                  child: _SensorCard(
                    label: kSensorLabels[i],
                    value: reading != null && i < reading.length
                        ? '${reading[i]}'
                        : '--',
                  ),
                ),
              ),
          ],
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
