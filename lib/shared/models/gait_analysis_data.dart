/// Data behind the gait-analysis tab, shared by both themes.
///
/// **Every figure here is mockup copy.** The app measures none of it: there is
/// no step detection, no speed model and no aggregation pipeline (see the
/// pipeline status in `CLAUDE.md`). The numbers follow the approved design so
/// the layout can be reviewed with realistic content, and they live in one
/// place so a real source replaces them without touching layout.
library;

/// Which window the gait tab is summarising.
///
/// Three scales rather than one page, because what can honestly be shown
/// depends on how much data is behind it: a week supports averages, a month
/// supports per-step variability, a quarter supports a trajectory.
enum GaitScale {
  week('range_week'),
  month('range_month'),
  quarter('range_quarter');

  const GaitScale(this.labelKey);

  /// Key in `strings.csv`.
  final String labelKey;
}

/// The trend stage shown as a pill on the hero card.
///
/// The staging rules have a statistical basis but the labels themselves are a
/// product decision, not a validated clinical classification — which is what
/// the [GaitTopic.phase] sheet says on screen.
enum GaitPhase {
  stable('gait_phase_stable'),
  declining('gait_phase_declining'),
  alert('gait_phase_alert');

  const GaitPhase(this.labelKey);

  /// Key in `strings.csv`.
  final String labelKey;
}

/// How a figure should read: a change can be neutral, an improvement, or worth
/// attention. Each theme maps these to its own colors.
enum GaitTone { neutral, good, warn, alert }

/// A metric or concept with an explanation sheet behind its ⓘ button.
///
/// Copy lives in `strings.csv` under `gait_help_<name>_*`: `body` says what the
/// number is, `note` adds the caveat a family member needs, and `evidence`
/// names the literature. [hasNote] / [hasEvidence] say which of those a topic
/// actually has.
enum GaitTopic {
  speed(hasNote: true, hasEvidence: true),
  cadence(hasEvidence: true),
  stability(hasNote: true, hasEvidence: true),
  doubleSupport(hasNote: true, hasEvidence: true),
  symmetry(hasNote: true, hasEvidence: true),
  threshold(hasNote: true, hasEvidence: true),
  phase(hasNote: true, hasEvidence: true),
  binning(hasNote: true),
  falls(hasNote: true, hasEvidence: true);

  const GaitTopic({this.hasNote = false, this.hasEvidence = false});

  final bool hasNote;
  final bool hasEvidence;

  String get titleKey => 'gait_help_${name}_title';
  String get bodyKey => 'gait_help_${name}_body';
  String get noteKey => 'gait_help_${name}_note';
  String get evidenceKey => 'gait_help_${name}_evidence';
}

/// One row in the "walking ability" or "walking stability" group.
class GaitMetric {
  const GaitMetric({
    required this.nameKey,
    required this.topic,
    required this.readingKey,
    required this.value,
    required this.unitKey,
    required this.delta,
    this.tone = GaitTone.neutral,
    this.subKey,
    this.subValue,
    this.subDelta,
    this.isAuxiliary = false,
  });

  /// Keys in `strings.csv`.
  final String nameKey;
  final String readingKey;
  final String unitKey;

  final GaitTopic topic;

  /// Already formatted, so the mock keeps the designed precision.
  final String value;
  final String delta;
  final GaitTone tone;

  /// Second line under the reading, e.g. per-step variation.
  final String? subKey;
  final String? subValue;
  final String? subDelta;

  /// Marked "supporting" on screen: watched but deliberately kept out of the
  /// staging decision because the evidence behind it is weaker.
  final bool isAuxiliary;
}

/// A span of the quarter timeline.
class GaitPhaseSpan {
  const GaitPhaseSpan({required this.phase, required this.weeks});

  final GaitPhase phase;

  /// How many weeks this phase lasted — the timeline's flex.
  final int weeks;
}

/// A small-multiples row on the quarter scale: one metric's twelve weeks.
class GaitTrendLine {
  const GaitTrendLine({
    required this.nameKey,
    required this.values,
    required this.tone,
  });

  /// Key in `strings.csv`.
  final String nameKey;

  final List<double> values;
  final GaitTone tone;
}

/// Everything one scale shows.
class GaitSnapshot {
  const GaitSnapshot({
    required this.scale,
    required this.phase,
    required this.heroLabelKey,
    required this.heroValue,
    required this.heroDelta,
    required this.heroDeltaSuffixKey,
    required this.heroTone,
    required this.thresholdNoteKey,
    required this.chartLabelKey,
    required this.speedSeries,
    required this.ability,
    required this.stability,
    required this.fallCount,
    required this.fallLastKey,
    required this.noteKey,
    this.stanceLeft = const [],
    this.stanceRight = const [],
    this.phaseSpans = const [],
    this.referenceSpeed,
    this.referenceUncertainty,
    this.smallMultiples = const [],
    this.adviceKeys = const [],
  });

