import 'package:flutter/material.dart';

/// A number that counts up from zero when it first appears.
///
/// Used for the shop's coin balance: the page is pushed fresh each visit, so
/// the tween restarts every time it is opened.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text('$current', style: style),
    );
  }
}
