// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/sensor_evaluation_service.dart

import '../models/activity_summary.dart';
import '../models/sensor_evaluation.dart';

class SensorEvaluationService {
  const SensorEvaluationService();

  static const double tempMin = 20.0;
  static const double tempMax = 26.0;
  static const double humMin = 40.0;
  static const double humMax = 60.0;

  SensorEvaluation build({
    required double? avgTemp,
    required double? avgHum,
    required ActivitySummary activitySummary,
  }) {
    final temperature = _buildTemperatureEvaluation(avgTemp);
    final humidity = _buildHumidityEvaluation(avgHum);
    final activity = _buildActivityEvaluation(activitySummary);

    final overallScore = (temperature.score * 0.5 +
            humidity.score * 0.25 +
            activity.score * 0.25)
        .round()
        .clamp(0, 100);

    final flags = _mergeFlags(
      temperature.flags,
      humidity.flags,
      activity.flags,
    );

    final overallState = _resolveOverallState(
      temperature.state,
      humidity.state,
      activity.state,
    );

    return SensorEvaluation(
      temperature: temperature,
      humidity: humidity,
      activity: activity,
      overallScore: overallScore,
      overallState: overallState,
      flags: flags,
      summary: _buildSummary(
        temperature: temperature,
        humidity: humidity,
        activity: activity,
        overallState: overallState,
      ),
    );
  }

  EnvironmentMetricEvaluation _buildTemperatureEvaluation(double? temp) {
    if (temp == null) {
      return const EnvironmentMetricEvaluation(
        value: null,
        score: 50,
        state: MetricState.unknown,
        flags: [],
        reason: '温度データがまだありません。',
      );
    }

    if (temp < tempMin) {
      final diff = tempMin - temp;
      final state = diff >= 2.0 ? MetricState.alert : MetricState.caution;
      final score = diff >= 2.0
          ? (65 - (diff * 12)).round().clamp(0, 100)
          : (85 - (diff * 10)).round().clamp(0, 100);

      return EnvironmentMetricEvaluation(
        value: temp,
        score: score,
        state: state,
        flags: const [EvaluationFlag.tempLow],
        reason: '温度が適正下限より ${diff.toStringAsFixed(1)}℃ 低い状態です。',
      );
    }

    if (temp > tempMax) {
      final diff = temp - tempMax;
      final state = diff >= 2.0 ? MetricState.alert : MetricState.caution;
      final score = diff >= 2.0
          ? (65 - (diff * 12)).round().clamp(0, 100)
          : (85 - (diff * 10)).round().clamp(0, 100);

      return EnvironmentMetricEvaluation(
        value: temp,
        score: score,
        state: state,
        flags: const [EvaluationFlag.tempHigh],
        reason: '温度が適正上限より ${diff.toStringAsFixed(1)}℃ 高い状態です。',
      );
    }

    return EnvironmentMetricEvaluation(
      value: temp,
      score: 100,
      state: MetricState.good,
      flags: const [],
      reason: '温度は適正範囲内です。',
    );
  }

  EnvironmentMetricEvaluation _buildHumidityEvaluation(double? hum) {
    if (hum == null) {
      return const EnvironmentMetricEvaluation(
        value: null,
        score: 50,
        state: MetricState.unknown,
        flags: [],
        reason: '湿度データがまだありません。',
      );
    }

    if (hum < humMin) {
      final diff = humMin - hum;
      final state = diff >= 10 ? MetricState.alert : MetricState.caution;
      final score = diff >= 10
          ? (65 - diff * 1.8).round().clamp(0, 100)
          : (85 - diff * 1.5).round().clamp(0, 100);

      return EnvironmentMetricEvaluation(
        value: hum,
        score: score,
        state: state,
        flags: const [EvaluationFlag.humidityLow],
        reason: '湿度が適正下限より ${diff.round()}pt 低い状態です。',
      );
    }

    if (hum > humMax) {
      final diff = hum - humMax;
      final state = diff >= 10 ? MetricState.alert : MetricState.caution;
      final score = diff >= 10
          ? (65 - diff * 1.8).round().clamp(0, 100)
          : (85 - diff * 1.5).round().clamp(0, 100);

      return EnvironmentMetricEvaluation(
        value: hum,
        score: score,
        state: state,
        flags: const [EvaluationFlag.humidityHigh],
        reason: '湿度が適正上限より ${diff.round()}pt 高い状態です。',
      );
    }

    return EnvironmentMetricEvaluation(
      value: hum,
      score: 100,
      state: MetricState.good,
      flags: const [],
      reason: '湿度は適正範囲内です。',
    );
  }