  final GaitScale scale;
  final GaitPhase phase;

  /// Keys in `strings.csv`.
  final String heroLabelKey;
  final String thresholdNoteKey;
  final String chartLabelKey;
  final String fallLastKey;
  final String noteKey;

  /// Already formatted — the hero is the one figure read at a glance.
  final String heroValue;
  final String heroDelta;

  /// What the delta is measured against, e.g. "vs previous 7 days".
  final String heroDeltaSuffixKey;
  final GaitTone heroTone;

  /// Speed per bucket: days on the week scale, whole weeks after that.
  final List<double> speedSeries;

  final List<GaitMetric> ability;
  final List<GaitMetric> stability;

  final int fallCount;

  /// Left and right stance share per week — the month scale's second chart.
  final List<double> stanceLeft;
  final List<double> stanceRight;

  /// Quarter only: the phase timeline, four small trend lines, and what to do.
  final List<GaitPhaseSpan> phaseSpans;

  /// Clinical reference speed and the uncertainty around it, drawn as a band
  /// rather than a line — the speed is modelled rather than measured, so a hard
  /// line would put borderline cases on the wrong side of it.
  final double? referenceSpeed;
  final double? referenceUncertainty;
  final List<GaitTrendLine> smallMultiples;
  final List<String> adviceKeys;

  bool get hasStanceChart => stanceLeft.isNotEmpty;

  /// Which phase a bucket fell in, so each point on the trajectory can be
  /// colored by it.
  GaitPhase phaseAt(int bucket) {
    var week = 0;
    for (final span in phaseSpans) {
      week += span.weeks;
      if (bucket < week) return span.phase;
    }
    return phaseSpans.isEmpty ? phase : phaseSpans.last.phase;
  }

  /// The phases as x ranges for the trajectory chart: each covers its own
  /// weeks, with the edge halfway between the weeks on either side so the
  /// tints meet without overlapping.
  List<({double from, double to, GaitPhase phase})> get phaseBands {
    final bands = <({double from, double to, GaitPhase phase})>[];
    var week = 0;
    for (var i = 0; i < phaseSpans.length; i++) {
      final from = i == 0 ? 0.0 : week - 0.5;
      week += phaseSpans[i].weeks;
      final last = i == phaseSpans.length - 1;
      bands.add((
        from: from,
        to: last ? (week - 1).toDouble() : week - 0.5,
        phase: phaseSpans[i].phase,
      ));
    }
    return bands;
  }

  bool get hasPhaseTimeline => phaseSpans.isNotEmpty;
  bool get hasSmallMultiples => smallMultiples.isNotEmpty;
  bool get hasAdvice => adviceKeys.isNotEmpty;
}

const _cadence = GaitMetric(
  nameKey: 'gait_metric_cadence',
  topic: GaitTopic.cadence,
  readingKey: 'gait_reading_cadence_flat',
  value: '104',
  unitKey: 'gait_unit_spm',
  delta: '−1',
);

