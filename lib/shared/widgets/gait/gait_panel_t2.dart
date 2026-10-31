import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/app_palette_t2.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';
import 'package:silversole/shared/widgets/gait/gait_charts.dart';
import 'package:silversole/shared/widgets/gait/gait_topic_sheet.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// The gait analysis tab, mascot theme.
///
/// Same approved layout as [GaitAnalysisPanel] — hero speed with its phase,
/// then "walking ability" and "walking stability" as separate questions, fall
/// records beside the stability group — in this theme's vocabulary: outlined
/// [MascotCard]s, gold for data and the ink/cream palette.
///
/// Draws whatever [snapshot] it is given: the bundled example ([gaitSnapshot]),
/// which opens with a banner that says so and cannot be dismissed, or the
/// wearer's own figures.
class GaitAnalysisPanelT2 extends StatelessWidget {
  const GaitAnalysisPanelT2({super.key, required this.snapshot});

  /// The "sample data" banner, for tests.
  static const sampleBannerKey = Key('gait-sample-banner-t2');

  /// The "still collecting" card, for tests.
  static const pendingKey = Key('gait-pending-t2');

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        if (snapshot.isSample) const _SampleBanner(),
        if (snapshot.isPending)
          _PendingCard(days: snapshot.pendingDays!)
        else ...[
          _Hero(snapshot: snapshot),

          _GroupLabel('gait_group_ability'.tr()),
          _SpeedChartCard(snapshot: snapshot),
          for (final metric in snapshot.ability) _MetricTile(metric: metric),

          _GroupLabel('gait_group_stability'.tr()),
          for (final metric in snapshot.stability) _MetricTile(metric: metric),
          if (snapshot.hasStanceChart)
            _Titled(
              title: 'gait_sect_lr_stance'.tr(),
              child: SizedBox(
                height: 170,
                child: GaitStanceChart(
                  left: snapshot.stanceLeft,
                  right: snapshot.stanceRight,
                  leftColor: AppPaletteT2.gold,
                  rightColor: AppPaletteT2.flame,
                ),
              ),
            ),
          if (snapshot.hasPhaseTimeline)
            _Titled(
              title: 'gait_sect_phase'.tr(),
              topic: GaitTopic.phase,
              child: GaitPhaseTimeline(
                spans: snapshot.phaseSpans,
                colorOf: _phaseColor,
              ),
            ),
          if (snapshot.hasSmallMultiples)
            _Titled(
              title: snapshot.smallMultiplesTitleKey.tr(),
              child: GaitSmallMultiples(
                lines: snapshot.smallMultiples,
                colorOf: _toneColor,
              ),
            ),
        ],

        _FallCard(snapshot: snapshot),
        if (snapshot.hasAdvice) _AdviceCard(keys: snapshot.adviceKeys),
        _NoteCard(textKey: snapshot.noteKey),
      ],
    );
  }
}

/// Says, above everything else, that the figures are an example: the app does
/// not measure gait yet.
class _SampleBanner extends StatelessWidget {
  const _SampleBanner();

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      key: GaitAnalysisPanelT2.sampleBannerKey,
      color: AppPaletteT2.cardWarm,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppPaletteT2.flame),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'gait_sample_banner'.tr(),
              style: context.textTheme.titleSmall?.copyWith(
                color: AppPaletteT2.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the figures while a scale has too few days behind it.
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      key: GaitAnalysisPanelT2.pendingKey,
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom, color: AppPaletteT2.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'gait_pending_days'.tr(args: ['$days']),
              style: context.textTheme.titleSmall,
            ),
          ),
        ],
      ),
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

    return _Titled(
      title: snapshot.chartLabelKey.tr(),
      topic: isWeek ? snapshot.heroTopic : GaitTopic.binning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: snapshot.hasPhaseTimeline ? 185 : 155,
            child: isWeek
                ? GaitSpeedBars(
                    values: snapshot.series,
                    step: snapshot.seriesStep,
                    color: AppPaletteT2.gold,
                  )
                : GaitTrendChart(
                    values: snapshot.series,
                    step: snapshot.seriesStep,
                    color: AppPaletteT2.ink,
                    openLast: true,
                    weekLabels: true,
                    showLeftAxis: snapshot.hasPhaseTimeline,
                    bands: [
                      for (final band in snapshot.phaseBands)
                        GaitChartBand(
                          fromX: band.from,
                          toX: band.to,
                          color: _phaseColor(
                            band.phase,
                          ).withValues(alpha: 0.16),
                        ),
                    ],
                    dotColorAt: snapshot.hasPhaseTimeline
                        ? (index) => _phaseColor(snapshot.phaseAt(index))
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
          if (!isWeek) ...[
            const SizedBox(height: 6),
            Text('gait_in_progress'.tr(), style: context.textTheme.bodySmall),
          ],
          if (reference != null)
            Text('gait_ref_band'.tr(), style: context.textTheme.bodySmall),
        ],
      ),
    );
  }
}

