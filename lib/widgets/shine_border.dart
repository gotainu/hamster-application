import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedShiningBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final bool active;

  const AnimatedShiningBorder({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.borderWidth = 2.5,
    this.active = true,
  });

  @override
  State<AnimatedShiningBorder> createState() => _AnimatedShiningBorderState();
}

class _AnimatedShiningBorderState extends State<AnimatedShiningBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedShiningBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.reset();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ShiningBorderPainter(
            progress: widget.active ? _controller.value : 0,
            borderRadius: widget.borderRadius,
            borderWidth: widget.borderWidth,
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

  _ShiningBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Oura風ブルーグラデ
    final colors = [
      const Color(0xFF5897F8),
      const Color(0xFFA66BFF),
      const Color(0xFF1DE9B6),
      const Color(0xFF5897F8),
    ];
    final sweepGradient = SweepGradient(
      colors: colors,
      startAngle: 0,
      endAngle: 2 * pi,
      transform: GradientRotation(2 * pi * progress),
    );
    paint.shader = sweepGradient.createShader(rect);

    // シャイン用の白いフレア
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth + 1
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.75),
          Colors.transparent,
        ],
        stops: [progress, (progress + 0.12) % 1.0, (progress + 0.17) % 1.0],
        transform: GradientRotation(2 * pi * progress),
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, shinePaint);
  }

  @override
  bool shouldRepaint(_ShiningBorderPainter oldDelegate) => true;
}
