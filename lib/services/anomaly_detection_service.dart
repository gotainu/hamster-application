// /Users/gota/local_dev/flutter_projects/hamster_project/lib/services/anomaly_detection_service.dart
import '../models/anomaly_detection.dart';
import '../models/environment_assessment_history.dart';

class AnomalyDetectionService {
  const AnomalyDetectionService();

  static const double _tempLowThreshold = 20.0;
  static const double _tempHighThreshold = 26.0;
  static const double _humHighThreshold = 60.0;

  AnomalyDetectionResult detect({
    required List<EnvironmentAssessmentHistory> history,
    int windowDays = 14,
  }) {
    final sorted = [...history]
      ..sort((a, b) => (a.dateKey ?? '').compareTo(b.dateKey ?? ''));

    final anomalies = <DetectedAnomaly>[
      ..._detectHighHumidityStreak(sorted),
      ..._detectLowTemperatureStreak(sorted),
      ..._detectHighTemperatureStreak(sorted),
      ..._detectDangerMinutes(sorted),
      ..._detectSpikes(sorted),
      ..._detectRatioWorsening(sorted),
      ..._detectLevelIssues(sorted),
    ];

    anomalies.sort((a, b) {
      final severityCompare = b.severity.index.compareTo(a.severity.index);
      if (severityCompare != 0) return severityCompare;

      final countCompare = (b.count ?? 0).compareTo(a.count ?? 0);
      if (countCompare != 0) return countCompare;

      return (b.value ?? 0).compareTo(a.value ?? 0);
    });

    return AnomalyDetectionResult(
      anomalies: anomalies,
      windowDays: windowDays,
      detectedAt: DateTime.now(),
    );
  }

  List<DetectedAnomaly> _detectHighHumidityStreak(
    List<EnvironmentAssessmentHistory> history,
  ) {
    final streak = _tailConsecutiveCount(
      history,
      (e) => (e.avgHum ?? double.negativeInfinity) > _humHighThreshold,
    );

    if (streak < 3) return const [];

    final recent = history.sublist(history.length - streak);
    final latest = recent.last;
    final latestHum = latest.avgHum;

    return [
      DetectedAnomaly(
        flag: AnomalyFlag.highHumidityStreak,
        severity: streak >= 5 ? AnomalySeverity.high : AnomalySeverity.medium,
        title: '高湿が続いています',
        description: latestHum != null
            ? '湿度が高めの状態が $streak 日連続です。最新の平均湿度は ${latestHum.round()}% です。'
            : '湿度が高めの状態が $streak 日連続です。',
        count: streak,
        value: latestHum,
        startDateKey: recent.first.dateKey,
        endDateKey: recent.last.dateKey,
      ),
    ];
  }

  List<DetectedAnomaly> _detectLowTemperatureStreak(
    List<EnvironmentAssessmentHistory> history,
  ) {
    final streak = _tailConsecutiveCount(
      history,
      (e) => (e.avgTemp ?? double.infinity) < _tempLowThreshold,
    );

    if (streak < 3) return const [];

    final recent = history.sublist(history.length - streak);
    final latest = recent.last;
    final latestTemp = latest.avgTemp;

    return [
      DetectedAnomaly(
        flag: AnomalyFlag.lowTemperatureStreak,
        severity: streak >= 5 ? AnomalySeverity.high : AnomalySeverity.medium,
        title: '低温が続いています',
        description: latestTemp != null
            ? '温度が低めの状態が $streak 日連続です。最新の平均温度は ${latestTemp.toStringAsFixed(1)}℃ です。'
            : '温度が低めの状態が $streak 日連続です。',
        count: streak,
        value: latestTemp,
        startDateKey: recent.first.dateKey,
        endDateKey: recent.last.dateKey,
      ),
    ];
  }

