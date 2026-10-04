import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/widgets/gait/gait_charts.dart';
import 'package:silversole/shared/widgets/gait/gait_topic_sheet.dart';
import 'package:silversole/shared/widgets/section_card.dart';

/// The gait analysis tab, classic theme.
///
/// Follows the approved design: a hero speed figure with its trend phase, then
/// two groups — "walking ability" (is it declining?) and "walking stability"
/// (is the walking steady?) — because those answer different questions and only
/// the second is the one tied to repeated falls. Fall records sit with the
/// stability group on purpose: a previous fall is the strongest single
/// predictor there is.
///
/// Figures are mockup copy, see [gaitSnapshot]. Every metric carries an ⓘ that
/// explains what it is and what it cannot tell you.
class GaitAnalysisPanel extends StatelessWidget {
  const GaitAnalysisPanel({super.key, required this.scale});

  final GaitScale scale;

  @override
  Widget build(BuildContext context) {
    final snapshot = gaitSnapshot(scale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        _Hero(snapshot: snapshot),

        _GroupLabel('gait_group_ability'.tr()),
        _SpeedChartCard(snapshot: snapshot),
        for (final metric in snapshot.ability) _MetricTile(metric: metric),

        _GroupLabel('gait_group_stability'.tr()),
        for (final metric in snapshot.stability) _MetricTile(metric: metric),
        if (snapshot.hasStanceChart)
          SectionCard(
            title: 'gait_sect_lr_stance'.tr(),
            child: SizedBox(
              height: 170,
              child: GaitStanceChart(
                left: snapshot.stanceLeft,
                right: snapshot.stanceRight,
                leftColor: context.colorScheme.primary,
                rightColor: context.tokens.dataOrange,
              ),
            ),
          ),
        if (snapshot.hasPhaseTimeline)
          SectionCard(
            title: 'gait_sect_phase'.tr(),
            trailing: const GaitTopicButton(topic: GaitTopic.phase),
            child: GaitPhaseTimeline(
              spans: snapshot.phaseSpans,
              colorOf: (phase) => phaseColor(context, phase),
            ),
          ),
        if (snapshot.hasSmallMultiples)
          SectionCard(
            title: 'gait_sect_four_metrics'.tr(),
            child: GaitSmallMultiples(
              lines: snapshot.smallMultiples,
              colorOf: (tone) => toneColor(context, tone),
            ),
          ),

        _FallCard(snapshot: snapshot),
        if (snapshot.hasAdvice) _AdviceCard(keys: snapshot.adviceKeys),
        _NoteCard(textKey: snapshot.noteKey),
      ],
    );
  }
}

/// The speed chart for the scale in view. On the long trajectory the phases are
/// tinted behind the plot and every point takes its phase's color, so the
/// stable/declining/watch split can be seen on the chart itself rather than
/// only read off the timeline below it.
class _SpeedChartCard extends StatelessWidget {
  const _SpeedChartCard({required this.snapshot});

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final isWeek = snapshot.scale == GaitScale.week;
    final reference = snapshot.referenceSpeed;
    final muted = context.colorScheme.onSurfaceVariant;

    return SectionCard(
      title: snapshot.chartLabelKey.tr(),
      trailing: GaitTopicButton(
        topic: isWeek ? GaitTopic.speed : GaitTopic.binning,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          SizedBox(
            height: snapshot.hasPhaseTimeline ? 185 : 155,
            child: isWeek
                ? GaitSpeedBars(
                    values: snapshot.speedSeries,
                    color: context.colorScheme.primary,
                  )
                : GaitTrendChart(
                    values: snapshot.speedSeries,
                    color: context.colorScheme.primary,
                    openLast: true,
                    weekLabels: true,
                    showLeftAxis: snapshot.hasPhaseTimeline,
                    bands: [
                      for (final band in snapshot.phaseBands)
                        GaitChartBand(
                          fromX: band.from,
                          toX: band.to,
                          color: phaseColor(
                            context,
                            band.phase,
                          ).withValues(alpha: 0.13),
                        ),
                    ],
                    dotColorAt: snapshot.hasPhaseTimeline
                        ? (index) =>
                              phaseColor(context, snapshot.phaseAt(index))
                        : null,
                    reference: reference == null
                        ? null
                        : GaitReferenceBand(
                            value: reference,
                            uncertainty: snapshot.referenceUncertainty ?? 0,
                            label: 'gait_ref_value'.tr(
                              args: [reference.toStringAsFixed(2)],
                            ),
                          ),
                  ),
          ),
          if (!isWeek)
            Text(
              'gait_in_progress'.tr(),
              style: context.textTheme.bodySmall?.copyWith(color: muted),
            ),
          if (reference != null)
            Text(
              'gait_ref_band'.tr(),
              style: context.textTheme.bodySmall?.copyWith(color: muted),
            ),
        ],
      ),
    );
  }
}