  ActivityMetricEvaluation _buildActivityEvaluation(ActivitySummary summary) {
    if (!summary.hasAnyRecord) {
      return const ActivityMetricEvaluation(
        todayDistanceMeters: 0,
        avg7DistanceMeters: 0,
        deltaPct: 0,
        score: 50,
        state: MetricState.unknown,
        flags: [EvaluationFlag.activityMissing],
        reason: '走行距離データがまだありません。',
      );
    }

    if (!summary.todayHasRecord) {
      return ActivityMetricEvaluation(
        todayDistanceMeters: 0,
        avg7DistanceMeters: summary.avg7DistanceMeters,
        deltaPct: 0,
        score: 45,
        state: MetricState.unknown,
        flags: const [EvaluationFlag.activityMissing],
        reason: '今日はまだ走行距離が記録されていません。',
      );
    }

    final today = summary.todayDistanceMeters;
    final avg7 = summary.avg7DistanceMeters;
    final deltaPct = summary.deltaPct;

    if (deltaPct <= -40) {
      return ActivityMetricEvaluation(
        todayDistanceMeters: today,
        avg7DistanceMeters: avg7,
        deltaPct: deltaPct,
        score: 40,
        state: MetricState.alert,
        flags: const [
          EvaluationFlag.activityLow,
          EvaluationFlag.activityDrop,
        ],
        reason: '活動量が直近7日平均を大きく下回っています。',
      );
    }

    if (deltaPct <= -15) {
      return ActivityMetricEvaluation(
        todayDistanceMeters: today,
        avg7DistanceMeters: avg7,
        deltaPct: deltaPct,
        score: 70,
        state: MetricState.caution,
        flags: const [
          EvaluationFlag.activityLow,
          EvaluationFlag.activityDrop,
        ],
        reason: '活動量が直近7日平均より少なめです。',
      );
    }

    if (deltaPct >= 60) {
      return ActivityMetricEvaluation(
        todayDistanceMeters: today,
        avg7DistanceMeters: avg7,
        deltaPct: deltaPct,
        score: 75,
        state: MetricState.alert,
        flags: const [EvaluationFlag.activityHigh],
        reason: '活動量が直近7日平均を大きく上回っています。',
      );
    }

    if (deltaPct >= 20) {
      return ActivityMetricEvaluation(
        todayDistanceMeters: today,
        avg7DistanceMeters: avg7,
        deltaPct: deltaPct,
        score: 88,
        state: MetricState.caution,
        flags: const [EvaluationFlag.activityHigh],
        reason: '活動量が直近7日平均より多めです。',
      );
    }

    return ActivityMetricEvaluation(
      todayDistanceMeters: today,
      avg7DistanceMeters: avg7,
      deltaPct: deltaPct,
      score: 100,
      state: MetricState.good,
      flags: const [],
      reason: '活動量は直近7日平均に対して概ね安定しています。',
    );
  }

  MetricState _resolveOverallState(
    MetricState temperature,
    MetricState humidity,
    MetricState activity,
  ) {
    final states = [temperature, humidity, activity];

    if (states.contains(MetricState.alert)) return MetricState.alert;
    if (states.contains(MetricState.caution)) return MetricState.caution;
    if (states.every((s) => s == MetricState.unknown))
      return MetricState.unknown;
    if (states.contains(MetricState.unknown)) return MetricState.caution;
    return MetricState.good;
  }

  List<EvaluationFlag> _mergeFlags(
      List<EvaluationFlag> a, List<EvaluationFlag> b, List<EvaluationFlag> c) {
    final merged = <EvaluationFlag>{...a, ...b, ...c};
    return merged.toList();
  }

  String _buildSummary({
    required EnvironmentMetricEvaluation temperature,
    required EnvironmentMetricEvaluation humidity,
    required ActivityMetricEvaluation activity,
    required MetricState overallState,
  }) {
    if (temperature.flags.contains(EvaluationFlag.tempHigh)) {
      return '温度が高めです。まずは暑さの影響を優先して確認したい状態です。';
    }
    if (temperature.flags.contains(EvaluationFlag.tempLow)) {
      return '温度が低めです。冷えすぎていないかを優先して確認したい状態です。';
    }
    if (humidity.flags.contains(EvaluationFlag.humidityHigh)) {
      return '湿度が高めです。通気や床材のこもりを見直したい状態です。';
    }
    if (humidity.flags.contains(EvaluationFlag.humidityLow)) {
      return '湿度が低めです。乾燥しすぎていないかを見たい状態です。';
    }
    if (activity.flags.contains(EvaluationFlag.activityMissing)) {
      return '活動量データが不足しています。記録が増えると、より確かな評価ができます。';
    }
    if (activity.flags.contains(EvaluationFlag.activityLow)) {
      return '活動量が少なめです。最近の傾向変化として注目したい状態です。';
    }
    if (activity.flags.contains(EvaluationFlag.activityHigh)) {
      return '活動量が多めです。大きな変化として注目しておきたい状態です。';
    }

    switch (overallState) {
      case MetricState.good:
        return '温湿度と活動量は全体として安定しています。';
      case MetricState.caution:
        return '全体として大きな異常ではありませんが、いくつか注意したい点があります。';
      case MetricState.alert:
        return '全体として注意度が高く、優先して確認したい点があります。';
      case MetricState.unknown:
        return '評価に必要なデータがまだ不足しています。';
    }
  }
}