  List<DetectedAnomaly> _detectHighTemperatureStreak(
    List<EnvironmentAssessmentHistory> history,
  ) {
    final streak = _tailConsecutiveCount(
      history,
      (e) => (e.avgTemp ?? double.negativeInfinity) > _tempHighThreshold,
    );

    if (streak < 3) return const [];

    final recent = history.sublist(history.length - streak);
    final latest = recent.last;
    final latestTemp = latest.avgTemp;

    return [
      DetectedAnomaly(
        flag: AnomalyFlag.highTemperatureStreak,
        severity: streak >= 5 ? AnomalySeverity.high : AnomalySeverity.medium,
        title: '高温が続いています',
        description: latestTemp != null
            ? '温度が高めの状態が $streak 日連続です。最新の平均温度は ${latestTemp.toStringAsFixed(1)}℃ です。'
            : '温度が高めの状態が $streak 日連続です。',
        count: streak,
        value: latestTemp,
        startDateKey: recent.first.dateKey,
        endDateKey: recent.last.dateKey,
      ),
    ];
  }

  List<DetectedAnomaly> _detectDangerMinutes(
    List<EnvironmentAssessmentHistory> history,
  ) {
    if (history.isEmpty) return const [];

    final recent =
        history.length <= 3 ? history : history.sublist(history.length - 3);

    final hit = recent.where((e) => (e.dangerMinutes ?? 0) > 0).toList();
    if (hit.isEmpty) return const [];

    final maxDanger = hit
        .map((e) => e.dangerMinutes ?? 0)
        .fold<int>(0, (max, v) => v > max ? v : max);

    return [
      DetectedAnomaly(
        flag: AnomalyFlag.dangerMinutesDetected,
        severity:
            maxDanger >= 60 ? AnomalySeverity.high : AnomalySeverity.medium,
        title: '危険域への滞在がありました',
        description: '直近3日以内に危険域へ入った記録があります。最大で $maxDanger 分の滞在が検出されました。',
        count: hit.length,
        value: maxDanger.toDouble(),
        startDateKey: hit.first.dateKey,
        endDateKey: hit.last.dateKey,
      ),
    ];
  }

  List<DetectedAnomaly> _detectSpikes(
    List<EnvironmentAssessmentHistory> history,
  ) {
    if (history.isEmpty) return const [];

    final recent =
        history.length <= 3 ? history : history.sublist(history.length - 3);

    final tempSpikeTotal = recent.fold<int>(
      0,
      (sum, e) => sum + (e.spikesTemp ?? 0),
    );
    final humSpikeTotal = recent.fold<int>(
      0,
      (sum, e) => sum + (e.spikesHum ?? 0),
    );

    final anomalies = <DetectedAnomaly>[];

    if (tempSpikeTotal >= 3) {
      anomalies.add(
        DetectedAnomaly(
          flag: AnomalyFlag.tempSpikeDetected,
          severity: tempSpikeTotal >= 6
              ? AnomalySeverity.high
              : AnomalySeverity.medium,
          title: '温度の急変が増えています',
          description:
              '直近3日で温度急変が合計 $tempSpikeTotal 回ありました。温度の安定性が崩れている可能性があります。',
          count: tempSpikeTotal,
          value: tempSpikeTotal.toDouble(),
          startDateKey: recent.first.dateKey,
          endDateKey: recent.last.dateKey,
        ),
      );
    }

    if (humSpikeTotal >= 3) {
      anomalies.add(
        DetectedAnomaly(
          flag: AnomalyFlag.humiditySpikeDetected,
          severity: humSpikeTotal >= 6
              ? AnomalySeverity.high
              : AnomalySeverity.medium,
          title: '湿度の急変が増えています',
          description:
              '直近3日で湿度急変が合計 $humSpikeTotal 回ありました。湿度の安定性が崩れている可能性があります。',
          count: humSpikeTotal,
          value: humSpikeTotal.toDouble(),
          startDateKey: recent.first.dateKey,
          endDateKey: recent.last.dateKey,
        ),
      );
    }

    return anomalies;
  }