Color _toneColor(GaitTone tone) => switch (tone) {
  GaitTone.neutral => AppPaletteT2.inkMuted,
  GaitTone.good => AppPaletteT2.safe,
  GaitTone.warn => AppPaletteT2.flame,
  GaitTone.alert => AppPaletteT2.danger,
};

Color _phaseColor(GaitPhase phase) => switch (phase) {
  GaitPhase.stable => AppPaletteT2.safe,
  GaitPhase.declining => AppPaletteT2.flame,
  GaitPhase.alert => AppPaletteT2.danger,
};

/// This theme's section heading: the gold tab and a title.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 20,
            decoration: BoxDecoration(
              color: AppPaletteT2.gold,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppPaletteT2.ink, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: context.textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// A card with a heading row and an optional ⓘ.
class _Titled extends StatelessWidget {
  const _Titled({required this.title, required this.child, this.topic});

  final String title;
  final Widget child;
  final GaitTopic? topic;

  @override
  Widget build(BuildContext context) {
    final help = topic;
    return MascotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: context.textTheme.titleMedium),
              ),
              if (help != null) GaitTopicButton(topic: help),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.snapshot});

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;
    final delta = snapshot.heroDelta;
    final threshold = snapshot.thresholdNoteKey;

    return MascotCard(
      color: AppPaletteT2.cardWarm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phase != null) ...[
            Row(
              children: [
                MascotPill(
                  color: _phaseColor(phase),
                  child: Text(
                    phase.labelKey.tr(),
                    style: context.textTheme.labelLarge?.copyWith(
                      color: AppPaletteT2.card,
                    ),
                  ),
                ),
                GaitTopicButton(topic: GaitTopic.phase),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Flexible(
                child: Text(
                  snapshot.heroLabelKey.tr(),
                  style: context.textTheme.bodyLarge,
                ),
              ),
              GaitTopicButton(topic: snapshot.heroTopic),
              Text(
                'gait_live_daily'.tr(),
                style: context.textTheme.labelMedium,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                snapshot.heroValue,
                style: context.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppPaletteT2.ink,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                snapshot.heroUnitKey.tr(),
                style: context.textTheme.titleLarge,
              ),
            ],
          ),
          if (delta != null || threshold != null) ...[
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                if (delta != null)
                  Text(
                    '$delta ${snapshot.heroDeltaSuffixKey?.tr() ?? ''}',
                    style: context.textTheme.titleMedium.bold?.copyWith(
                      color: _toneColor(snapshot.heroTone),
                    ),
                  ),
                if (threshold != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(threshold.tr(), style: context.textTheme.bodyMedium),
                      GaitTopicButton(topic: GaitTopic.threshold),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final GaitMetric metric;

  @override
  Widget build(BuildContext context) {
    final tone = _toneColor(metric.tone);

    return MascotCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    if (metric.isAuxiliary)
                      MascotPill(
                        color: AppPaletteT2.canvas,
                        child: Text(
                          'gait_aux'.tr(),
                          style: context.textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
                Text(
                  metric.readingKey.tr(),
                  style: context.textTheme.bodyLarge,
                ),
                if (metric.subKey != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
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
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    metric.value,
                    style: context.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    metric.unitKey.tr(),
                    style: context.textTheme.labelLarge,
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

class _FallCard extends StatelessWidget {
  const _FallCard({required this.snapshot});

  final GaitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return MascotCard(
      child: Row(
        children: [
          Image.asset('assets/mascot-assets/icons/dev_foot.webp', height: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        snapshot.fallTitleKey.tr(),
                        style: context.textTheme.titleMedium,
                      ),
                    ),
                    GaitTopicButton(topic: GaitTopic.falls),
                  ],
                ),
                if (snapshot.fallLastKey case final last?)
                  Text(last.tr(), style: context.textTheme.bodyMedium),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${snapshot.fallCount}',
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppPaletteT2.danger,
                ),
              ),
              const SizedBox(width: 2),
              Text('gait_fall_unit'.tr(), style: context.textTheme.labelLarge),
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
    return _Titled(
      title: 'gait_advice_title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          for (final key in keys)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppPaletteT2.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppPaletteT2.ink, width: 1.2),
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.textKey});

  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(textKey.tr(), style: context.textTheme.bodyMedium),
    );
  }
}
