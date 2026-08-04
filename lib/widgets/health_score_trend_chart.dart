import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_assessment.dart';
import '../theme/app_theme.dart';
import 'health_score_gauge.dart';

class HealthScoreTrendPoint {
  final DateTime date;
  final int? score;
  final HealthAssessmentState state;
  final bool isProvisional;

  const HealthScoreTrendPoint({
    required this.date,
    required this.score,
    required this.state,
    required this.isProvisional,
  });
}

class HealthScoreTrendSummary {
  final List<HealthScoreTrendPoint> points;
  final int? averageScore;
  final int? previousDayDelta;
  final int recordedDays;

  const HealthScoreTrendSummary({
    required this.points,
    required this.averageScore,
    required this.previousDayDelta,
    required this.recordedDays,
  });

  bool get hasAnyScore => recordedDays > 0;
  bool get hasTrend => recordedDays >= 2;
}

HealthScoreTrendSummary buildHealthScoreTrendSummary({
  required List<HealthAssessment> history,
  HealthAssessment? latest,
  int days = 7,
}) {
  final safeDays = days.clamp(2, 30).toInt();
  final byDateKey = <String, HealthAssessment>{};

  for (final item in history) {
    final key = item.dateKey.trim();
    if (_parseDateKey(key) == null) continue;
    byDateKey[key] = item;
  }

  if (latest != null && _parseDateKey(latest.dateKey) != null) {
    byDateKey[latest.dateKey] = latest;
  }

  final availableDates =
      byDateKey.keys.map(_parseDateKey).whereType<DateTime>().toList()..sort();

  final endDate = latest == null
      ? (availableDates.isEmpty
          ? _dateOnly(DateTime.now())
          : availableDates.last)
      : (_parseDateKey(latest.dateKey) ?? _dateOnly(DateTime.now()));

  final startDate = endDate.subtract(Duration(days: safeDays - 1));
  final points = <HealthScoreTrendPoint>[];

  for (var index = 0; index < safeDays; index += 1) {
    final date = startDate.add(Duration(days: index));
    final assessment = byDateKey[_formatDateKey(date)];
    final publishedScore = assessment?.overall.score;
    final score = publishedScore ?? assessment?.overall.observedScore;

    points.add(
      HealthScoreTrendPoint(
        date: date,
        score: score,
        state:
            assessment?.overall.state ?? HealthAssessmentState.insufficientData,
        isProvisional: assessment == null
            ? false
            : assessment.overall.isProvisional || publishedScore == null,
      ),
    );
  }

  final recordedScores = points
      .map((point) => point.score)
      .whereType<int>()
      .toList(growable: false);
  final average = recordedScores.isEmpty
      ? null
      : (recordedScores.reduce((a, b) => a + b) / recordedScores.length)
          .round();

  int? previousDayDelta;
  if (points.length >= 2) {
    final latestScore = points.last.score;
    final previousScore = points[points.length - 2].score;
    if (latestScore != null && previousScore != null) {
      previousDayDelta = latestScore - previousScore;
    }
  }

  return HealthScoreTrendSummary(
    points: points,
    averageScore: average,
    previousDayDelta: previousDayDelta,
    recordedDays: recordedScores.length,
  );
}

class HealthScoreTrendChart extends StatelessWidget {
  final HealthScoreTrendSummary summary;
  final double height;
  final bool compact;
  final bool showThresholdLabels;
  final bool monochrome;
  final Color? foregroundColor;
  final Color? mutedForegroundColor;
  final Color? gridColor;
  final Color? pointFillColor;
  final List<Shadow>? labelShadows;

  const HealthScoreTrendChart({
    super.key,
    required this.summary,
    this.height = 112,
    this.compact = false,
    this.showThresholdLabels = true,
    this.monochrome = false,
    this.foregroundColor,
    this.mutedForegroundColor,
    this.gridColor,
    this.pointFillColor,
    this.labelShadows,
  });

  @override
  Widget build(BuildContext context) {
    if (!summary.hasAnyScore) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '総合スコアの履歴を蓄積中です',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      mutedForegroundColor ?? AppTheme.secondaryText(context),
                  shadows: labelShadows,
                ),
          ),
        ),
      );
    }

    final latestState = summary.points
        .lastWhere(
          (point) => point.score != null,
          orElse: () => summary.points.last,
        )
        .state;
    final resolvedForeground = foregroundColor ?? Colors.white;
    final accent = monochrome
        ? resolvedForeground
        : healthAssessmentAccent(context, latestState);
    final resolvedGridColor = gridColor ??
        (monochrome
            ? resolvedForeground.withValues(alpha: 0.22)
            : AppTheme.isDark(context)
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.09));
    final chartHeight = math.max(48.0, height - 25).toDouble();

    return Semantics(
      label: '直近7日間の総合コンディションスコア推移',
      child: Column(
        children: [
          SizedBox(
            height: chartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _HealthScoreTrendPainter(
                points: summary.points,
                accent: accent,
                surfaceColor: pointFillColor ?? AppTheme.cardSurface(context),
                gridColor: resolvedGridColor,
                goodColor: monochrome ? resolvedForeground : AppTheme.envGood,
                cautionColor:
                    monochrome ? resolvedForeground : AppTheme.envCaution,
                alertColor:
                    monochrome ? resolvedForeground : AppTheme.envDanger,
                showThresholdLabels: showThresholdLabels && !compact,
              ),
            ),
          ),
          const SizedBox(height: 5),
          _TrendDateLabels(
            points: summary.points,
            compact: compact,
            color: mutedForegroundColor,
            shadows: labelShadows,
          ),
        ],
      ),
    );
  }
}

