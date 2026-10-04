import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/shared/models/gait_analysis_data.dart';

Set<String> _csvKeys() => File('assets/translations/strings.csv')
    .readAsLinesSync()
    .where((line) => line.isNotEmpty)
    .map((line) => line.split(',').first)
    .toSet();

/// Every `'some_key'.tr()` written as a literal in the gait widgets. Catches a
/// string that was used but never added — which shows up on screen as the raw
/// key rather than as a crash.
Set<String> _literalKeysInGaitWidgets() {
  final pattern = RegExp(r"'([a-z0-9_]+)'\.tr\(");
  return {
    for (final path in const [
      'lib/shared/widgets/gait/gait_panel.dart',
      'lib/shared/widgets/gait/gait_panel_t2.dart',
      'lib/shared/widgets/gait/gait_charts.dart',
      'lib/shared/widgets/gait/gait_topic_sheet.dart',
    ])
      for (final match in pattern.allMatches(File(path).readAsStringSync()))
        match.group(1)!,
  };
}

/// Every key the snapshots hand to the widgets.
Set<String> _keysFromData() {
  final keys = <String>{};
  for (final topic in GaitTopic.values) {
    keys.addAll([topic.titleKey, topic.bodyKey]);
    if (topic.hasNote) keys.add(topic.noteKey);
    if (topic.hasEvidence) keys.add(topic.evidenceKey);
  }
  for (final phase in GaitPhase.values) {
    keys.add(phase.labelKey);
  }
  for (final scale in GaitScale.values) {
    keys.add(scale.labelKey);
    final snapshot = gaitSnapshot(scale);
    keys.addAll([
      snapshot.heroLabelKey,
      snapshot.heroDeltaSuffixKey,
      snapshot.thresholdNoteKey,
      snapshot.chartLabelKey,
      snapshot.fallLastKey,
      snapshot.noteKey,
      ...snapshot.adviceKeys,
      ...snapshot.smallMultiples.map((line) => line.nameKey),
      for (final metric in [...snapshot.ability, ...snapshot.stability]) ...[
        metric.nameKey,
        metric.readingKey,
        metric.unitKey,
        if (metric.subKey != null) metric.subKey!,
      ],
    ]);
  }
  return keys;
}

void main() {
  test('every gait string the widgets ask for is in strings.csv', () {
    expect(_literalKeysInGaitWidgets().difference(_csvKeys()), isEmpty);
  });

  test('every gait string the data hands over is in strings.csv', () {
    expect(_keysFromData().difference(_csvKeys()), isEmpty);
  });

  test('each scale shows only what that much data supports', () {
    final week = gaitSnapshot(GaitScale.week);
    final month = gaitSnapshot(GaitScale.month);
    final quarter = gaitSnapshot(GaitScale.quarter);

    // A week of data carries averages but not per-step variability.
    expect(week.speedSeries, hasLength(7));
    expect(
      week.stability.map((m) => m.nameKey),
      isNot(contains('gait_metric_stability')),
    );
    expect(week.hasStanceChart, isFalse);
    expect(week.hasAdvice, isFalse);

    // A month adds step stability and the left/right comparison.
    expect(month.speedSeries, hasLength(4));
    expect(
      month.stability.map((m) => m.nameKey),
      contains('gait_metric_stability'),
    );
    expect(month.hasStanceChart, isTrue);
    expect(month.stanceLeft, hasLength(month.stanceRight.length));

    // A quarter is where a trajectory and a recommendation become honest.
    expect(quarter.speedSeries, hasLength(12));
    expect(quarter.hasPhaseTimeline, isTrue);
    expect(quarter.hasSmallMultiples, isTrue);
    expect(quarter.hasAdvice, isTrue);
  });

  test('the phase timeline covers the whole quarter', () {
    final spans = gaitSnapshot(GaitScale.quarter).phaseSpans;
    final weeks = spans.fold(0, (sum, span) => sum + span.weeks);
    expect(weeks, 12);
  });

  test('every week of the quarter belongs to a phase', () {
    // W1-W4 stable, W5-W9 declining, W10-W12 watch: the trajectory colors its
    // points by this, so the chart shows the split instead of hiding it.
    final quarter = gaitSnapshot(GaitScale.quarter);
    const expected = [
      ...[
        GaitPhase.stable,
        GaitPhase.stable,
        GaitPhase.stable,
        GaitPhase.stable,
      ],
      ...[
        GaitPhase.declining,
        GaitPhase.declining,
        GaitPhase.declining,
        GaitPhase.declining,
        GaitPhase.declining,
      ],
      ...[GaitPhase.alert, GaitPhase.alert, GaitPhase.alert],
    ];
    expect([
      for (var week = 0; week < quarter.speedSeries.length; week++)
        quarter.phaseAt(week),
    ], expected);
  });

  test('the phase tints meet without gaps and span the whole plot', () {
    final bands = gaitSnapshot(GaitScale.quarter).phaseBands;
    expect(bands, hasLength(3));
    expect(bands.first.from, 0);
    expect(bands.last.to, 11, reason: 'the last bucket is the last point');
    for (var i = 1; i < bands.length; i++) {
      expect(
        bands[i].from,
        bands[i - 1].to,
        reason: 'a gap would leave an unpainted stripe between phases',
      );
    }
    expect(bands[0].to, 3.5, reason: 'halfway between W4 and W5');
    expect(bands[1].to, 8.5, reason: 'halfway between W9 and W10');
  });

  test('only the quarter carries the clinical reference band', () {
    expect(gaitSnapshot(GaitScale.quarter).referenceSpeed, 0.80);
    expect(gaitSnapshot(GaitScale.quarter).referenceUncertainty, 0.10);
    expect(gaitSnapshot(GaitScale.week).referenceSpeed, isNull);
    expect(gaitSnapshot(GaitScale.month).referenceSpeed, isNull);
  });

  test('left-right balance stays a supporting observation on every scale', () {
    // It is deliberately kept out of the staging decision, so the UI has to
    // keep flagging it as auxiliary.
    for (final scale in GaitScale.values) {
      final symmetry = gaitSnapshot(
        scale,
      ).stability.where((m) => m.nameKey == 'gait_metric_symmetry');
      for (final metric in symmetry) {
        expect(metric.isAuxiliary, isTrue, reason: scale.name);
      }
    }
  });
}
