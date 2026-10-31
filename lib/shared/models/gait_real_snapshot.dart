import 'package:silversole/core/gait/daily_gait.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';

/// Days with data inside a scale's window before it shows figures (design
/// §5.2): a week needs one, four weeks need seven, twelve weeks need 28.
int gaitDaysNeeded(GaitScale scale) => switch (scale) {
  GaitScale.week => 1,
  GaitScale.month => 7,
  GaitScale.quarter => 28,
};

/// One bucket of days: their sum, how many had data, and those days
/// themselves (needed to average per-day variation).
typedef _Bucket = ({DailyGait total, int days, List<DailyGait> list});

/// The gait tab for [scale], from the wearer's own [history].
///
/// No phase, no reference speed, no advice and no deltas: those need months
/// of a personal baseline (design §5.3). Until the window holds
/// [gaitDaysNeeded] days with data the snapshot is a "still collecting" one
/// and carries no figures at all.
GaitSnapshot realGaitSnapshot({
  required GaitScale scale,
  required Map<String, DailyGait> history,
  required DateTime today,
  required int fallCount,
}) {
  final buckets = switch (scale) {
    GaitScale.week => _buckets(history, today, count: 7, days: 1),
    GaitScale.month => _buckets(history, today, count: 4, days: 7),
    GaitScale.quarter => _buckets(history, today, count: 12, days: 7),
  };
  final daysWithData = buckets.fold(0, (n, b) => n + b.days);
  final need = gaitDaysNeeded(scale);

  if (daysWithData < need) {
    return GaitSnapshot(
      scale: scale,
      isSample: false,
      pendingDays: need - daysWithData,
      heroLabelKey: '',
      heroValue: '',
      chartLabelKey: '',
      series: const [],
      ability: const [],
      stability: const [],
      fallCount: fallCount,
      fallTitleKey: _fallTitleKey,
      noteKey: _noteKey,
    );
  }

  var window = const DailyGait(date: '');
  for (final b in buckets) {
    window = window.merge(b.total);
  }
  final windowCv = _meanStrideCv([for (final b in buckets) ...b.list]);
  // A stored day can parse and still be corrupt, which turns a ratio into
  // NaN or infinity; such a figure is left out rather than drawn.
  final cadence = _finite(window.cadence);
  final stance = _finite(window.stanceRatio);
  final symmetry = _finite(window.symmetry);
  final doubleSupport = _finite(window.doubleSupportRatio);

  return GaitSnapshot(
    scale: scale,
    isSample: false,
    heroLabelKey: switch (scale) {
      GaitScale.week => 'gait_hero_steps_week',
      GaitScale.month => 'gait_hero_steps_month',
      GaitScale.quarter => 'gait_hero_steps_quarter',
    },
    heroValue: (window.steps / daysWithData).round().toString(),
    heroUnitKey: 'gait_unit_steps',
    heroTopic: GaitTopic.steps,
    chartLabelKey: switch (scale) {
      GaitScale.week => 'gait_sect_daily_steps',
      GaitScale.month => 'gait_sect_four_weeks',
      GaitScale.quarter => 'gait_sect_twelve_weeks',
    },
    series: [for (final b in _charted(scale, buckets)) _dailySteps(b) ?? 0],
    seriesStep: 100,
    ability: [
      if (cadence != null)
        _metric(
          'gait_metric_cadence',
          GaitTopic.cadence,
          'gait_reading_cadence_real',
          cadence.round().toString(),
          'gait_unit_spm',
        ),
      _metric(
        'gait_metric_walk_minutes',
        GaitTopic.steps,
        'gait_reading_walk_minutes',
        (window.walkingMs / 60000 / daysWithData).round().toString(),
        'gait_unit_min',
      ),
      if (stance != null)
        _metric(
          'gait_metric_stance',
          GaitTopic.stance,
          'gait_reading_stance_real',
          (stance * 100).round().toString(),
          'gait_unit_percent',
        ),
    ],
    stability: [
      if (windowCv case final cv?)
        _metric(
          'gait_metric_stride_cv',
          GaitTopic.variation,
          'gait_reading_stride_cv',
          (cv * 100).toStringAsFixed(1),
          'gait_unit_percent',
        ),
      if (symmetry != null)
        _metric(
          'gait_metric_symmetry',
          GaitTopic.symmetry,
          'gait_reading_sym_real',
          (symmetry * 100).round().toString(),
          'gait_unit_percent',
        ),
      if (doubleSupport != null)
        _metric(
          'gait_metric_double_support',
          GaitTopic.doubleSupport,
          'gait_reading_ds_real',
          (doubleSupport * 100).toStringAsFixed(1),
          'gait_unit_percent',
        ),
    ],
    fallCount: fallCount,
    fallTitleKey: _fallTitleKey,
    noteKey: _noteKey,
    smallMultiplesTitleKey: 'gait_sect_weekly_metrics',
    smallMultiples: scale != GaitScale.quarter
        ? const []
        : [
            for (final line in [
              _line('gait_metric_daily_steps', buckets, _dailySteps),
              _line('gait_metric_cadence', buckets, (b) => b.total.cadence),
              _line(
                'gait_metric_stride_cv',
                buckets,
                (b) => _percent(_meanStrideCv(b.list)),
              ),
              _line(
                'gait_metric_symmetry',
                buckets,
                (b) => _percent(b.total.symmetry),
              ),
            ])
              ?line,
          ],
  );
}

