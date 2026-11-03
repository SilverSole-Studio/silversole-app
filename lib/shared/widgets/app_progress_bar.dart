import 'package:flutter/material.dart';
import 'package:silversole/core/theme/theme.dart';
import 'package:silversole/core/utils/useful_extension.dart';
import 'package:silversole/shared/widgets/theme_two/mascot_card.dart';

/// A horizontal progress bar in the active theme's language: the mascot theme
/// draws its outlined capsule, the classic theme a plain rounded bar. Pages use
/// this instead of choosing between the two.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 14,
    this.color,
  });

  /// 0..1.
  final double value;
  final double height;

  /// The fill; null = the theme's default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (context.isMascot) {
      return MascotProgressBar(value: value, height: height + 6, fill: color);
    }
    return SizedBox(
      height: height,
      child: LinearProgressIndicator(
        value: value,
        year2023: false, // ignore: deprecated_member_use
        borderRadius: AppRadius.pillR,
        stopIndicatorRadius: 0,
        trackGap: 0,
        color: color,
      ),
    );
  }
}