/// The mock snapshot for [scale].
GaitSnapshot gaitSnapshot(GaitScale scale) => switch (scale) {
  GaitScale.week => const GaitSnapshot(
    scale: GaitScale.week,
    phase: GaitPhase.stable,
    heroLabelKey: 'gait_hero_speed_week',
    heroValue: '0.88',
    heroDelta: '−0.02',
    heroDeltaSuffixKey: 'gait_delta_vs_week',
    heroTone: GaitTone.neutral,
    thresholdNoteKey: 'gait_threshold_under',
    chartLabelKey: 'gait_sect_daily_speed',
    speedSeries: [0.86, 0.90, 0.87, 0.89, 0.85, 0.91, 0.88],
    ability: [_cadence],
    stability: [
      GaitMetric(
        nameKey: 'gait_metric_double_support',
        topic: GaitTopic.doubleSupport,
        readingKey: 'gait_reading_ds_week',
        value: '28.4',
        unitKey: 'gait_unit_percent',
        delta: '+0.6',
        tone: GaitTone.warn,
        subKey: 'gait_sub_flutter',
        subValue: '6.8%',
        subDelta: '+0.4',
      ),
      GaitMetric(
        nameKey: 'gait_metric_symmetry',
        topic: GaitTopic.symmetry,
        readingKey: 'gait_reading_sym_week',
        value: '92',
        unitKey: 'gait_unit_percent',
        delta: '−1.2',
        tone: GaitTone.warn,
        isAuxiliary: true,
      ),
    ],
    fallCount: 1,
    fallLastKey: 'gait_fall_last',
    noteKey: 'gait_note_week',
  ),
  GaitScale.month => const GaitSnapshot(
    scale: GaitScale.month,
    phase: GaitPhase.declining,
    heroLabelKey: 'gait_hero_speed_month',
    heroValue: '0.91',
    heroDelta: '−0.05',
    heroDeltaSuffixKey: 'gait_delta_vs_month',
    heroTone: GaitTone.warn,
    thresholdNoteKey: 'gait_threshold_over',
    chartLabelKey: 'gait_sect_four_weeks',
    speedSeries: [0.96, 0.94, 0.93, 0.91],
    ability: [_cadence],
    stability: [
      GaitMetric(
        nameKey: 'gait_metric_stability',
        topic: GaitTopic.stability,
        readingKey: 'gait_reading_cv_month',
        value: '95.8',
        unitKey: 'score_unit',
        delta: '−0.8',
        tone: GaitTone.warn,
      ),
      GaitMetric(
        nameKey: 'gait_metric_double_support',
        topic: GaitTopic.doubleSupport,
        readingKey: 'gait_reading_ds_month',
        value: '26.8',
        unitKey: 'gait_unit_percent',
        delta: '+1.6',
        tone: GaitTone.warn,
        subKey: 'gait_sub_flutter',
        subValue: '6.6%',
        subDelta: '+1.1',
      ),
      GaitMetric(
        nameKey: 'gait_metric_symmetry',
        topic: GaitTopic.symmetry,
        readingKey: 'gait_reading_sym_month',
        value: '94.5',
        unitKey: 'gait_unit_percent',
        delta: '−1.7',
        tone: GaitTone.warn,
        isAuxiliary: true,
      ),
    ],
    fallCount: 1,
    fallLastKey: 'gait_fall_last',
    noteKey: 'gait_note_month',
    stanceLeft: [51, 52, 53, 54],
    stanceRight: [49, 48, 47, 46],
  ),
  GaitScale.quarter => const GaitSnapshot(
    scale: GaitScale.quarter,
    phase: GaitPhase.alert,
    heroLabelKey: 'gait_hero_speed_quarter',
    heroValue: '0.88',
    heroDelta: '−0.14',
    heroDeltaSuffixKey: 'gait_delta_vs_quarter',
    heroTone: GaitTone.alert,
    thresholdNoteKey: 'gait_threshold_rate',
    chartLabelKey: 'gait_sect_twelve_weeks',
    speedSeries: [
      1.02,
      1.01,
      1.00,
      0.99,
      0.98,
      0.97,
      0.96,
      0.94,
      0.93,
      0.91,
      0.90,
      0.88,
    ],
    ability: [_cadence],
    stability: [],
    fallCount: 1,
    fallLastKey: 'gait_fall_last_quarter',
    noteKey: 'gait_note_quarter',
    referenceSpeed: 0.80,
    referenceUncertainty: 0.10,
    phaseSpans: [
      GaitPhaseSpan(phase: GaitPhase.stable, weeks: 4),
      GaitPhaseSpan(phase: GaitPhase.declining, weeks: 5),
      GaitPhaseSpan(phase: GaitPhase.alert, weeks: 3),
    ],
    smallMultiples: [
      GaitTrendLine(
        nameKey: 'gait_metric_speed',
        values: [1.02, 1.00, 0.98, 0.96, 0.93, 0.90, 0.88],
        tone: GaitTone.alert,
      ),
      GaitTrendLine(
        nameKey: 'gait_metric_stability',
        values: [97.4, 97.0, 96.6, 96.3, 96.0, 95.9, 95.8],
        tone: GaitTone.warn,
      ),
      GaitTrendLine(
        nameKey: 'gait_metric_double_support',
        values: [24.1, 24.8, 25.4, 25.9, 26.3, 26.6, 26.8],
        tone: GaitTone.warn,
      ),
      GaitTrendLine(
        nameKey: 'gait_metric_symmetry',
        values: [97.8, 97.1, 96.4, 95.8, 95.2, 94.8, 94.5],
        tone: GaitTone.warn,
      ),
    ],
    adviceKeys: [
      'gait_advice_assessment',
      'gait_advice_home',
      'gait_advice_pain',
    ],
  ),
};
