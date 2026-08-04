import 'dart:math';

import 'package:flutter/material.dart';

class AnimatedShiningBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final bool active;
  final Duration duration;
  final List<Color>? colors;

  const AnimatedShiningBorder({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.borderWidth = 2.5,
    this.active = true,
    this.duration = const Duration(seconds: 2),
    this.colors,
  });

  @override
  State<AnimatedShiningBorder> createState() => _AnimatedShiningBorderState();
}

class _AnimatedShiningBorderState extends State<AnimatedShiningBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedShiningBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate = widget.active && !reduceMotion;

    if (!animate) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShiningBorderPainter(
            progress: _controller.value,
            borderRadius: widget.borderRadius,
            borderWidth: widget.borderWidth,
            colors: widget.colors,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _ShiningBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;
  final double borderWidth;
  final List<Color>? colors;

  const _ShiningBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final borderColors = colors ??
        const [
          Color(0xFF5897F8),
          Color(0xFFA66BFF),
          Color(0xFF1DE9B6),
          Color(0xFF5897F8),
        ];

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = SweepGradient(
        colors: borderColors,
        transform: GradientRotation(2 * pi * progress),
      ).createShader(rect);

    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 1
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.78),
          Colors.transparent,
        ],
        stops: const [0.0, 0.08, 0.18],
        transform: GradientRotation(2 * pi * progress),
      ).createShader(rect);

    canvas
      ..drawRRect(rrect, borderPaint)
      ..drawRRect(rrect, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _ShiningBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.colors != colors;
  }
}
