// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/environment_status_service.dart
import '../models/environment_assessment.dart';
import '../models/metric_card_view_data.dart';
import '../models/semantic_chart_band.dart';

enum EnvironmentMetricKind {
  temperature,
  humidity,
}

class EnvironmentStatusViewData {
  final String stateText;
  final String deltaText;
  final String summaryText;
  final List<SemanticChartBand> chartBands;
  final MetricCardViewData card;

  const EnvironmentStatusViewData({
    required this.stateText,
    required this.deltaText,
    required this.summaryText,
    required this.chartBands,
    required this.card,
  });
}

class EnvironmentHeroViewData {
  final EnvironmentMetricKind metricKind;
  final String metricLabel;
  final String metricValueText;
  final String metricSubText;
  final List<SemanticChartBand> chartBands;

  const EnvironmentHeroViewData({
    required this.metricKind,
    required this.metricLabel,
    required this.metricValueText,
    required this.metricSubText,
    required this.chartBands,
  });
}

class EnvironmentStatusService {
  const EnvironmentStatusService();

  static const double tempMin = 20.0;
  static const double tempMax = 26.0;
  static const double humMin = 40.0;
  static const double humMax = 60.0;

  List<SemanticChartBand> _buildTemperatureBands() {
    return const [
      SemanticChartBand(
        start: double.negativeInfinity,
        end: tempMin,
        bandKey: SemanticBandKey.low,
      ),
      SemanticChartBand(
        start: tempMin,
        end: tempMax,
        bandKey: SemanticBandKey.normal,
      ),
      SemanticChartBand(
        start: tempMax,
        end: double.infinity,
        bandKey: SemanticBandKey.high,
      ),
    ];
  }

  List<SemanticChartBand> _buildHumidityBands() {
    return const [
      SemanticChartBand(
        start: double.negativeInfinity,
        end: humMin,
        bandKey: SemanticBandKey.low,
      ),
      SemanticChartBand(
        start: humMin,
        end: humMax,
        bandKey: SemanticBandKey.normal,
      ),
      SemanticChartBand(
        start: humMax,
        end: double.infinity,
        bandKey: SemanticBandKey.high,
      ),
    ];
  }

  EnvironmentStatusViewData buildTemperatureStatus(double? temp) {
    final bands = _buildTemperatureBands();

    if (temp == null) {
      return EnvironmentStatusViewData(
        stateText: '未評価',
        deltaText: '温度データがありません',
        summaryText: '温度データが取得できると状態を表示できます',
        chartBands: bands,
        card: MetricCardViewData(
          currentValueText: '—',
          stateText: '未評価',
          deltaText: '温度データがありません',
          summaryText: '温度データが取得できると状態を表示できます',
          chartBands: bands,
          hasChart: true,
          emptyChartText: '温度データがまだありません',
          emptyChartSubtext: 'データが入ると7日推移を表示できます',
        ),
      );
    }

    if (temp < tempMin) {
      final diff = tempMin - temp;
      return EnvironmentStatusViewData(
        stateText: '低め',
        deltaText: '適正下限より ${diff.toStringAsFixed(1)}℃ 低め',
        summaryText: '温度は低めです。冷えすぎていないか確認したい状態です',
        chartBands: bands,
        card: MetricCardViewData(
          currentValueText: '${temp.toStringAsFixed(1)}℃',
          stateText: '低め',
          deltaText: '適正下限より ${diff.toStringAsFixed(1)}℃ 低め',
          summaryText: '温度は低めです。冷えすぎていないか確認したい状態です',
          chartBands: bands,
          hasChart: true,
        ),
      );
    }

    if (temp > tempMax) {
      final diff = temp - tempMax;
      return EnvironmentStatusViewData(
        stateText: '高め',
        deltaText: '適正上限より ${diff.toStringAsFixed(1)}℃ 高め',
        summaryText: '温度は高めです。暑くなりすぎていないか確認したい状態です',
        chartBands: bands,
        card: MetricCardViewData(
          currentValueText: '${temp.toStringAsFixed(1)}℃',
          stateText: '高め',
          deltaText: '適正上限より ${diff.toStringAsFixed(1)}℃ 高め',
          summaryText: '温度は高めです。暑くなりすぎていないか確認したい状態です',
          chartBands: bands,
          hasChart: true,
        ),
      );
    }

    return EnvironmentStatusViewData(
      stateText: '理想範囲',
      deltaText: '適正範囲内です',
      summaryText: '温度は適正範囲内で安定しています',
      chartBands: bands,
      card: MetricCardViewData(
        currentValueText: '${temp.toStringAsFixed(1)}℃',
        stateText: '理想範囲',
        deltaText: '適正範囲内です',
        summaryText: '温度は適正範囲内で安定しています',
        chartBands: bands,
        hasChart: true,
      ),
    );
  }

