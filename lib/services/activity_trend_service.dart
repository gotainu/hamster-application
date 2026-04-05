// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/activity_trend_service.dart
import 'dart:math' as math;

import 'package:hamster_project/models/activity_distribution.dart';
import 'package:hamster_project/models/activity_summary.dart';
import 'package:hamster_project/models/health_record.dart';
import 'package:hamster_project/models/metric_card_view_data.dart';
import 'package:hamster_project/models/semantic_chart_band.dart';

class ActivityTrendService {
  const ActivityTrendService();

  ActivitySummary buildSummary({
    required double todayDistanceMeters,
    required double avg7DistanceMeters,
    required List<HealthRecord> recentRecords,
    required List<HealthRecord> allDailyRecords,
  }) {
    final nonZeroAll = allDailyRecords.where((e) => e.distance > 0).toList();
    final hasAnyRecord = nonZeroAll.isNotEmpty;
    final todayHasRecord = _hasTodayRecord(allDailyRecords);
    final latestRecordedAt =
        hasAnyRecord ? _latestRecordedAt(allDailyRecords) : null;

    if (!hasAnyRecord) {
      return ActivitySummary.empty();
    }

    final referenceRecord = todayHasRecord
        ? _todayRecord(allDailyRecords)!
        : _latestNonZeroRecord(allDailyRecords)!;

    final referenceDistanceMeters = referenceRecord.distance;
    final referenceDate = referenceRecord.date;

    final distribution = _buildDistribution(
      allDailyRecords: nonZeroAll,
      markerValue: referenceDistanceMeters,
      markerCaption: todayHasRecord ? '今日の位置' : '最新記録日の位置',
    );

    final chartBands = _buildChartBands(distribution);

    final deltaPct = avg7DistanceMeters <= 0
        ? 0.0
        : (referenceDistanceMeters - avg7DistanceMeters) /
            avg7DistanceMeters *
            100.0;

    if (!todayHasRecord) {
      const stateText = '未入力';
      final deltaText = '今日はまだ走行距離が記録されていません';
      final summaryText =
          '最新記録日は ${distribution.bandLabel} です。記録すると今日の位置も確認できます';

      return ActivitySummary(
        todayDistanceMeters: 0,
        avg7DistanceMeters: avg7DistanceMeters,
        deltaPct: 0,
        latestRecordedAt: latestRecordedAt,
        headline: '今日はまだ未入力です',
        deltaText: deltaText,
        summaryText: summaryText,
        directionText: stateText,
        hasAnyRecord: true,
        todayHasRecord: false,
        referenceDistanceMeters: referenceDistanceMeters,
        referenceDate: referenceDate,
        distribution: distribution,
        chartBands: chartBands,
        card: MetricCardViewData(
          currentValueText: '未入力',
          stateText: stateText,
          deltaText: deltaText,
          summaryText: summaryText,
          chartBands: chartBands,
          hasChart: true,
        ),
      );
    }

    final bandLabel = distribution.bandLabel;
    final deltaText =
        _deltaText(todayDistanceMeters, avg7DistanceMeters, deltaPct);
    final summaryText = _summaryText(bandLabel);

    return ActivitySummary(
      todayDistanceMeters: todayDistanceMeters,
      avg7DistanceMeters: avg7DistanceMeters,
      deltaPct: deltaPct,
      latestRecordedAt: latestRecordedAt,
      headline: _headline(bandLabel),
      deltaText: deltaText,
      summaryText: summaryText,
      directionText: bandLabel,
      hasAnyRecord: true,
      todayHasRecord: true,
      referenceDistanceMeters: referenceDistanceMeters,
      referenceDate: referenceDate,
      distribution: distribution,
      chartBands: chartBands,
      card: MetricCardViewData(
        currentValueText: '${todayDistanceMeters.toStringAsFixed(0)} m',
        stateText: bandLabel,
        deltaText: deltaText,
        summaryText: summaryText,
        chartBands: chartBands,
        hasChart: true,
      ),
    );
  }

  List<SemanticChartBand> _buildChartBands(ActivityDistribution distribution) {
    return [
      SemanticChartBand(
        start: double.negativeInfinity,
        end: distribution.p25,
        bandKey: SemanticBandKey.low,
      ),
      SemanticChartBand(
        start: distribution.p25,
        end: distribution.p75,
        bandKey: SemanticBandKey.normal,
      ),
      SemanticChartBand(
        start: distribution.p75,
        end: double.infinity,
        bandKey: SemanticBandKey.high,
      ),
    ];
  }

  bool _hasTodayRecord(List<HealthRecord> records) {
    final now = DateTime.now();
    return records.any((e) {
      if (e.distance <= 0) return false;
      final d = e.date.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    });
  }

