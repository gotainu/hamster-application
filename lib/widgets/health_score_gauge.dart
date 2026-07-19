import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_assessment.dart';
import '../theme/app_theme.dart';

String healthAssessmentStateLabel(HealthAssessmentState state) {
  switch (state) {
    case HealthAssessmentState.alert:
      return '警戒';
    case HealthAssessmentState.caution:
      return '注意';
    case HealthAssessmentState.changed:
      return '変化あり';
    case HealthAssessmentState.good:
      return '良好';
    case HealthAssessmentState.stable:
      return '安定';
    case HealthAssessmentState.insufficientData:
      return '記録待ち';
    case HealthAssessmentState.unknown:
      return '未評価';
  }
}

Color healthAssessmentAccent(
  BuildContext context,
  HealthAssessmentState state,
) {
  switch (state) {
    case HealthAssessmentState.alert:
      return AppTheme.envDanger;
    case HealthAssessmentState.caution:
    case HealthAssessmentState.changed:
      return AppTheme.envCaution;
    case HealthAssessmentState.good:
    case HealthAssessmentState.stable:
      return AppTheme.envGood;
    case HealthAssessmentState.insufficientData:
    case HealthAssessmentState.unknown:
      return AppTheme.secondaryText(context);
  }
}

class HealthScoreGauge extends StatelessWidget {
  final int? score;
  final HealthAssessmentState state;
  final bool isProvisional;
  final double width;
  final double height;
  final double strokeWidth;
  final double scoreFontSize;
  final double stateFontSize;
  final bool showProvisionalCaption;

  const HealthScoreGauge({
    super.key,
    required this.score,
    required this.state,
    this.isProvisional = false,
    this.width = 260,
    this.height = 156,
    this.strokeWidth = 17,
    this.scoreFontSize = 50,
    this.stateFontSize = 15,
    this.showProvisionalCaption = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = healthAssessmentAccent(context, state);
    final stateLabel = healthAssessmentStateLabel(state);
    final trackColor = AppTheme.isDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final surfaceColor = AppTheme.cardSurface(context);

    return Semantics(
      label: score == null
          ? '$stateLabel。スコアは未算出です。'
          : '$stateLabel。スコアは$score点です。',
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(width, height),
              painter: _HealthScoreGaugePainter(
                progress: score == null ? 0 : score!.clamp(0, 100) / 100,
                hasScore: score != null,
                isProvisional: isProvisional,
                accent: accent,
                trackColor: trackColor,
                surfaceColor: surfaceColor,
                strokeWidth: strokeWidth,
              ),
            ),
            Positioned(
              top: height * 0.28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score == null ? '—' : '$score',
                    style: TextStyle(
                      fontSize: scoreFontSize,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: score == null ? 0 : -2,
                      color: AppTheme.primaryText(context),
                    ),
                  ),
                  SizedBox(height: height < 110 ? 4 : 7),
                  Text(
                    stateLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: stateFontSize,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (showProvisionalCaption && isProvisional) ...[
                    const SizedBox(height: 4),
                    Text(
                      '暫定',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.tertiaryText(context),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthScoreGaugePainter extends CustomPainter {
  final double progress;
  final bool hasScore;
  final bool isProvisional;
  final Color accent;
  final Color trackColor;
  final Color surfaceColor;
  final double strokeWidth;

  const _HealthScoreGaugePainter({
    required this.progress,
    required this.hasScore,
    required this.isProvisional,
    required this.accent,
    required this.trackColor,
    required this.surfaceColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final horizontalInset = strokeWidth + 3;
    final rect = Rect.fromLTWH(
      horizontalInset,
      strokeWidth * 0.9,
      size.width - horizontalInset * 2,
      size.height * 1.34,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    if (!hasScore) return;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: math.pi,
        endAngle: math.pi * 2,
        colors: [
          accent.withValues(alpha: 0.48),
          accent,
        ],
      ).createShader(rect);

    final clampedProgress = progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * clampedProgress,
      false,
      progressPaint,
    );

    if (!isProvisional || clampedProgress <= 0) return;

    final angle = math.pi + math.pi * clampedProgress;
    final center = rect.center;
    final radiusX = rect.width / 2;
    final radiusY = rect.height / 2;
    final endpoint = Offset(
      center.dx + radiusX * math.cos(angle),
      center.dy + radiusY * math.sin(angle),
    );

    canvas.drawCircle(
      endpoint,
      strokeWidth * 0.35,
      Paint()
        ..style = PaintingStyle.fill
        ..color = surfaceColor,
    );
    canvas.drawCircle(
      endpoint,
      strokeWidth * 0.35,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, strokeWidth * 0.14).toDouble()
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _HealthScoreGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hasScore != hasScore ||
        oldDelegate.isProvisional != isProvisional ||
        oldDelegate.accent != accent ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