  List<DetectedAnomaly> _detectRatioWorsening(
    List<EnvironmentAssessmentHistory> history,
  ) {
    if (history.length < 2) return const [];

    final recent =
        history.length <= 3 ? history : history.sublist(history.length - 3);

    final anomalies = <DetectedAnomaly>[];

    final latest = recent.last;
    final previous = recent[recent.length - 2];

    final tempRatioDelta = _delta(previous.tempRatio, latest.tempRatio);
    if (tempRatioDelta != null && tempRatioDelta >= 0.15) {
      anomalies.add(
        DetectedAnomaly(
          flag: AnomalyFlag.tempRatioWorsened,
          severity: tempRatioDelta >= 0.30
              ? AnomalySeverity.high
              : AnomalySeverity.medium,
          title: '温度の適正度が悪化しています',
          description:
              '直近で温度の適正度が悪化しました。前回比で ${(tempRatioDelta * 100).round()}pt 変化しています。',
          value: tempRatioDelta,
          startDateKey: previous.dateKey,
          endDateKey: latest.dateKey,
        ),
      );
    }

    final humRatioDelta = _delta(previous.humRatio, latest.humRatio);
    if (humRatioDelta != null && humRatioDelta >= 0.15) {
      anomalies.add(
        DetectedAnomaly(
          flag: AnomalyFlag.humidityRatioWorsened,
          severity: humRatioDelta >= 0.30
              ? AnomalySeverity.high
              : AnomalySeverity.medium,
          title: '湿度の適正度が悪化しています',
          description:
              '直近で湿度の適正度が悪化しました。前回比で ${(humRatioDelta * 100).round()}pt 変化しています。',
          value: humRatioDelta,
          startDateKey: previous.dateKey,
          endDateKey: latest.dateKey,
        ),
      );
    }

    return anomalies;
  }

  List<DetectedAnomaly> _detectLevelIssues(
    List<EnvironmentAssessmentHistory> history,
  ) {
    if (history.isEmpty) return const [];

    final results = <DetectedAnomaly>[];

    final cautionStreak = _tailConsecutiveCount(
      history,
      (e) => e.level == '注意',
    );

    if (cautionStreak >= 3) {
      final recent = history.sublist(history.length - cautionStreak);

      results.add(
        DetectedAnomaly(
          flag: AnomalyFlag.cautionLevelStreak,
          severity: cautionStreak >= 5
              ? AnomalySeverity.high
              : AnomalySeverity.medium,
          title: '注意評価が続いています',
          description: '環境評価の「注意」が $cautionStreak 日連続です。',
          count: cautionStreak,
          value: cautionStreak.toDouble(),
          startDateKey: recent.first.dateKey,
          endDateKey: recent.last.dateKey,
        ),
      );
    }

    final recent3 =
        history.length <= 3 ? history : history.sublist(history.length - 3);
    final dangerHit = recent3.where((e) => e.level == '危険').toList();

    if (dangerHit.isNotEmpty) {
      results.add(
        DetectedAnomaly(
          flag: AnomalyFlag.dangerLevelDetected,
          severity: AnomalySeverity.high,
          title: '危険評価が検出されました',
          description: '直近3日以内に環境評価「危険」が発生しています。',
          count: dangerHit.length,
          value: dangerHit.length.toDouble(),
          startDateKey: dangerHit.first.dateKey,
          endDateKey: dangerHit.last.dateKey,
        ),
      );
    }

    return results;
  }

  int _tailConsecutiveCount(
    List<EnvironmentAssessmentHistory> history,
    bool Function(EnvironmentAssessmentHistory item) predicate,
  ) {
    int count = 0;
    for (int i = history.length - 1; i >= 0; i--) {
      if (predicate(history[i])) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  double? _delta(double? previous, double? current) {
    if (previous == null || current == null) return null;
    return current - previous;
  }
}
