// /Users/gota/local_dev/flutter_projects/hamster_project/lib/widgets/semantic_sparkline.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hamster_project/models/semantic_chart_band.dart';
import 'package:hamster_project/theme/app_theme.dart';

class SemanticSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final List<SemanticChartBand>? bands;
  final double height;

  const SemanticSparkline({
    super.key,
    required this.values,
    required this.color,
    this.bands,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SemanticSparklinePainter(
          values: values,
          color: color,
          bands: bands,
          context: context,
        ),
      ),
    );
  }
}

class _SemanticSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final List<SemanticChartBand>? bands;
  final BuildContext context;

  _SemanticSparklinePainter({
    required this.values,
    required this.color,
    required this.bands,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    double minV = values.first;
    double maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }

    if (bands != null && bands!.isNotEmpty) {
      for (final band in bands!) {
        if (!band.start.isInfinite && band.start < minV) {
          minV = band.start;
        }
        if (!band.end.isInfinite && band.end > maxV) {
          maxV = band.end;
        }
      }
    }

    final rawRange = (maxV - minV).abs();
    final pad = rawRange < 0.0001 ? 1.0 : rawRange * 0.08;
    minV -= pad;
    maxV += pad;

    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    if (bands != null && bands!.isNotEmpty) {
      for (final band in bands!) {
        final bandStart = (band.start.isInfinite && band.start.isNegative)
            ? minV
            : band.start;
        final bandEnd = band.end.isInfinite ? maxV : band.end;

        final clippedStart = bandStart.clamp(minV, maxV).toDouble();
        final clippedEnd = bandEnd.clamp(minV, maxV).toDouble();

        if (clippedEnd <= clippedStart) continue;

        final topY = size.height - ((clippedEnd - minV) / range) * size.height;
        final bottomY =
            size.height - ((clippedStart - minV) / range) * size.height;

        final rect = Rect.fromLTRB(0, topY, size.width, bottomY);

        canvas.drawRect(
          rect,
          Paint()..color = AppTheme.semanticBandColor(context, band.bandKey),
        );
      }
    }

    final path = Path();

    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glow = Paint()
      ..color = AppTheme.chartGlow(color, context)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);

    final lastX = size.width;
    final lastY = size.height - ((values.last - minV) / range) * size.height;

    canvas.drawCircle(
      Offset(lastX, lastY),
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SemanticSparklinePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.bands != bands;
  }
}