  EnvironmentStatusViewData buildHumidityStatus(double? hum) {
    final bands = _buildHumidityBands();

    if (hum == null) {
      return EnvironmentStatusViewData(
        stateText: '未評価',
        deltaText: '湿度データがありません',
        summaryText: '湿度データが取得できると状態を表示できます',
        chartBands: bands,
        card: MetricCardViewData(
          currentValueText: '—',
          stateText: '未評価',
          deltaText: '湿度データがありません',
          summaryText: '湿度データが取得できると状態を表示できます',
          chartBands: bands,
          hasChart: true,
          emptyChartText: '湿度データがまだありません',
          emptyChartSubtext: 'データが入ると7日推移を表示できます',
        ),
      );
    }

    if (hum < humMin) {
      final diff = humMin - hum;
      return EnvironmentStatusViewData(
        stateText: '低め',
        deltaText: '適正下限より ${diff.round()}pt 低め',
        summaryText: '湿度は低めです。乾燥しすぎていないか見たい状態です',
        chartBands: bands,
        card: MetricCardViewData(
          currentValueText: '${hum.round()}%',
          stateText: '低め',
          deltaText: '適正下限より ${diff.round()}pt 低め',
          summaryText: '湿度は低めです。乾燥しすぎていないか見たい状態です',
          chartBands: bands,
          hasChart: true,
        ),
      );
    }

    if (hum > humMax) {
      final diff = hum - humMax;
      return EnvironmentStatusViewData(
        stateText: '高め',
        deltaText: '適正上限より ${diff.round()}pt 高め',
        summaryText: '湿度は高めです。通気や床材のこもりを見直したい状態です',
        chartBands: bands,
        card: MetricCardViewData(
          currentValueText: '${hum.round()}%',
          stateText: '高め',
          deltaText: '適正上限より ${diff.round()}pt 高め',
          summaryText: '湿度は高めです。通気や床材のこもりを見直したい状態です',
          chartBands: bands,
          hasChart: true,
        ),
      );
    }

    return EnvironmentStatusViewData(
      stateText: '理想範囲',
      deltaText: '適正範囲内です',
      summaryText: '湿度は適正範囲内で安定しています',
      chartBands: bands,
      card: MetricCardViewData(
        currentValueText: '${hum.round()}%',
        stateText: '理想範囲',
        deltaText: '適正範囲内です',
        summaryText: '湿度は適正範囲内で安定しています',
        chartBands: bands,
        hasChart: true,
      ),
    );
  }

  EnvironmentHeroViewData buildHeroViewData(EnvironmentAssessment assessment) {
    final metricKind = _mainMetricKind(assessment);

    if (metricKind == EnvironmentMetricKind.humidity) {
      final hum = assessment.avgHum;
      return EnvironmentHeroViewData(
        metricKind: EnvironmentMetricKind.humidity,
        metricLabel: '平均湿度',
        metricValueText: hum != null ? '${hum.round()}%' : '—',
        metricSubText: _humidityHeroSubText(hum),
        chartBands: buildHumidityStatus(hum).chartBands,
      );
    }

    final temp = assessment.avgTemp;
    return EnvironmentHeroViewData(
      metricKind: EnvironmentMetricKind.temperature,
      metricLabel: '平均温度',
      metricValueText: temp != null ? '${temp.toStringAsFixed(1)}℃' : '—',
      metricSubText: _temperatureHeroSubText(temp),
      chartBands: buildTemperatureStatus(temp).chartBands,
    );
  }

  EnvironmentMetricKind _mainMetricKind(EnvironmentAssessment a) {
    final hum = a.avgHum;
    final temp = a.avgTemp;

    if (hum != null && hum > humMax) return EnvironmentMetricKind.humidity;
    if (hum != null && hum < humMin) return EnvironmentMetricKind.humidity;
    if (temp != null && temp > tempMax) {
      return EnvironmentMetricKind.temperature;
    }
    if (temp != null && temp < tempMin) {
      return EnvironmentMetricKind.temperature;
    }
    if ((a.humRatio ?? 1) < (a.tempRatio ?? 1)) {
      return EnvironmentMetricKind.humidity;
    }
    return EnvironmentMetricKind.temperature;
  }

  String _temperatureHeroSubText(double? temp) {
    if (temp == null) return '理想 20–26℃';
    if (temp > tempMax) return '理想 20–26℃ より高め';
    if (temp < tempMin) return '理想 20–26℃ より低め';
    return '理想 20–26℃ の範囲';
  }

  String _humidityHeroSubText(double? hum) {
    if (hum == null) return '理想 40–60%';
    if (hum > humMax) return '理想 40–60% より高め';
    if (hum < humMin) return '理想 40–60% より低め';
    return '理想 40–60% の範囲';
  }
}
