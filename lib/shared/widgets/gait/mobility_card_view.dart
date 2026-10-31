import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/mobility_card.dart';
import 'package:silversole/shared/widgets/gait/gait_charts.dart';

/// The mobility card's content: this week's A–E letter against the wearer's
/// own recent weeks, one sentence on what moved, and a letter with a small
/// trend line for each metric that has one.
///
/// Both themes use it; the panel puts it inside its own card shell. The
/// letter is always drawn, so the grade never rests on color alone. While
/// [MobilityPending] it shows no letter at all. The disclaimer is always
/// the last line.
class MobilityCardView extends StatelessWidget {
  const MobilityCardView({super.key, required this.card});

  /// The card itself, for tests.
  static const cardKey = Key('mobility-card');

  final MobilityCard card;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    return KeyedSubtree(
      key: cardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('mobility_title'.tr(), style: context.textTheme.titleMedium),
              Text(
                'mobility_subtitle'.tr(),
                style: context.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
          switch (card) {
            final MobilityGraded graded => _Graded(card: graded),
            final MobilityPending pending => Text(
              // Enough weeks and still no grade means the weeks themselves
              // are short of data; counting weeks again would read as stuck.
              pending.weeksSoFar >= pending.weeksNeeded
                  ? 'mobility_pending_data'.tr()
                  : 'mobility_pending'.tr(args: ['${pending.weeksSoFar}']),
              style: context.textTheme.bodyLarge,
            ),
          },
          Text(
            'mobility_disclaimer'.tr(),
            style: context.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// The color a grade is drawn in, from the theme's own accents. A is the
/// strongest green, E the red; C is neutral so "about as usual" is not
/// painted as good or bad.
Color mobilityGradeColor(BuildContext context, MobilityGrade grade) {
  final tokens = context.tokens;
  final scheme = context.colorScheme;
  return switch (grade) {
    MobilityGrade.a => tokens.success,
    MobilityGrade.b => Color.lerp(tokens.success, scheme.surface, 0.35)!,
    MobilityGrade.c => scheme.onSurfaceVariant,
    MobilityGrade.d => tokens.dataOrange,
    MobilityGrade.e => tokens.alert,
  };
}

/// The letter color on a grade square: white or [Colors.black87], whichever
/// has the higher WCAG contrast ratio against [fill].
Color mobilityLetterColor(Color fill) {
  double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  // black87 is translucent, so judge it as it lands on the square.
  final dark = Color.alphaBlend(Colors.black87, fill);
  return ratio(Colors.white, fill) > ratio(dark, fill)
      ? Colors.white
      : Colors.black87;
}

class _Graded extends StatelessWidget {
  const _Graded({required this.card});

  final MobilityGraded card;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurfaceVariant;
    final weekStart = DateTime.parse(card.weekStart);
    final weekLabel = card.isCurrentWeek
        ? 'mobility_week_current'.tr()
        : 'mobility_week_of'.tr(args: ['${weekStart.month}/${weekStart.day}']);
    final changes = [
      for (final c in card.changes)
        'mobility_change_${c.metric.name}_${c.better ? 'up' : 'down'}'.tr(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        Text(
          weekLabel,
          style: context.textTheme.labelLarge?.copyWith(color: muted),
        ),
        Row(
          spacing: AppSpacing.base,
          children: [
            _GradeBox(grade: card.grade, size: 64),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    'mobility_grade_${card.grade.name}'.tr(),
                    style: context.textTheme.titleMedium,
                  ),
                  if (changes.isNotEmpty)
                    Text(
                      (card.isCurrentWeek
                              ? 'mobility_mainly'
                              : 'mobility_mainly_past')
                          .tr(args: [changes.join('mobility_joiner'.tr())]),
                      style: context.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
        for (final row in card.rows) _MetricRow(row: row),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.row});

  final MobilityMetricRow row;

  /// The names the gait tab already uses for the same measures.
  static const _nameKeys = {
    MobilityMetric.dailySteps: 'gait_metric_daily_steps',
    MobilityMetric.cadence: 'gait_metric_cadence',
    MobilityMetric.symmetry: 'gait_metric_symmetry',
    MobilityMetric.strideVariation: 'gait_metric_stride_cv',
    MobilityMetric.doubleSupport: 'gait_metric_double_support',
  };

  @override
  Widget build(BuildContext context) {
    final color = mobilityGradeColor(context, row.grade);
    return Row(
      spacing: AppSpacing.md,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            _nameKeys[row.metric]!.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelLarge,
          ),
        ),
        _GradeBox(grade: row.grade, size: 28),
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 30,
            child: row.trend.length < 2
                ? null
                : GaitSparkline(values: row.trend, color: color),
          ),
        ),
      ],
    );
  }
}

/// A rounded square in the grade's color with its letter in it.
class _GradeBox extends StatelessWidget {
  const _GradeBox({required this.grade, required this.size});

  final MobilityGrade grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = mobilityGradeColor(context, grade);
    final onFill = mobilityLetterColor(fill);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        grade.name.toUpperCase(),
        style: TextStyle(
          color: onFill,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
