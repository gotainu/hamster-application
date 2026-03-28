import 'package:hamster_project/models/environment_assessment.dart';
import 'package:hamster_project/models/environment_assessment_history.dart';
import 'package:hamster_project/models/weekly_trend_summary.dart';

class EnvironmentTrendService {
  const EnvironmentTrendService();

  WeeklyTrendSummary buildWeeklyTrendSummary({
    required EnvironmentAssessment assessment,
    required List<EnvironmentAssessmentHistory> history,
    required String mainMetricLabel,
  }) {
    final validHistory = history.where((e) => e.hasCoreData).toList();
    if (validHistory.length < 2) {
      return WeeklyTrendSummary.insufficientData();
    }

    if (mainMetricLabel == '平均湿度') {
      final current = assessment.avgHum;
      final baseline = _avgOfHistory(validHistory, (e) => e.avgHum);
      if (current == null || baseline == null) {
        return WeeklyTrendSummary.insufficientData();
      }

      final diff = current - baseline;
      final direction = _directionForHumidity(assessment, diff);

      return WeeklyTrendSummary(
        deltaText: _buildHumidityDeltaText(diff),
        directionText: _directionText(direction),
        summaryText: _buildHumiditySummaryText(assessment, diff),
        direction: direction,
      );
    }

    if (mainMetricLabel == '平均温度') {
      final current = assessment.avgTemp;
      final baseline = _avgOfHistory(validHistory, (e) => e.avgTemp);
      if (current == null || baseline == null) {
        return WeeklyTrendSummary.insufficientData();
      }

      final diff = current - baseline;
      final direction = _directionForTemperature(assessment, diff);

      return WeeklyTrendSummary(
        deltaText: _buildTemperatureDeltaText(diff),
        directionText: _directionText(direction),
        summaryText: _buildTemperatureSummaryText(assessment, diff),
        direction: direction,
      );
    }

    return WeeklyTrendSummary.insufficientData();
  }

  double? _avgOfHistory(
    List<EnvironmentAssessmentHistory> items,
    double? Function(EnvironmentAssessmentHistory e) pick,
  ) {
    final values = items.map(pick).whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  TrendDirection _directionForHumidity(EnvironmentAssessment a, double diff) {
    final hum = a.avgHum;
    if (hum == null) return TrendDirection.unknown;

    if (diff.abs() < 2.0) return TrendDirection.stable;

    if (hum > 60) {
      return diff < 0 ? TrendDirection.improving : TrendDirection.worsening;
    }

    if (hum < 40) {
      return diff > 0 ? TrendDirection.improving : TrendDirection.worsening;
    }

    if (diff.abs() < 3.0) return TrendDirection.stable;
    return diff < 0 ? TrendDirection.worsening : TrendDirection.improving;
  }

  TrendDirection _directionForTemperature(
      EnvironmentAssessment a, double diff) {
    final temp = a.avgTemp;
    if (temp == null) return TrendDirection.unknown;

    if (diff.abs() < 0.3) return TrendDirection.stable;

    if (temp > 26) {
      return diff < 0 ? TrendDirection.improving : TrendDirection.worsening;
    }

    if (temp < 20) {
      return diff > 0 ? TrendDirection.improving : TrendDirection.worsening;
    }

    if (diff.abs() < 0.5) return TrendDirection.stable;
    return diff < 0 ? TrendDirection.worsening : TrendDirection.improving;
  }

  String _directionText(TrendDirection direction) {
    switch (direction) {
      case TrendDirection.improving:
        return '改善';
      case TrendDirection.worsening:
        return '悪化';
      case TrendDirection.stable:
        return '横ばい';
      case TrendDirection.unknown:
        return '比較中';
    }
  }

  String _buildHumidityDeltaText(double diff) {
    if (diff.abs() < 2.0) {
      return '先週平均とほぼ同じ湿度です';
    }

    final sign = diff > 0 ? '+' : '';
    return '先週平均より 湿度 ${sign}${diff.round()}pt';
  }

  String _buildTemperatureDeltaText(double diff) {
    if (diff.abs() < 0.3) {
      return '先週平均とほぼ同じ温度です';
    }

    final sign = diff > 0 ? '+' : '';
    return '先週平均より 温度 ${sign}${diff.toStringAsFixed(1)}℃';
  }

  String _buildHumiditySummaryText(EnvironmentAssessment a, double diff) {
    final hum = a.avgHum;
    if (hum == null) return '湿度の比較データを確認中です';

    if (hum > 60) {
      if (diff.abs() < 2.0) return '湿度はまだ高めですが、先週から大きな変化はありません';
      return diff < 0 ? '湿度はまだ高めですが、先週より改善' : '湿度はまだ高めで、先週より悪化';
    }

    if (hum < 40) {
      if (diff.abs() < 2.0) return '湿度はまだ低めですが、先週から大きな変化はありません';
      return diff > 0 ? '湿度はまだ低めですが、先週より改善' : '湿度はまだ低めで、先週より悪化';
    }

    if (diff.abs() < 2.0) return '湿度は安定しており、先週から大きな変化はありません';
    return diff < 0 ? '湿度はやや低下しました' : '湿度はやや上昇しました';
  }

  String _buildTemperatureSummaryText(EnvironmentAssessment a, double diff) {
    final temp = a.avgTemp;
    if (temp == null) return '温度の比較データを確認中です';

    if (temp > 26) {
      if (diff.abs() < 0.3) return '温度はまだ高めですが、先週から大きな変化はありません';
      return diff < 0 ? '温度はまだ高めですが、先週より改善' : '温度はまだ高めで、先週より悪化';
    }

    if (temp < 20) {
      if (diff.abs() < 0.3) return '温度はまだ低めですが、先週から大きな変化はありません';
      return diff > 0 ? '温度はまだ低めですが、先週より改善' : '温度はまだ低めで、先週より悪化';
    }

    if (diff.abs() < 0.3) return '温度は安定しており、先週から大きな変化はありません';
    return diff < 0 ? '温度はやや低下しました' : '温度はやや上昇しました';
  }
}