/// The buckets to draw as the step chart. Weeks and months start at the first
/// bucket with data, so a new wearer's line does not climb from zero; the
/// last bucket always stays. Days of the week keep every bar.
List<_Bucket> _charted(GaitScale scale, List<_Bucket> buckets) {
  if (scale == GaitScale.week) return buckets;
  final first = buckets.indexWhere((b) => b.days > 0);
  return buckets.sublist(first < 0 ? buckets.length - 1 : first);
}

const _fallTitleKey = 'gait_fall_title_since_open';
const _noteKey = 'gait_note_real';

/// [count] buckets of [days] days each, oldest first, the last one ending
/// today.
List<_Bucket> _buckets(
  Map<String, DailyGait> history,
  DateTime today, {
  required int count,
  required int days,
}) => [
  for (var b = count - 1; b >= 0; b--)
    _bucket(history, today, endsDaysAgo: b * days, days: days),
];

_Bucket _bucket(
  Map<String, DailyGait> history,
  DateTime today, {
  required int endsDaysAgo,
  required int days,
}) {
  var total = const DailyGait(date: '');
  var withData = 0;
  final list = <DailyGait>[];
  for (var i = 0; i < days; i++) {
    final day =
        history[gaitDateKey(
          DateTime(today.year, today.month, today.day - endsDaysAgo - i),
        )];
    if (day == null || !day.hasData) continue;
    total = total.merge(day);
    withData++;
    list.add(day);
  }
  return (total: total, days: withData, list: list);
}

/// Stride variation over [days]: each day's own variation, weighted by its
/// strides. Pooling the strides would count a slow day next to a fast one as
/// irregular walking, when it is only a different pace. Days too short to
/// have a variation are skipped; null when none has one.
double? _meanStrideCv(List<DailyGait> days) {
  var weighted = 0.0;
  var strides = 0;
  for (final day in days) {
    final cv = _finite(day.strideCv);
    if (cv == null) continue;
    weighted += cv * day.strides;
    strides += day.strides;
  }
  return strides == 0 ? null : _finite(weighted / strides);
}

/// [v] unless it is null, NaN or infinite.
double? _finite(double? v) => v != null && v.isFinite ? v : null;

/// Average daily steps over the days in [b] that have data.
double? _dailySteps(_Bucket b) => b.days == 0 ? null : b.total.steps / b.days;

double? _percent(double? fraction) {
  final f = _finite(fraction);
  return f == null ? null : f * 100;
}

/// A weekly line over the buckets that have data, or null with fewer than
/// two points to draw.
GaitTrendLine? _line(
  String nameKey,
  List<_Bucket> buckets,
  double? Function(_Bucket b) valueOf,
) {
  final values = <double>[
    for (final b in buckets)
      if (b.days > 0) ?_finite(valueOf(b)),
  ];
  if (values.length < 2) return null;
  return GaitTrendLine(
    nameKey: nameKey,
    values: values,
    tone: GaitTone.neutral,
  );
}

GaitMetric _metric(
  String nameKey,
  GaitTopic topic,
  String readingKey,
  String value,
  String unitKey,
) => GaitMetric(
  nameKey: nameKey,
  topic: topic,
  readingKey: readingKey,
  value: value,
  unitKey: unitKey,
  delta: '',
);
