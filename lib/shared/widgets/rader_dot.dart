import 'package:flutter/material.dart';

class RadarDot extends StatefulWidget {
  final bool active;
  final Color color;
  final double baseSize;
  final double endSize;

  const RadarDot({super.key,
    required this.active,
    required this.color,
    this.baseSize = 6,
    this.endSize = 12,
  });

  @override
  State<RadarDot> createState() => _RadarDotState();
}

class _RadarDotState extends State<RadarDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RadarDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return DecoratedBox(
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        child: const SizedBox(width: 6, height: 6),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final rippleSize = widget.baseSize + (widget.endSize * t);
        final rippleOpacity = (1 - t) * 0.45;

        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: rippleSize,
                height: rippleSize,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: rippleOpacity),
                  shape: BoxShape.circle,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                child: const SizedBox(width: 6, height: 6),
              ),
            ],
          ),
        );
      },
    );
  }
}