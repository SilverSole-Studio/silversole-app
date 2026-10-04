import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/foot_check_rating.dart';
import 'package:silversole/core/utils/foot_load_balance.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// The report a one-minute foot check ends on.
///
/// Everything shown is measured: the band comes from how balanced the load was
/// (see [FootLoadBalance.rating]) and the two sentences name what was actually
/// found. A check that collected too little says so instead of guessing.
///
/// Reached by replacing the session page, so its one way out lands back on the
/// home screen.
class FootCheckResultPage extends StatelessWidget {
  const FootCheckResultPage({super.key, required this.report});

  /// Marks the three-segment indicator for tests, which would otherwise have to
  /// tell it apart from the two distribution bars.
  static const gradeKey = Key('foot-check-grade');

  final FootCheckReport report;

  @override
  Widget build(BuildContext context) {
    final balance = report.balance;

    return Scaffold(
      appBar: AppBar(
        // The action on the right is the only way out, so no back arrow.
        automaticallyImplyLeading: false,
        title: Text(
          'foot_check_result_title'.tr(),
          style: context.textTheme.titleLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('foot_check_finish'.tr()),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: balance == null
              ? const _NotEnoughData()
              : _Findings(balance: balance, report: report),
        ),
      ),
    );
  }
}

class _Findings extends StatelessWidget {
  const _Findings({required this.balance, required this.report});

  final FootLoadBalance balance;
  final FootCheckReport report;

  @override
  Widget build(BuildContext context) {
    final rating = balance.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('foot_check_result_grade'.tr()),
        const SizedBox(height: AppSpacing.md),
        // Three separate segments, same shape as the fall-risk indicator: the
        // band is the score, so there is no number to show.
        Row(
          spacing: AppSpacing.base,
          children: [
            Expanded(
              child: _GradeSegments(
                key: FootCheckResultPage.gradeKey,
                level: rating.level,
              ),
            ),
            Text(
              rating.labelKey.tr(),
              style: context.textTheme.titleLarge.bold?.copyWith(
                color: context.tokens.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        _SectionLabel('foot_check_load_section'.tr()),
        const SizedBox(height: AppSpacing.md),
        _SplitBar(
          leftLabel: 'foot_check_forefoot'.tr(),
          rightLabel: 'foot_check_rearfoot'.tr(),
          leftRatio: balance.foreRatio,
        ),
        const SizedBox(height: AppSpacing.base),
        _SplitBar(
          leftLabel: 'foot_check_medial'.tr(),
          rightLabel: 'foot_check_lateral'.tr(),
          leftRatio: balance.medialRatio,
        ),
        const SizedBox(height: AppSpacing.xxl),
        // One finding per axis, in the order the bars above them appear.
        Card(
          elevation: 0,
          color: context.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                Text(
                  balance.foreAft.summaryKey.tr(),
                  style: context.textTheme.bodyLarge,
                ),
                Text(
                  balance.side.summaryKey.tr(),
                  style: context.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.titleMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// [level] of three segments filled, each its own bar.
class _GradeSegments extends StatelessWidget {
  const _GradeSegments({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.sm,
      children: [
        for (
          var segment = 1;
          segment <= FootCheckRating.values.length;
          segment++
        )
          Expanded(
            child: SizedBox(
              height: 14,
              child: LinearProgressIndicator(
                value: segment <= level ? 1 : 0,
                year2023: false, // ignore: deprecated_member_use
                borderRadius: AppRadius.subR,
                stopIndicatorRadius: 0,
                trackGap: 0,
                color: context.tokens.success,
              ),
            ),
          ),
      ],
    );
  }
}

/// One measured split, named at both ends: `Forefoot 38% ▓▓▓░░░ 62% Rearfoot`.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftRatio,
  });

  final String leftLabel;
  final String rightLabel;
  final double leftRatio;

  @override
  Widget build(BuildContext context) {
    // Rounded once and subtracted, so the two ends always add up to 100.
    final left = (leftRatio * 100).round();

    return Row(
      spacing: AppSpacing.md,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            '$leftLabel $left%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleSmall,
          ),
        ),
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 12,
            child: LinearProgressIndicator(
              value: leftRatio,
              year2023: false, // ignore: deprecated_member_use
              borderRadius: AppRadius.subR,
              stopIndicatorRadius: 0,
              trackGap: 0,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            '${100 - left}% $rightLabel',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

/// Shown when the check never saw enough load to judge anything — honest about
/// it rather than filling the panel with numbers it does not have.
class _NotEnoughData extends StatelessWidget {
  const _NotEnoughData();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.base,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            child: Icon(
              LucideIcons.footprints,
              size: 28,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'foot_check_no_data_title'.tr(),
            style: context.textTheme.titleLarge,
          ),
          Text(
            'foot_check_no_data_body'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