  HealthRecord? _todayRecord(List<HealthRecord> records) {
    final now = DateTime.now();
    final matches = records.where((e) {
      if (e.distance <= 0) return false;
      final d = e.date.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.date.compareTo(b.date));
    return matches.last;
  }

  HealthRecord? _latestNonZeroRecord(List<HealthRecord> records) {
    final actual = records.where((e) => e.distance > 0).toList();
    if (actual.isEmpty) return null;
    actual.sort((a, b) => a.date.compareTo(b.date));
    return actual.last;
  }

  DateTime? _latestRecordedAt(List<HealthRecord> records) {
    final actualRecords = records.where((e) => e.distance > 0).toList();
    if (actualRecords.isEmpty) return null;

    final sorted = [...actualRecords]..sort((a, b) => a.date.compareTo(b.date));
    return sorted.last.date;
  }

  ActivityDistribution _buildDistribution({
    required List<HealthRecord> allDailyRecords,
    required double markerValue,
    required String markerCaption,
  }) {
    final values = allDailyRecords
        .map((e) => e.distance)
        .where((e) => e > 0)
        .toList()
      ..sort();

    final p10 = _percentile(values, 0.10);
    final p25 = _percentile(values, 0.25);
    final p50 = _percentile(values, 0.50);
    final p75 = _percentile(values, 0.75);
    final p90 = _percentile(values, 0.90);

    final bandLabel = _bandLabel(
      value: markerValue,
      p10: p10,
      p25: p25,
      p75: p75,
      p90: p90,
    );

    final rawMin = values.first;
    final rawMax = values.last;

    final binCount = math.min(8, math.max(6, (values.length / 4).ceil()));
    final rawWidth =
        (rawMax - rawMin).abs() < 0.0001 ? 1.0 : (rawMax - rawMin) / binCount;

    final width = _niceCompactBinWidth(rawWidth);
    final minV = (rawMin / width).floor() * width;
    final maxV = ((rawMax / width).ceil()) * width;

    final actualBinCount = math.max(1, ((maxV - minV) / width).ceil());
    final counts = List<int>.filled(actualBinCount, 0);

    for (final v in values) {
      var idx = ((v - minV) / width).floor();
      if (idx >= actualBinCount) idx = actualBinCount - 1;
      if (idx < 0) idx = 0;
      counts[idx] += 1;
    }

    final bins = <ActivityDistributionBin>[];
    for (int i = 0; i < actualBinCount; i++) {
      final start = minV + width * i;
      final end = start + width;
      bins.add(
        ActivityDistributionBin(
          start: start,
          end: end,
          count: counts[i],
          label: '${start.round()}-${end.round()}',
        ),
      );
    }

    return ActivityDistribution(
      bins: bins,
      markerValue: markerValue,
      markerCaption: markerCaption,
      bandLabel: bandLabel,
      p10: p10,
      p25: p25,
      p50: p50,
      p75: p75,
      p90: p90,
    );
  }

  double _percentile(List<double> sortedValues, double p) {
    if (sortedValues.isEmpty) return 0;
    if (sortedValues.length == 1) return sortedValues.first;

    final pos = (sortedValues.length - 1) * p;
    final lower = pos.floor();
    final upper = pos.ceil();

    if (lower == upper) return sortedValues[lower];

    final weight = pos - lower;
    return sortedValues[lower] * (1 - weight) + sortedValues[upper] * weight;
  }

  double _niceCompactBinWidth(double rawWidth) {
    if (rawWidth <= 0) return 500.0;
    if (rawWidth <= 200) return 200.0;
    if (rawWidth <= 250) return 250.0;
    if (rawWidth <= 500) return 500.0;
    if (rawWidth <= 800) return 800.0;
    if (rawWidth <= 1000) return 1000.0;
    if (rawWidth <= 1500) return 1500.0;
    return 2000.0;
  }

  String _bandLabel({
    required double value,
    required double p10,
    required double p25,
    required double p75,
    required double p90,
  }) {
    if (value < p10) return 'かなり少なめ';
    if (value < p25) return 'やや少なめ';
    if (value > p90) return 'かなり多め';
    if (value > p75) return 'やや多め';
    return '普段の範囲内';
  }

  String _headline(String bandLabel) {
    switch (bandLabel) {
      case 'かなり少なめ':
        return '今日はかなり少なめです';
      case 'やや少なめ':
        return '今日はやや少なめです';
      case 'やや多め':
        return '今日はやや多めです';
      case 'かなり多め':
        return '今日はかなり多めです';
      default:
        return '今日は普段の範囲内です';
    }
  }

  String _deltaText(double today, double avg7, double deltaPct) {
    if (avg7 <= 0 && today <= 0) {
      return '比較データがまだ少ないです';
    }
    if (deltaPct.abs() < 5) {
      return '直近7日平均とほぼ同じです';
    }
    final sign = deltaPct >= 0 ? '+' : '';
    return '直近7日平均より $sign${deltaPct.toStringAsFixed(0)}%';
  }

  String _summaryText(String bandLabel) {
    switch (bandLabel) {
      case 'かなり少なめ':
        return '過去の分布で見るとかなり少なめです。まずは様子を見たい水準です';
      case 'やや少なめ':
        return '過去の分布で見るとやや少なめです';
      case 'やや多め':
        return '過去の分布で見るとやや多めです';
      case 'かなり多め':
        return '過去の分布で見るとかなり多めです';
      default:
        return '過去の分布で見ると普段の範囲内です';
    }
  }
}