/// Functional hues for this theme: a change can be neutral, an improvement, or
/// worth attention.
Color toneColor(BuildContext context, GaitTone tone) => switch (tone) {
  GaitTone.neutral => context.colorScheme.onSurfaceVariant,
  GaitTone.good => context.tokens.success,
  GaitTone.warn => context.tokens.dataOrange,
  GaitTone.alert => context.tokens.alert,
};

Color phaseColor(BuildContext context, GaitPhase phase) => switch (phase) {
  GaitPhase.stable => context.tokens.success,
  GaitPhase.declining => context.tokens.dataOrange,
  GaitPhase.alert => context.tokens.alert,
};

/// Group heading: the accent-colored rule that splits the two questions the
/// page answers.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        text,
        style: context.textTheme.titleSmall.bold?.copyWith(
          color: context.colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Speed, the one figure read at a glance, with the phase it sits in.
class _Hero extends StatelessWidget {
  const _Hero({required this.snapshot});

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final phase = phaseColor(context, snapshot.phase);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Row(
            children: [
              _PhasePill(phase: snapshot.phase, color: phase),
              const GaitTopicButton(topic: GaitTopic.phase),
            ],
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  snapshot.heroLabelKey.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const GaitTopicButton(topic: GaitTopic.speed),
              Text(
                'gait_live_daily'.tr(),
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                snapshot.heroValue,
                style: context.textTheme.displayMedium.bold,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'gait_unit_mps'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              Text(
                '${snapshot.heroDelta} ${snapshot.heroDeltaSuffixKey.tr()}',
                style: context.textTheme.titleMedium.bold?.copyWith(
                  color: toneColor(context, snapshot.heroTone),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.thresholdNoteKey.tr(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const GaitTopicButton(topic: GaitTopic.threshold),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.phase, required this.color});

  final GaitPhase phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Text(
              phase.labelKey.tr(),
              style: context.textTheme.titleSmall.bold?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// One metric: what it is and how to read it on the left, the figure and its
/// change on the right.
class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final GaitMetric metric;

  @override
  Widget build(BuildContext context) {
    final tone = toneColor(context, metric.tone);
    final muted = context.colorScheme.onSurfaceVariant;

    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        metric.nameKey.tr(),
                        style: context.textTheme.titleMedium,
                      ),
                    ),
                    GaitTopicButton(topic: metric.topic),
                    if (metric.isAuxiliary) _AuxBadge(),
                  ],
                ),
                Text(
                  metric.readingKey.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(color: muted),
                ),
                if (metric.subKey != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${metric.subKey!.tr()} '),
                          TextSpan(
                            text: metric.subValue,
                            style: context.textTheme.titleSmall.bold,
                          ),
                          TextSpan(
                            text: '  ${metric.subDelta}',
                            style: TextStyle(color: tone),
                          ),
                        ],
                      ),
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    metric.value,
                    style: context.textTheme.headlineMedium.bold,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    metric.unitKey.tr(),
                    style: context.textTheme.labelLarge?.copyWith(color: muted),
                  ),
                ],
              ),
              Text(
                metric.delta,
                style: context.textTheme.titleSmall.bold?.copyWith(color: tone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Marks a metric as watched but deliberately outside the phase decision.
class _AuxBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.subR,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          'gait_aux'.tr(),
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Falls sit with the gait metrics because a previous fall predicts the next
/// one better than any of them.
class _FallCard extends StatelessWidget {
  const _FallCard({required this.snapshot});

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final alert = context.tokens.alert;

    return SectionCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: alert.withValues(alpha: 0.12),
            child: Icon(LucideIcons.triangleAlert, size: 18, color: alert),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'gait_fall_title'.tr(),
                        style: context.textTheme.titleMedium,
                      ),
                    ),
                    const GaitTopicButton(topic: GaitTopic.falls),
                  ],
                ),
                Text(
                  snapshot.fallLastKey.tr(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${snapshot.fallCount}',
                style: context.textTheme.headlineMedium.bold?.copyWith(
                  color: alert,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'gait_fall_unit'.tr(),
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'gait_advice_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          for (final key in keys)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(key.tr(), style: context.textTheme.bodyLarge),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Closing paragraph: how much data is behind the page and what it does not
/// cover.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.textKey});

  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        textKey.tr(),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
