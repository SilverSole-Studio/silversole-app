import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/gait/mobility_grade.dart';
import 'package:silversole/core/report/activity_report.dart';
import 'package:silversole/core/theme/theme.dart';

/// Light theme the record is always drawn in: it is a picture that gets
/// printed or read in a chat, so it does not follow the app's dark mode or
/// either theme variant.
final ThemeData _reportTheme = appTheme(Brightness.light);

const _ink = Color(0xFF1F2933);
const _muted = Color(0xFF616E7C);
const _line = Color(0xFFD9DEE3);
const _track = Color(0xFFE4E9EE);

/// The shared activity record, as the one picture that gets shared.
///
/// Fixed [width] and always light, whatever the screen and the text-size
/// setting are, so the picture comes out the same on every phone. It shows only
/// the sections in [shown] that [report] has data for, and the [nickname] only
/// when it is not blank. It states what was recorded and makes no judgement.
class ActivityReportCard extends StatelessWidget {
  const ActivityReportCard({
    super.key,
    required this.report,
    required this.shown,
    this.nickname = '',
  });

  /// Logical width; the shared picture is this wide times the pixel ratio.
  static const double width = 360;

  /// Marks the nickname line, which exists only when a name was typed.
  static const nicknameKey = Key('report-nickname');

  /// Marks every grade letter square, for tests.
  static const gradeBoxKey = Key('report-grade-box');

  /// Marks the line that stands in for the inner/outer split when the
  /// forefoot carried too little load.
  static const noMedialKey = Key('report-no-medial');

  final ActivityReport report;

  /// Sections the wearer left ticked.
  final Set<ReportSection> shown;

  final String nickname;

  bool _show(ReportSection section) =>
      shown.contains(section) && report.sections.contains(section);

