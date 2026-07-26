import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../theme/app_theme.dart';

enum SemanticTrendChartMode { compact, full }

class SemanticTrendPoint {
  final DateTime x;
  final double y;

  const SemanticTrendPoint({required this.x, required this.y});
}

class SemanticTrendBand {
  final double start;
  final double end;
  final String label;
  final Color color;
  final Color labelColor;

  const SemanticTrendBand({
    required this.start,
    required this.end,
    required this.label,
    required this.color,
    required this.labelColor,
  });
}

class SemanticTrendChart extends StatelessWidget {
  final List<SemanticTrendPoint> points;
  final List<SemanticTrendBand> bands;
  final SemanticTrendChartMode mode;
  final String unit;
  final double minimum;
  final double maximum;
  final DateFormat? dateFormat;
  final DateTime? xMinimum;
  final DateTime? xMaximum;
  final double height;
  final bool showRawSeries;
  final bool showLatestMarker;
  final bool showLatestVerticalLine;
  final bool showBandLabels;
  final Color? lineColor;
  final double? smoothingAlpha;

  const SemanticTrendChart({
    super.key,
    required this.points,
    required this.bands,
    required this.unit,
    required this.minimum,
    required this.maximum,
    this.mode = SemanticTrendChartMode.compact,
    this.dateFormat,
    this.xMinimum,
    this.xMaximum,
    this.height = 72,
    this.showRawSeries = true,
    this.showLatestMarker = true,
    this.showLatestVerticalLine = true,
    this.showBandLabels = true,
    this.lineColor,
    this.smoothingAlpha,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '推移を表示するためのデータが不足しています',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondaryText(context),
                ),
          ),
        ),
      );
    }

    final sortedPoints = List<SemanticTrendPoint>.from(points)
      ..sort((a, b) => a.x.compareTo(b.x));

    final latestPoint = sortedPoints.last;
    final isDark = AppTheme.isDark(context);
    final compact = mode == SemanticTrendChartMode.compact;
    final effectiveLineColor =
        lineColor ?? (isDark ? Colors.white : const Color(0xFF374151));
    final rawLineColor = effectiveLineColor.withValues(
      alpha: compact ? (isDark ? 0.34 : 0.26) : (isDark ? 0.24 : 0.18),
    );
    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        effectiveLineColor.withValues(alpha: compact ? 0.22 : 0.16),
        effectiveLineColor.withValues(alpha: 0.015),
      ],
    );
    final trendPoints = _buildEmaSeries(
      sortedPoints,
      alpha: smoothingAlpha ??
          (sortedPoints.length >= 100
              ? 0.12
              : sortedPoints.length >= 20
                  ? 0.22
                  : 0.35),
    );

    return SizedBox(
      height: height,
      child: SfCartesianChart(
        margin: EdgeInsets.zero,
        plotAreaBorderWidth: 0,
        plotAreaBackgroundColor: Colors.transparent,
        primaryXAxis: DateTimeAxis(
          minimum: xMinimum,
          maximum: xMaximum,
          isVisible: !compact,
          dateFormat: dateFormat,
          majorGridLines: MajorGridLines(
            width: compact ? 0 : 0.7,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
          ),
          axisLine: AxisLine(
            width: compact ? 0 : 0.8,
            color: AppTheme.chartAxis(context),
          ),
          labelStyle: TextStyle(
            color: AppTheme.secondaryText(context),
            fontSize: 11,
          ),
          plotBands: showLatestVerticalLine
              ? [
                  PlotBand(
                    start: latestPoint.x,
                    end: latestPoint.x,
                    borderWidth: compact ? 0.8 : 1,
                    borderColor: effectiveLineColor.withValues(
                      alpha: compact ? 0.35 : 0.5,
                    ),
                  ),
                ]
              : const [],
        ),
        primaryYAxis: NumericAxis(
          minimum: minimum,
          maximum: maximum,
          isVisible: !compact,
          plotBands: bands
              .map(
                (band) => PlotBand(
                  start: band.start,
                  end: band.end,
                  text: showBandLabels ? band.label : '',
                  horizontalTextAlignment: TextAnchor.end,
                  verticalTextAlignment: TextAnchor.middle,
                  color: compact
                      ? band.color.withValues(alpha: isDark ? 0.18 : 0.14)
                      : band.color,
                  borderWidth: compact ? 0.45 : 0,
                  borderColor: band.labelColor.withValues(
                    alpha: compact ? 0.18 : 0,
                  ),
                  textStyle: TextStyle(
                    color: band.labelColor,
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
              .toList(),
          majorGridLines: MajorGridLines(
            width: compact ? 0 : 0.7,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
          ),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: TextStyle(
            color: AppTheme.secondaryText(context),
            fontSize: 11,
          ),
          axisLabelFormatter: (details) {
            final value = details.value;
            final text = switch (unit) {
              '%' => '${value.round()}%',
              '℃' => value.toStringAsFixed(1),
              _ => value.round().toString(),
            };
            return ChartAxisLabel(text, details.textStyle);
          },
        ),
        series: <CartesianSeries<SemanticTrendPoint, DateTime>>[
          SplineAreaSeries<SemanticTrendPoint, DateTime>(
            dataSource: trendPoints,
            xValueMapper: (point, _) => point.x,
            yValueMapper: (point, _) => point.y,
            splineType: SplineType.monotonic,
            gradient: areaGradient,
            borderWidth: 0,
            animationDuration: compact ? 0 : 500,
          ),
          if (showRawSeries)
            LineSeries<SemanticTrendPoint, DateTime>(
              dataSource: sortedPoints,
              xValueMapper: (point, _) => point.x,
              yValueMapper: (point, _) => point.y,
              color: rawLineColor,
              width: compact ? 0.9 : 1.2,
              animationDuration: 0,
              markerSettings: const MarkerSettings(isVisible: false),
            ),
          SplineSeries<SemanticTrendPoint, DateTime>(
            dataSource: trendPoints,
            xValueMapper: (point, _) => point.x,
            yValueMapper: (point, _) => point.y,
            splineType: SplineType.monotonic,
            color: effectiveLineColor,
            width: compact ? 3.2 : 3,
            animationDuration: compact ? 0 : 500,
            markerSettings: const MarkerSettings(isVisible: false),
          ),
          if (showLatestMarker)
            ScatterSeries<SemanticTrendPoint, DateTime>(
              dataSource: [latestPoint],
              xValueMapper: (point, _) => point.x,
              yValueMapper: (point, _) => point.y,
              color: effectiveLineColor,
              animationDuration: 0,
              markerSettings: MarkerSettings(
                isVisible: true,
                width: compact ? 13 : 16,
                height: compact ? 13 : 16,
                shape: DataMarkerType.circle,
                color: effectiveLineColor,
                borderWidth: compact ? 2.5 : 4,
                borderColor: isDark ? const Color(0xFF232635) : Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  List<SemanticTrendPoint> _buildEmaSeries(
    List<SemanticTrendPoint> source, {
    required double alpha,
  }) {
    if (source.isEmpty) return const [];
    if (source.length == 1) return [source.first];

    final result = <SemanticTrendPoint>[];
    var current = source.first.y;
    result.add(SemanticTrendPoint(x: source.first.x, y: current));

    for (var i = 1; i < source.length; i++) {
      current = alpha * source[i].y + (1 - alpha) * current;
      result.add(SemanticTrendPoint(x: source[i].x, y: current));
    }

    return result;
  }
}