class _TrendDateLabels extends StatelessWidget {
  final List<HealthScoreTrendPoint> points;
  final bool compact;
  final Color? color;
  final List<Shadow>? shadows;

  const _TrendDateLabels({
    required this.points,
    required this.compact,
    this.color,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final dateFormat = DateFormat('M/d');
    final labels = compact
        ? <DateTime>[points.first.date, points.last.date]
        : <DateTime>[
            points.first.date,
            points[points.length ~/ 2].date,
            points.last.date,
          ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (date) => Text(
              dateFormat.format(date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color ?? AppTheme.tertiaryText(context),
                    fontSize: compact ? 10 : null,
                    fontWeight: FontWeight.w700,
                    shadows: shadows,
                  ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _HealthScoreTrendPainter extends CustomPainter {
  final List<HealthScoreTrendPoint> points;
  final Color accent;
  final Color surfaceColor;
  final Color gridColor;
  final Color goodColor;
  final Color cautionColor;
  final Color alertColor;
  final bool showThresholdLabels;

  const _HealthScoreTrendPainter({
    required this.points,
    required this.accent,
    required this.surfaceColor,
    required this.gridColor,
    required this.goodColor,
    required this.cautionColor,
    required this.alertColor,
    required this.showThresholdLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final labelSpace = showThresholdLabels ? 28.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      4,
      5,
      math.max(1.0, size.width - 8 - labelSpace).toDouble(),
      math.max(1.0, size.height - 10).toDouble(),
    );

    double yForScore(double score) {
      return plotRect.top + (1 - score.clamp(0, 100) / 100) * plotRect.height;
    }

    final y90 = yForScore(90);
    final y70 = yForScore(70);

    canvas.drawRect(
      Rect.fromLTRB(plotRect.left, plotRect.top, plotRect.right, y90),
      Paint()..color = goodColor.withValues(alpha: 0.055),
    );
    canvas.drawRect(
      Rect.fromLTRB(plotRect.left, y90, plotRect.right, y70),
      Paint()..color = cautionColor.withValues(alpha: 0.055),
    );
    canvas.drawRect(
      Rect.fromLTRB(plotRect.left, y70, plotRect.right, plotRect.bottom),
      Paint()..color = alertColor.withValues(alpha: 0.04),
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(plotRect.left, y90),
      Offset(plotRect.right, y90),
      gridPaint,
    );
    canvas.drawLine(
      Offset(plotRect.left, y70),
      Offset(plotRect.right, y70),
      gridPaint,
    );

    if (showThresholdLabels) {
      _drawText(
        canvas,
        '90',
        Offset(plotRect.right + 6, y90 - 7),
        goodColor,
      );
      _drawText(
        canvas,
        '70',
        Offset(plotRect.right + 6, y70 - 7),
        cautionColor,
      );
    }

    final lastIndex = points.length - 1;
    double xForIndex(int index) {
      if (lastIndex <= 0) return plotRect.center.dx;
      return plotRect.left + plotRect.width * index / lastIndex;
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent;

    for (var index = 1; index < points.length; index += 1) {
      final previous = points[index - 1];
      final current = points[index];
      if (previous.score == null || current.score == null) continue;

      canvas.drawLine(
        Offset(xForIndex(index - 1), yForScore(previous.score!.toDouble())),
        Offset(xForIndex(index), yForScore(current.score!.toDouble())),
        linePaint,
      );
    }

    final lastRecordedIndex = points.lastIndexWhere(
      (point) => point.score != null,
    );

    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final score = point.score;
      if (score == null) continue;

      final pointAccent = healthStateColor(point.state);
      final center = Offset(xForIndex(index), yForScore(score.toDouble()));
      final isLatest = index == lastRecordedIndex;
      final radius = isLatest ? 5.5 : 4.0;

      if (isLatest) {
        canvas.drawCircle(
          center,
          radius + 4,
          Paint()..color = pointAccent.withValues(alpha: 0.16),
        );
      }

      if (point.isProvisional) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.fill
            ..color = surfaceColor,
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = pointAccent,
        );
      } else {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.fill
            ..color = pointAccent,
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = surfaceColor.withValues(alpha: 0.9),
        );
      }
    }
  }

  Color healthStateColor(HealthAssessmentState state) {
    switch (state) {
      case HealthAssessmentState.alert:
        return alertColor;
      case HealthAssessmentState.caution:
      case HealthAssessmentState.changed:
        return cautionColor;
      case HealthAssessmentState.good:
      case HealthAssessmentState.stable:
        return goodColor;
      case HealthAssessmentState.insufficientData:
      case HealthAssessmentState.unknown:
        return gridColor;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _HealthScoreTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accent != accent ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.goodColor != goodColor ||
        oldDelegate.cautionColor != cautionColor ||
        oldDelegate.alertColor != alertColor ||
        oldDelegate.showThresholdLabels != showThresholdLabels;
  }
}

DateTime? _parseDateKey(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return _dateOnly(parsed);
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _formatDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