  @override
  Widget build(BuildContext context) {
    final name = nickname.trim();
    return Theme(
      data: _reportTheme,
      // The picture must not grow with the wearer's text-size setting.
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: SizedBox(
          width: width,
          child: Material(
            color: Colors.white,
            textStyle: const TextStyle(color: _ink, fontSize: 14, height: 1.4),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Header(report: report, name: name),
                  if (_show(ReportSection.footCheck))
                    _FootCheckBlock(section: report.footCheck!),
                  if (_show(ReportSection.games))
                    _GamesBlock(section: report.games!),
                  if (_show(ReportSection.gait))
                    _GaitBlock(section: report.gait!),
                  if (_show(ReportSection.mobility))
                    _MobilityBlock(section: report.mobility!),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'report_footer'.tr(),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'report_app_name'.tr(),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _shortDate(DateTime d) => '${d.month}/${d.day}';
String _fullDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

class _Header extends StatelessWidget {
  const _Header({required this.report, required this.name});

  final ActivityReport report;
  final String name;

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(color: _muted, fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Text(
          'report_title'.tr(),
          style: const TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (name.isNotEmpty)
          Text(
            'report_nickname_line'.tr(args: [name]),
            key: ActivityReportCard.nicknameKey,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(
          'report_period'.tr(
            args: [
              _shortDate(report.periodStart),
              _shortDate(report.generatedOn),
            ],
          ),
          style: small,
        ),
        Text(
          'report_made_on'.tr(args: [_fullDate(report.generatedOn)]),
          style: small,
        ),
      ],
    );
  }
}

/// A titled block with a rule above it.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: _line),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpacing.md),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Foot check ────────────────────────────────────────────────────────────

class _FootCheckBlock extends StatelessWidget {
  const _FootCheckBlock({required this.section});

  final FootCheckSection section;

  @override
  Widget build(BuildContext context) {
    return _Block(
      title: 'report_section_foot_check'.tr(),
      children: [
        Text(
          'report_foot_last_check'.tr(args: [_fullDate(section.takenAt)]),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.xs),
        _LabelValue('report_foot_result'.tr(), section.rating.labelKey.tr()),
        if (section.hasRatios) ...[
          const SizedBox(height: AppSpacing.sm),
          _SplitRow(
            leftLabel: 'foot_check_forefoot'.tr(),
            rightLabel: 'foot_check_rearfoot'.tr(),
            leftPercent: section.forePercent!,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (section.hasMedial)
            _SplitRow(
              leftLabel: 'foot_check_medial'.tr(),
              rightLabel: 'foot_check_lateral'.tr(),
              leftPercent: section.medialPercent!,
            )
          else
            Text(
              'report_foot_no_medial'.tr(),
              key: ActivityReportCard.noMedialKey,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
        ],
      ],
    );
  }
}

/// `Forefoot 38% ▓▓▓░░░ 62% Rearfoot`, the same split the check result shows.
class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftPercent,
  });

  final String leftLabel;
  final String rightLabel;
  final int leftPercent;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    return Row(
      spacing: AppSpacing.sm,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            '$leftLabel $leftPercent%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: AppRadius.subR,
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: math.max(leftPercent, 0),
                    child: ColoredBox(color: _reportTheme.colorScheme.primary),
                  ),
                  Expanded(
                    flex: math.max(100 - leftPercent, 0),
                    child: const ColoredBox(color: _track),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            '${100 - leftPercent}% $rightLabel',
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

// ── Games ─────────────────────────────────────────────────────────────────

class _GamesBlock extends StatelessWidget {
  const _GamesBlock({required this.section});

  final GameSection section;

  @override
  Widget build(BuildContext context) {
    return _Block(
      title: 'report_section_games'.tr(),
      children: [
        Text(
          'report_games_summary'.tr(
            args: ['${section.activeDays}', '${section.totalMinutes}'],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final game in section.games)
          _LabelValue(
            game.slug == null
                ? 'report_game_other'.tr()
                : 'report_game_${game.slug}'.tr(),
            'report_times'.tr(args: ['${game.rounds}']),
          ),
      ],
    );
  }
}

// ── Gait ──────────────────────────────────────────────────────────────────

class _GaitBlock extends StatelessWidget {
  const _GaitBlock({required this.section});

  final GaitSection section;

  @override
  Widget build(BuildContext context) {
    final cadence = section.averageCadence;
    final minutes = section.averageWalkingMinutes;
    return _Block(
      title: 'report_section_gait'.tr(),
      children: [
        Text(
          'report_gait_steps'.tr(),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StepBars(days: section.days),
        const SizedBox(height: AppSpacing.md),
        if (cadence != null)
          _LabelValue(
            'gait_metric_cadence'.tr(),
            'report_gait_cadence_value'.tr(args: [cadence.round().toString()]),
          ),
        if (minutes != null)
          _LabelValue(
            'gait_metric_walk_minutes'.tr(),
            'report_gait_minutes_value'.tr(args: ['$minutes']),
          ),
      ],
    );
  }
}

/// One small bar per day with its step count above and its date below.
class _StepBars extends StatelessWidget {
  const _StepBars({required this.days});

  final List<GaitDayBar> days;

  static const _barArea = 64.0;

  @override
  Widget build(BuildContext context) {
    final most = days.fold(0, (m, d) => math.max(m, d.steps));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: AppSpacing.xs,
      children: [
        for (final day in days)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day.steps == 0 ? '' : '${day.steps}',
                  maxLines: 1,
                  style: const TextStyle(fontSize: 9, color: _muted),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: _barArea,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: day.steps == 0
                          ? 2
                          : math.max(3.0, _barArea * day.steps / most),
                      decoration: BoxDecoration(
                        color: day.steps == 0
                            ? _track
                            : _reportTheme.colorScheme.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _shortDate(day.day),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Mobility ──────────────────────────────────────────────────────────────

class _MobilityBlock extends StatelessWidget {
  const _MobilityBlock({required this.section});

  final MobilitySection section;

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
    final changes = [
      for (final c in section.changes)
        'mobility_change_${c.metric.name}_${c.better ? 'up' : 'down'}'.tr(),
    ];
    final weekLabel = section.isCurrentWeek
        ? 'mobility_week_current'.tr()
        : 'mobility_week_of'.tr(
            args: ['${section.weekStart.month}/${section.weekStart.day}'],
          );
    return _Block(
      title: 'mobility_title'.tr(),
      children: [
        Text(weekLabel, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          spacing: AppSpacing.md,
          children: [
            _GradeBox(grade: section.grade, size: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    'mobility_grade_${section.grade.name}'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (changes.isNotEmpty)
                    Text(
                      (section.isCurrentWeek
                              ? 'mobility_mainly'
                              : 'mobility_mainly_past')
                          .tr(args: [changes.join('mobility_joiner'.tr())]),
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final row in section.metrics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(child: Text(_nameKeys[row.metric]!.tr())),
                _GradeBox(grade: row.grade, size: 24),
              ],
            ),
          ),
      ],
    );
  }
}

/// A rounded square with the grade's letter in it.
class _GradeBox extends StatelessWidget {
  const _GradeBox({required this.grade, required this.size});

  final MobilityGrade grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    // One neutral fill for every grade: the letter says which, and the record
    // makes no judgement by colour.
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerHighest;
    return Container(
      key: ActivityReportCard.gradeBoxKey,
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
          color: scheme.onSurface,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
