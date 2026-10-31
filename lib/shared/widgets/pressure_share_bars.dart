import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/pressure_shares.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/foot_pressure_heatmap.dart';

/// Where the weight sits on each foot on show, as two plain splits:
/// `Forefoot 38% ▓▓░░ 62% Heel` and `Medial 60% ▓▓▓░ 40% Lateral`.
///
/// Only measured numbers appear. A foot with no sole reads "no insole
/// connected", a connected one that is not loaded reads "stand on the insole",
/// and neither shows a percentage. There is no verdict anywhere — the bars say
/// where the weight is, not whether that is good.
class PressureShareBars extends StatelessWidget {
  const PressureShareBars({
    super.key,
    required this.feet,
    required this.right,
    required this.left,
    required this.rightConnected,
    required this.leftConnected,
  });

  final FootView feet;
  final PressureShares? right;
  final PressureShares? left;
  final bool rightConnected;
  final bool leftConnected;

  @override
  Widget build(BuildContext context) {
    final both = feet == FootView.both;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.base,
      children: [
        if (feet.showsLeft)
          _FootShares(
            title: both ? 'left_foot'.tr() : null,
            shares: left,
            connected: leftConnected,
          ),
        if (feet.showsRight)
          _FootShares(
            title: both ? 'right_foot'.tr() : null,
            shares: right,
            connected: rightConnected,
          ),
      ],
    );
  }
}

class _FootShares extends StatelessWidget {
  const _FootShares({
    required this.title,
    required this.shares,
    required this.connected,
  });

  final String? title;
  final PressureShares? shares;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final s = connected ? shares : null;
    final medial = s?.medialRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        if (title != null)
          Text(
            title!,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        if (s == null)
          _Hint(
            (connected ? 'pressure_share_stand' : 'pressure_share_no_sole')
                .tr(),
          )
        else ...[
          _SplitBar(
            leftLabel: 'forefoot'.tr(),
            rightLabel: 'pressure_share_heel'.tr(),
            leftRatio: s.foreRatio,
          ),
          if (medial != null)
            _SplitBar(
              leftLabel: 'foot_check_medial'.tr(),
              rightLabel: 'foot_check_lateral'.tr(),
              leftRatio: medial,
            )
          else
            _Hint('pressure_share_side_none'.tr()),
        ],
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// One measured split, named at both ends. Looks like the split bars on the
/// foot-check result page; kept as its own copy so that page stays untouched.
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
